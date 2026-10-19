const router = require('express').Router();
const fs = require('fs');
const path = require('path');
const { db, withTransaction } = require('../config/db');
const env = require('../config/env');
const { HttpError, wrap, ok, idParam, toInt } = require('../utils/http');
const { auth } = require('../middleware/auth');
const { upload, saveImage } = require('../utils/upload');
const { pad, parseDate, fmtDate, todayUtc, endDate, MAX_COUNT } = require('../utils/format');
const {
  PENDING, ADMIN_FEE, BOOKING_COLS, BOOKING_FROM,
  toBooking, releaseBooking, expireStale, findBooking, resolveVoucher,
} = require('../services/bookings');

router.use(auth);

const UNIT_PRICE = {
  harian: 'price_daily',
  mingguan: 'price_weekly',
  bulanan: 'price_monthly',
  tahunan: 'price_yearly',
};
const PAY_METHODS = ['bca', 'mandiri', 'bni', 'gopay', 'dana', 'qris'];
const BANK_METHODS = ['bca', 'mandiri', 'bni']; // transfer bank wajib bukti

// POST /bookings
// { kos_id, room_type_id, checkin_date, duration_unit, duration_count, occupants,
//   tenant_name, tenant_phone, note?, promo_code? }
// Server menghitung ulang SEMUA harga; angka dari aplikasi hanya estimasi.
router.post('/', wrap(async (req, res) => {
  const b = req.body;
  const kosId = toInt(b.kos_id);
  const roomId = toInt(b.room_type_id);
  const unit = String(b.duration_unit || '');
  const count = toInt(b.duration_count);
  const occupants = b.occupants === undefined ? 1 : toInt(b.occupants);
  const tenantName = String(b.tenant_name || '').trim();
  const tenantPhone = String(b.tenant_phone || '').replace(/[\s-]/g, '');
  const note = b.note ? String(b.note).trim().slice(0, 500) : null;
  const checkin = parseDate(b.checkin_date);

  if (!(kosId > 0) || !(roomId > 0)) throw new HttpError(422, 'Kos dan tipe kamar wajib dipilih');
  if (!UNIT_PRICE[unit]) throw new HttpError(422, 'Satuan sewa tidak valid');
  if (!(count >= 1 && count <= MAX_COUNT[unit])) {
    throw new HttpError(422, `Durasi ${unit} harus 1 sampai ${MAX_COUNT[unit]}`);
  }
  if (!(occupants >= 1 && occupants <= 4)) throw new HttpError(422, 'Jumlah penghuni harus 1-4 orang');
  if (tenantName.length < 2 || tenantName.length > 100) throw new HttpError(422, 'Nama penyewa harus 2-100 karakter');
  if (!/^\+?[0-9]{8,15}$/.test(tenantPhone)) throw new HttpError(422, 'Nomor HP penyewa tidak valid');
  if (!checkin) throw new HttpError(422, 'Tanggal masuk tidak valid (format YYYY-MM-DD)');
  if (checkin < todayUtc()) throw new HttpError(422, 'Tanggal masuk tidak boleh di masa lalu');

  await expireStale(); // lepaskan stok dari pengajuan yang sudah kedaluwarsa

  const booking = await withTransaction(async (conn) => {
    const [[room]] = await conn.query(
      `SELECT rt.*, k.owner_id FROM room_types rt JOIN kos k ON k.id = rt.kos_id
        WHERE rt.id = ? AND rt.kos_id = ? AND k.is_active = 1 FOR UPDATE`,
      [roomId, kosId],
    );
    if (!room) throw new HttpError(404, 'Tipe kamar tidak ditemukan');
    if (room.owner_id === req.user.id) throw new HttpError(403, 'Kamu tidak bisa menyewa kos milik sendiri');
    if (room.stock < 1) throw new HttpError(409, 'Maaf, kamar tipe ini sudah penuh');
    const price = room[UNIT_PRICE[unit]];
    if (!price) throw new HttpError(400, `Tipe kamar ini tidak tersedia untuk sewa ${unit}`);

    const subtotal = price * count;
    let discount = 0;
    let voucher = null;
    if (b.promo_code) {
      ({ voucher, discount } = await resolveVoucher(conn, req.user.id, b.promo_code, subtotal));
    }
    const total = Math.max(0, subtotal + room.deposit + ADMIN_FEE - discount);
    const checkout = endDate(checkin, unit, count);

    const [ins] = await conn.query(
      `INSERT INTO bookings (code, user_id, kos_id, room_type_id, checkin_date, checkout_date,
         duration_unit, duration_count, price_per_unit, deposit, admin_fee, discount, total_amount,
         occupants, tenant_name, tenant_phone, note, promo_code, status, expires_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'menunggu_konfirmasi',
               DATE_ADD(NOW(), INTERVAL 24 HOUR))`,
      [`TMP-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`, req.user.id, kosId, roomId,
        fmtDate(checkin), fmtDate(checkout), unit, count, price, room.deposit, ADMIN_FEE, discount, total,
        occupants, tenantName, tenantPhone, note, voucher ? voucher.code : null],
    );
    const code = `NGK-${fmtDate(new Date()).replace(/-/g, '')}-${pad(ins.insertId, 4)}`;
    await conn.query('UPDATE bookings SET code = ? WHERE id = ?', [code, ins.insertId]);
    await conn.query('UPDATE room_types SET stock = stock - 1 WHERE id = ?', [roomId]);
    if (voucher) {
      await conn.query(
        `INSERT INTO user_vouchers (user_id, voucher_id, used_at) VALUES (?, ?, NOW())
         ON DUPLICATE KEY UPDATE used_at = NOW()`,
        [req.user.id, voucher.id],
      );
    }
    return ins.insertId;
  });
  ok(res, await findBooking(booking), 201);
}));

