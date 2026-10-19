// Pengajuan jadi pemilik, pengelolaan sewa oleh pemilik, dan peninjauan oleh admin.
const express = require('express');
const router = express.Router();       // dipasang di /owner
const adminRouter = express.Router();  // dipasang di /admin
const { db, withTransaction } = require('../config/db');
const { HttpError, wrap, ok, idParam } = require('../utils/http');
const { auth, requireRole } = require('../middleware/auth');
const { cardsByIds } = require('../services/kos');
const {
  PENDING, COIN_RATE, BOOKING_COLS, BOOKING_FROM, toBooking, releaseBooking, expireStale, findBooking,
} = require('../services/bookings');

router.use(auth);
adminRouter.use(auth);

// ------------------------------------------------------------------ PENGAJUAN
// GET /owner/status -> { role, owner_status }
router.get('/status', wrap(async (req, res) => {
  ok(res, { role: req.user.role, owner_status: req.user.owner_status });
}));

// POST /owner/apply  -> status "pending" sampai ditinjau admin
router.post('/apply', wrap(async (req, res) => {
  if (req.user.role !== 'pencari') throw new HttpError(409, 'Akunmu sudah berstatus pemilik');
  if (req.user.owner_status === 'pending') throw new HttpError(409, 'Pengajuanmu sedang diproses');
  await db.query("UPDATE users SET owner_status = 'pending' WHERE id = ?", [req.user.id]);
  ok(res, { owner_status: 'pending' }, 201);
}));

// ------------------------------------------------------------------ ADMIN
// GET /admin/owner-applications
adminRouter.get('/owner-applications', requireRole('admin'), wrap(async (_req, res) => {
  const [rows] = await db.query(
    "SELECT id, name, email, phone, created_at FROM users WHERE owner_status = 'pending' ORDER BY created_at");
  ok(res, rows);
}));

for (const [action, role, status] of [['approve', 'pemilik', 'approved'], ['reject', 'pencari', 'rejected']]) {
  // POST /admin/owner-applications/:userId/approve | reject
  adminRouter.post(`/owner-applications/:userId/${action}`, requireRole('admin'), wrap(async (req, res) => {
    const userId = idParam(req, 'userId');
    const [r] = await db.query(
      "UPDATE users SET role = ?, owner_status = ? WHERE id = ? AND owner_status = 'pending'",
      [role, status, userId],
    );
    if (!r.affectedRows) throw new HttpError(404, 'Pengajuan tidak ditemukan');
    ok(res, { user_id: userId, owner_status: status });
  }));
}

// ------------------------------------------------------------------ PEMILIK
const owner = requireRole('pemilik', 'admin');

// GET /owner/kos -> kos milik pemilik ini
router.get('/kos', owner, wrap(async (req, res) => {
  const [rows] = await db.query('SELECT id FROM kos WHERE owner_id = ? ORDER BY id', [req.user.id]);
  ok(res, await cardsByIds(rows.map((r) => r.id)));
}));

// GET /owner/bookings?status=  -> pengajuan sewa pada kos milik pemilik ini
router.get('/bookings', owner, wrap(async (req, res) => {
  await expireStale();
  const where = [req.user.role === 'admin' ? '1 = 1' : 'k.owner_id = ?'];
  const params = req.user.role === 'admin' ? [] : [req.user.id];
  if (req.query.status) {
    where.push('b.status = ?');
    params.push(String(req.query.status));
  }
  const [rows] = await db.query(
    `SELECT ${BOOKING_COLS} ${BOOKING_FROM} WHERE ${where.join(' AND ')} ORDER BY b.created_at DESC, b.id DESC`,
    params,
  );
  ok(res, rows.map(toBooking));
}));

/**
 * Pindahkan status booking milik kos si pemilik.
 * from: status asal yang diizinkan; to: status tujuan; after: aksi tambahan.
 */
function transition(action, { from, to, message, after }) {
  router.post(`/bookings/:id/${action}`, owner, wrap(async (req, res) => {
    const id = idParam(req);
    await withTransaction(async (conn) => {
      const [[b]] = await conn.query(
        `SELECT b.*, k.owner_id FROM bookings b JOIN kos k ON k.id = b.kos_id WHERE b.id = ? FOR UPDATE`, [id]);
      if (!b || (req.user.role !== 'admin' && b.owner_id !== req.user.id)) {
        throw new HttpError(404, 'Pengajuan tidak ditemukan');
      }
      if (!from.includes(b.status)) throw new HttpError(409, message);
      await conn.query('UPDATE bookings SET status = ? WHERE id = ?', [to, id]);
      if (after) await after(conn, b);
    });
    ok(res, await findBooking(id));
  }));
}

transition('confirm', {
  from: ['menunggu_konfirmasi'], to: 'menunggu_pembayaran',
  message: 'Pengajuan ini tidak sedang menunggu konfirmasi',
});
transition('reject', {
  from: PENDING, to: 'ditolak',
  message: 'Pengajuan ini tidak bisa ditolak lagi',
  after: (conn, b) => releaseBooking(conn, b),
});
transition('activate', {
  from: ['dibayar'], to: 'aktif',
  message: 'Pengajuan ini belum dibayar',
  after: (conn, b) => conn.query(
    "UPDATE payments SET status = 'berhasil' WHERE booking_id = ? AND status = 'menunggu_verifikasi'", [b.id]),
});
transition('complete', {
  from: ['aktif'], to: 'selesai',
  message: 'Hanya sewa yang sedang aktif yang bisa diselesaikan',
  after: async (conn, b) => {
    await conn.query('UPDATE room_types SET stock = stock + 1 WHERE id = ?', [b.room_type_id]);
    const coins = Math.floor((b.price_per_unit * b.duration_count) / COIN_RATE);
    if (coins > 0) {
      await conn.query('UPDATE users SET coins = coins + ? WHERE id = ?', [coins, b.user_id]);
      await conn.query(
        "INSERT INTO coin_transactions (user_id, title, amount) VALUES (?, 'Menyelesaikan masa sewa', ?)",
        [b.user_id, coins],
      );
    }
  },
});

// POST /owner/reviews/:id/reply  { reply }
router.post('/reviews/:id/reply', owner, wrap(async (req, res) => {
  const id = idParam(req);
  const reply = String(req.body.reply || '').trim();
  if (!reply || reply.length > 1000) throw new HttpError(422, 'Balasan wajib diisi (maks. 1000 karakter)');
  const [r] = await db.query(
    `UPDATE reviews r JOIN kos k ON k.id = r.kos_id
        SET r.owner_reply = ?, r.owner_replied_at = NOW()
      WHERE r.id = ? ${req.user.role === 'admin' ? '' : 'AND k.owner_id = ?'}`,
    req.user.role === 'admin' ? [reply, id] : [reply, id, req.user.id],
  );
  if (!r.affectedRows) throw new HttpError(404, 'Ulasan tidak ditemukan');
  ok(res, { id, owner_reply: reply });
}));

module.exports = { ownerRouter: router, adminRouter };
