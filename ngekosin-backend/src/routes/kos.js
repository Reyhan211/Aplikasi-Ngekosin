const router = require('express').Router();
const { db, withTransaction } = require('../config/db');
const { HttpError, wrap, ok, idParam } = require('../utils/http');
const { auth, optionalAuth } = require('../middleware/auth');
const { listKos, cardSelect, attachFacilities } = require('../services/kos');
const { shortName } = require('../utils/format');

const ASPECTS = ['cleanliness', 'comfort', 'safety', 'price', 'room_facility', 'public_facility'];
const round2 = (n) => Math.round(n * 100) / 100;

// GET /kos  (q, type, city_id, landmark_id, radius_km, available, promo, sort, limit, offset)
router.get('/', optionalAuth, wrap(async (req, res) => {
  ok(res, await listKos(req.query, req.user?.id));
}));

// GET /kos/featured -> "Pilihan Editor"
router.get('/featured', optionalAuth, wrap(async (req, res) => {
  const rows = await listKos({ sort: 'rating' }, req.user?.id);
  ok(res, rows.filter((k) => k.rating_avg >= 4.6));
}));

// GET /kos/promo -> "Diskon Kilat"
router.get('/promo', optionalAuth, wrap(async (req, res) => {
  ok(res, await listKos({ promo: '1', sort: 'recommended' }, req.user?.id));
}));

// GET /kos/:id  (login opsional: mengisi is_favorite & mencatat "terakhir dilihat")
router.get('/:id', optionalAuth, wrap(async (req, res) => {
  const id = idParam(req);
  const sel = cardSelect(req.user?.id);
  const [[row]] = await db.query(
    `SELECT ${sel.sql}, k.address, k.description, k.latitude, k.longitude,
            k.rb_cleanliness, k.rb_comfort, k.rb_safety, k.rb_price, k.rb_room_facility, k.rb_public_facility,
            u.id AS owner_id, u.name AS owner_name
       FROM kos k JOIN cities c ON c.id = k.city_id JOIN users u ON u.id = k.owner_id
      WHERE k.id = ? AND k.is_active = 1`,
    [...sel.params, id],
  );
  if (!row) throw new HttpError(404, 'Kos tidak ditemukan');

  const [facilities] = await db.query(
    `SELECT f.name, f.category, f.icon FROM kos_facilities kf JOIN facilities f ON f.id = kf.facility_id
      WHERE kf.kos_id = ? ORDER BY FIELD(f.category,'kamar','kamar_mandi','umum','parkir'), kf.sort_order`,
    [id],
  );
  const [rules] = await db.query('SELECT rule_text FROM kos_rules WHERE kos_id = ? ORDER BY sort_order', [id]);
  const [rooms] = await db.query(
    `SELECT id, name, size_label, price_daily, price_weekly, price_monthly, price_yearly, deposit, stock
       FROM room_types WHERE kos_id = ? ORDER BY price_monthly`,
    [id],
  );
  const [images] = await db.query('SELECT image_url FROM kos_images WHERE kos_id = ? ORDER BY sort_order', [id]);
  const [card] = await attachFacilities([row]);

  if (req.user) {
    await db.query(
      `INSERT INTO recently_viewed (user_id, kos_id, viewed_at) VALUES (?, ?, NOW())
       ON DUPLICATE KEY UPDATE viewed_at = NOW()`,
      [req.user.id, id],
    );
  }

  ok(res, {
    id: card.id,
    name: card.name,
    kos_type: card.kos_type,
    district: card.district,
    city: card.city,
    cover_url: card.cover_url,
    promo_label: card.promo_label,
    rating_avg: card.rating_avg,
    rating_count: card.rating_count,
    min_price: card.min_price,
    available_rooms: card.available_rooms,
    is_favorite: card.is_favorite,
    facilities, // detail lengkap (nama, kategori, ikon)
    highlights: card.facilities,
    address: row.address,
    description: row.description,
    latitude: row.latitude,
    longitude: row.longitude,
    images: images.map((i) => i.image_url),
    rules: rules.map((r) => r.rule_text),
    rating_breakdown: Object.fromEntries(ASPECTS.map((a) => [a, row[`rb_${a}`]])),
    owner: { id: row.owner_id, name: row.owner_name },
    rooms,
  });
}));

// ------------------------------------------------------------------ ULASAN
const toReview = (r) => ({
  id: r.id,
  user_name: shortName(r.user_name),
  rating_overall: r.rating_overall,
  comment: r.comment || '',
  owner_reply: r.owner_reply,
  created_at: r.created_at,
  ratings: Object.fromEntries(ASPECTS.map((a) => [a, r[a]])),
});

const REVIEW_SELECT = `SELECT r.*, u.name AS user_name FROM reviews r JOIN users u ON u.id = r.user_id`;

