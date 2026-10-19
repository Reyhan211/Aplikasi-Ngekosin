// Favorit, terakhir dilihat, koin, voucher, dan promo milik user yang login.
const router = require('express').Router();
const { db, withTransaction } = require('../config/db');
const { HttpError, wrap, ok, idParam } = require('../utils/http');
const { auth } = require('../middleware/auth');
const { cardsByIds } = require('../services/kos');
const { resolveVoucher } = require('../services/bookings');

// ------------------------------------------------------------------ FAVORIT
// GET /favorites  (terlama dulu; aplikasi membaliknya sehingga terbaru tampil di atas)
router.get('/favorites', auth, wrap(async (req, res) => {
  const [rows] = await db.query('SELECT kos_id FROM favorites WHERE user_id = ? ORDER BY created_at ASC, kos_id ASC', [req.user.id]);
  ok(res, await cardsByIds(rows.map((r) => r.kos_id), req.user.id));
}));

// POST /favorites/:kosId
router.post('/favorites/:kosId', auth, wrap(async (req, res) => {
  const kosId = idParam(req, 'kosId');
  const [[kos]] = await db.query('SELECT id FROM kos WHERE id = ? AND is_active = 1', [kosId]);
  if (!kos) throw new HttpError(404, 'Kos tidak ditemukan');
  await db.query('INSERT IGNORE INTO favorites (user_id, kos_id) VALUES (?, ?)', [req.user.id, kosId]);
  ok(res, { kos_id: kosId, is_favorite: true }, 201);
}));

// DELETE /favorites/:kosId
router.delete('/favorites/:kosId', auth, wrap(async (req, res) => {
  const kosId = idParam(req, 'kosId');
  await db.query('DELETE FROM favorites WHERE user_id = ? AND kos_id = ?', [req.user.id, kosId]);
  ok(res, { kos_id: kosId, is_favorite: false });
}));

// GET /recently-viewed  (terbaru dulu, maks. 10)
router.get('/recently-viewed', auth, wrap(async (req, res) => {
  const [rows] = await db.query(
    'SELECT kos_id FROM recently_viewed WHERE user_id = ? ORDER BY viewed_at DESC LIMIT 10', [req.user.id]);
  ok(res, await cardsByIds(rows.map((r) => r.kos_id), req.user.id));
}));

// ------------------------------------------------------------------ KOIN
// GET /coins -> { balance, history: [{title, amount, created_at}] }
router.get('/coins', auth, wrap(async (req, res) => {
  const [[u]] = await db.query('SELECT coins FROM users WHERE id = ?', [req.user.id]);
  const [history] = await db.query(
    'SELECT title, amount, created_at FROM coin_transactions WHERE user_id = ? ORDER BY created_at DESC, id DESC LIMIT 100',
    [req.user.id],
  );
  ok(res, { balance: u.coins, history });
}));

// ------------------------------------------------------------------ VOUCHER
const VOUCHER_COLS = 'v.code, v.title, v.description, v.discount, v.min_amount, v.expires_at';

// GET /vouchers -> voucher milik user yang belum dipakai
router.get('/vouchers', auth, wrap(async (req, res) => {
  const [rows] = await db.query(
    `SELECT ${VOUCHER_COLS} FROM user_vouchers uv JOIN vouchers v ON v.id = uv.voucher_id
      WHERE uv.user_id = ? AND uv.used_at IS NULL AND v.is_active = 1
      ORDER BY v.expires_at ASC`,
    [req.user.id],
  );
  ok(res, rows);
}));

// POST /vouchers/claim  { code }
router.post('/vouchers/claim', auth, wrap(async (req, res) => {
  const code = String(req.body.code || '').trim().toUpperCase();
  if (!code) throw new HttpError(422, 'Masukkan kode voucher dulu');
  const [[v]] = await db.query(
    `SELECT v.id, ${VOUCHER_COLS} FROM vouchers v WHERE v.code = ? AND v.is_active = 1 AND v.expires_at > NOW()`,
    [code],
  );
  if (!v) throw new HttpError(400, 'Kode voucher tidak valid atau sudah berakhir');
  const [r] = await db.query('INSERT IGNORE INTO user_vouchers (user_id, voucher_id) VALUES (?, ?)', [req.user.id, v.id]);
  if (r.affectedRows === 0) throw new HttpError(409, 'Voucher ini sudah ada di daftarmu');
  const { id, ...voucher } = v;
  ok(res, voucher, 201);
}));

// POST /promos/validate  { code, kos_id, amount } -> { discount }
router.post('/promos/validate', auth, wrap(async (req, res) => {
  const amount = Number(req.body.amount);
  if (!(amount > 0)) throw new HttpError(422, 'Nominal tidak valid');
  const { voucher, discount } = await withTransaction((conn) =>
    resolveVoucher(conn, req.user.id, req.body.code, amount));
  ok(res, { code: voucher.code, title: voucher.title, discount });
}));

module.exports = router;