// GET /bookings?status=  -> pengajuan/sewa milik user, terbaru dulu
router.get('/', wrap(async (req, res) => {
  await expireStale();
  const params = [req.user.id];
  let extra = '';
  if (req.query.status) {
    extra = 'AND b.status = ?';
    params.push(String(req.query.status));
  }
  const [rows] = await db.query(
    `SELECT ${BOOKING_COLS} ${BOOKING_FROM} WHERE b.user_id = ? ${extra} ORDER BY b.created_at DESC, b.id DESC`,
    params,
  );
  ok(res, rows.map(toBooking));
}));

/** Booking boleh dilihat oleh penyewa, pemilik kos terkait, atau admin. */
async function loadVisible(req) {
  const id = idParam(req);
  const [[row]] = await db.query(`SELECT ${BOOKING_COLS} ${BOOKING_FROM} WHERE b.id = ?`, [id]);
  const allowed = row && (row.user_id === req.user.id || row.owner_id === req.user.id || req.user.role === 'admin');
  if (!allowed) throw new HttpError(404, 'Pengajuan tidak ditemukan');
  return row;
}

// GET /bookings/:id
router.get('/:id', wrap(async (req, res) => {
  await expireStale();
  ok(res, toBooking(await loadVisible(req)));
}));

// GET /bookings/:id/proof  -> gambar bukti bayar (penyewa / pemilik kos / admin)
router.get('/:id/proof', wrap(async (req, res) => {
  const row = await loadVisible(req);
  const [[p]] = await db.query(
    'SELECT proof_url FROM payments WHERE booking_id = ? AND proof_url IS NOT NULL ORDER BY id DESC LIMIT 1', [row.id]);
  if (!p) throw new HttpError(404, 'Belum ada bukti pembayaran');
  res.sendFile(path.join(env.uploadsDir, '..', p.proof_url));
}));

// POST /bookings/:id/cancel  (hanya saat menunggu konfirmasi / pembayaran)
router.post('/:id/cancel', wrap(async (req, res) => {
  const id = idParam(req);
  await withTransaction(async (conn) => {
    const [[b]] = await conn.query('SELECT * FROM bookings WHERE id = ? AND user_id = ? FOR UPDATE', [id, req.user.id]);
    if (!b) throw new HttpError(404, 'Pengajuan tidak ditemukan');
    if (!PENDING.includes(b.status)) throw new HttpError(409, 'Pengajuan ini tidak bisa dibatalkan lagi');
    await conn.query("UPDATE bookings SET status = 'dibatalkan' WHERE id = ?", [id]);
    await releaseBooking(conn, b);
  });
  ok(res, await findBooking(id));
}));

// POST /bookings/:id/pay  (multipart: method, proof)
router.post('/:id/pay', upload.single('proof'), wrap(async (req, res) => {
  const id = idParam(req);
  const method = String(req.body.method || '').toLowerCase();
  if (!PAY_METHODS.includes(method)) throw new HttpError(422, 'Metode pembayaran tidak valid');
  const isBank = BANK_METHODS.includes(method);
  if (isBank && !req.file) throw new HttpError(422, 'Unggah bukti transfer terlebih dahulu');
  const proofUrl = req.file ? await saveImage(req.file, 'proofs') : null;

  try {
    await expireStale();
    await withTransaction(async (conn) => {
      const [[b]] = await conn.query('SELECT * FROM bookings WHERE id = ? AND user_id = ? FOR UPDATE', [id, req.user.id]);
      if (!b) throw new HttpError(404, 'Pengajuan tidak ditemukan');
      if (b.status === 'kadaluarsa') throw new HttpError(409, 'Pengajuan sudah kedaluwarsa, silakan ajukan ulang');
      if (!PENDING.includes(b.status)) throw new HttpError(409, 'Pengajuan ini tidak bisa dibayar');
      await conn.query(
        'INSERT INTO payments (booking_id, method, amount, proof_url, status) VALUES (?, ?, ?, ?, ?)',
        [id, method, b.total_amount, proofUrl, isBank ? 'menunggu_verifikasi' : 'berhasil'],
      );
      await conn.query("UPDATE bookings SET status = 'dibayar', expires_at = NULL WHERE id = ?", [id]);
    });
  } catch (err) {
    // bukti bayar yang sudah terlanjur tersimpan dibuang bila pembayaran ditolak
    if (proofUrl) await fs.promises.unlink(path.join(env.uploadsDir, '..', proofUrl)).catch(() => {});
    throw err;
  }
  ok(res, await findBooking(id));
}));

module.exports = router;