// GET /kos/:id/reviews?limit=&offset=
router.get('/:id/reviews', wrap(async (req, res) => {
  const id = idParam(req);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);
  const [rows] = await db.query(
    `${REVIEW_SELECT} WHERE r.kos_id = ? ORDER BY r.created_at DESC, r.id DESC LIMIT ? OFFSET ?`,
    [id, limit, offset],
  );
  ok(res, rows.map(toReview));
}));

// GET /kos/:id/reviews/me  -> ulasan milik user ini (404 bila belum ada)
router.get('/:id/reviews/me', auth, wrap(async (req, res) => {
  const [[row]] = await db.query(`${REVIEW_SELECT} WHERE r.kos_id = ? AND r.user_id = ?`, [idParam(req), req.user.id]);
  if (!row) throw new HttpError(404, 'Belum ada ulasan');
  ok(res, toReview(row));
}));

// POST /kos/:id/reviews  { ratings: {cleanliness, comfort, safety, price, room_facility, public_facility}, comment }
// Membuat ulasan, atau memperbarui ulasan milik user yang sama. Rating kos ikut dihitung ulang.
router.post('/:id/reviews', auth, wrap(async (req, res) => {
  const kosId = idParam(req);
  const input = req.body.ratings || {};
  const ratings = {};
  for (const a of ASPECTS) {
    const v = Number(input[a]);
    if (!(v >= 1 && v <= 5)) throw new HttpError(422, 'Semua aspek penilaian wajib diisi (1-5)');
    ratings[a] = Math.round(v * 10) / 10;
  }
  const comment = String(req.body.comment || '').trim();
  if (comment.length > 1000) throw new HttpError(422, 'Komentar maksimal 1000 karakter');
  const overall = Math.round((ASPECTS.reduce((s, a) => s + ratings[a], 0) / ASPECTS.length) * 10) / 10;

  const created = await withTransaction(async (conn) => {
    const [[kos]] = await conn.query('SELECT * FROM kos WHERE id = ? AND is_active = 1 FOR UPDATE', [kosId]);
    if (!kos) throw new HttpError(404, 'Kos tidak ditemukan');
    if (kos.owner_id === req.user.id) throw new HttpError(403, 'Pemilik tidak bisa mengulas kos sendiri');
    const [[old]] = await conn.query(
      'SELECT * FROM reviews WHERE kos_id = ? AND user_id = ? FOR UPDATE', [kosId, req.user.id]);

    // Agregat dihitung bertahap agar nilai awal (histori) pada kos ikut terhitung.
    let count;
    const next = {};
    if (!old) {
      count = kos.rating_count + 1;
      next.rating_avg = (kos.rating_avg * kos.rating_count + overall) / count;
      for (const a of ASPECTS) next[`rb_${a}`] = (kos[`rb_${a}`] * kos.rating_count + ratings[a]) / count;
      await conn.query(
        `INSERT INTO reviews (kos_id, user_id, ${ASPECTS.join(', ')}, rating_overall, comment)
         VALUES (?, ?, ${ASPECTS.map(() => '?').join(', ')}, ?, ?)`,
        [kosId, req.user.id, ...ASPECTS.map((a) => ratings[a]), overall, comment],
      );
      await conn.query('UPDATE users SET coins = coins + 50 WHERE id = ?', [req.user.id]);
      await conn.query("INSERT INTO coin_transactions (user_id, title, amount) VALUES (?, 'Menulis ulasan', 50)", [req.user.id]);
    } else {
      count = Math.max(kos.rating_count, 1);
      next.rating_avg = kos.rating_avg + (overall - old.rating_overall) / count;
      for (const a of ASPECTS) next[`rb_${a}`] = kos[`rb_${a}`] + (ratings[a] - old[a]) / count;
      await conn.query(
        `UPDATE reviews SET ${ASPECTS.map((a) => `${a} = ?`).join(', ')}, rating_overall = ?, comment = ?
          WHERE id = ?`,
        [...ASPECTS.map((a) => ratings[a]), overall, comment, old.id],
      );
    }
    const clamp = (n) => round2(Math.min(5, Math.max(0, n)));
    const cols = Object.keys(next);
    await conn.query(
      `UPDATE kos SET rating_count = ?, ${cols.map((c) => `${c} = ?`).join(', ')} WHERE id = ?`,
      [count, ...cols.map((c) => clamp(next[c])), kosId],
    );
    return !old;
  });

  const [[row]] = await db.query(`${REVIEW_SELECT} WHERE r.kos_id = ? AND r.user_id = ?`, [kosId, req.user.id]);
  ok(res, toReview(row), created ? 201 : 200);
}));

module.exports = router;
