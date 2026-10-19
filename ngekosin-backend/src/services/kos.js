const { db } = require('../config/db');

// Jarak (km) antara landmark `l` dan kos `k` - rumus Haversine.
const HAVERSINE = `(6371 * ACOS(LEAST(1,
  COS(RADIANS(l.latitude)) * COS(RADIANS(k.latitude)) * COS(RADIANS(k.longitude) - RADIANS(l.longitude))
  + SIN(RADIANS(l.latitude)) * SIN(RADIANS(k.latitude)))))`;

// Kata yang diabaikan saat pencarian (sama dengan aplikasi).
const STOP_WORDS = new Set([
  'kos', 'kost', 'kosan', 'dekat', 'sekitar', 'sekitaran', 'sekitarnya',
  'di', 'daerah', 'area', 'wilayah', 'dari', 'ke', 'yang', 'untuk', 'dan',
]);

/** "Kos dekat Universitas Negeri Surabaya" -> ['universitas','negeri','surabaya'] */
const tokenize = (q) =>
  String(q || '').toLowerCase().split(/[^a-z0-9]+/).filter((t) => t && !STOP_WORDS.has(t));

const AVAILABLE_SQL = '(SELECT COALESCE(SUM(r.stock), 0) FROM room_types r WHERE r.kos_id = k.id)';

const SORTS = {
  recommended: 'k.rating_avg DESC, k.rating_count DESC, k.id ASC',
  price_asc: 'min_price ASC, k.id ASC',
  price_desc: 'min_price DESC, k.id ASC',
  rating: 'k.rating_avg DESC, k.id ASC',
};

/** Kolom untuk kartu kos (item respons GET /kos). */
function cardSelect(userId) {
  return {
    sql: `k.id, k.name, k.kos_type, k.district, c.name AS city, k.cover_url, k.promo_label,
      k.rating_avg, k.rating_count,
      (SELECT MIN(r.price_monthly) FROM room_types r WHERE r.kos_id = k.id) AS min_price,
      CAST(${AVAILABLE_SQL} AS UNSIGNED) AS available_rooms,
      ${userId ? 'EXISTS(SELECT 1 FROM favorites f WHERE f.kos_id = k.id AND f.user_id = ?)' : '0'} AS is_favorite`,
    params: userId ? [userId] : [],
  };
}

/** Tambahkan `facilities` (ringkasan maks. 4) ke daftar kartu kos. */
async function attachFacilities(rows) {
  if (!rows.length) return rows;
  const [fac] = await db.query(
    `SELECT kf.kos_id, COALESCE(f.short_name, f.name) AS label
       FROM kos_facilities kf JOIN facilities f ON f.id = kf.facility_id
      WHERE kf.kos_id IN (?) AND kf.is_highlight = 1
      ORDER BY kf.kos_id, kf.sort_order`,
    [rows.map((r) => r.id)],
  );
  const map = new Map();
  for (const f of fac) {
    if (!map.has(f.kos_id)) map.set(f.kos_id, []);
    map.get(f.kos_id).push(f.label);
  }
  return rows.map((r) => ({
    ...r,
    is_favorite: !!r.is_favorite,
    facilities: (map.get(r.id) || []).slice(0, 4),
  }));
}

/**
 * Pencarian + filter kos.
 * opts: q, type, city_id, landmark_id, radius_km, available, promo, sort, limit, offset
 */
async function listKos(opts = {}, userId = null) {
  const where = ['k.is_active = 1'];
  const params = [];

  if (['putra', 'putri', 'campur'].includes(opts.type)) {
    where.push('k.kos_type = ?');
    params.push(opts.type);
  }
  if (Number(opts.city_id) > 0) {
    where.push('k.city_id = ?');
    params.push(Number(opts.city_id));
  }
  if (Number(opts.landmark_id) > 0) {
    const radius = Math.min(Math.max(Number(opts.radius_km) || 3, 0.1), 50);
    where.push(`EXISTS (SELECT 1 FROM landmarks l WHERE l.id = ? AND ${HAVERSINE} <= ?)`);
    params.push(Number(opts.landmark_id), radius);
  }
  if (opts.available === '1' || opts.available === true) {
    where.push(`${AVAILABLE_SQL} > 0`);
  }
  if (opts.promo === '1' || opts.promo === true) {
    where.push('k.promo_label IS NOT NULL');
  }

  const tokens = tokenize(opts.q);
  if (tokens.length) {
    // (a) semua kata kunci cocok dengan nama/kecamatan/kota/fasilitas kos
    const kosMatch = tokens.map(() => `(k.name LIKE ? OR k.district LIKE ? OR c.name LIKE ? OR EXISTS (
        SELECT 1 FROM kos_facilities kf JOIN facilities f ON f.id = kf.facility_id
         WHERE kf.kos_id = k.id AND (f.name LIKE ? OR f.short_name LIKE ?)))`).join(' AND ');
    const kosParams = tokens.flatMap((t) => Array(5).fill(`%${t}%`));
    // (b) atau kos berada dalam 3 km dari kampus yang cocok dengan kata kunci
    const lmMatch = tokens.map(() => '(l.short_name LIKE ? OR l.name LIKE ? OR l.city_label LIKE ?)').join(' AND ');
    const lmParams = tokens.flatMap((t) => Array(3).fill(`%${t}%`));
    where.push(`((${kosMatch}) OR EXISTS (
        SELECT 1 FROM landmarks l WHERE l.type = 'kampus' AND ${lmMatch} AND ${HAVERSINE} <= 3))`);
    params.push(...kosParams, ...lmParams);
  }

  const order = SORTS[opts.sort] || SORTS.recommended;
  const limit = Math.min(Math.max(parseInt(opts.limit, 10) || 100, 1), 100);
  const offset = Math.max(parseInt(opts.offset, 10) || 0, 0);
  const sel = cardSelect(userId);

  const [rows] = await db.query(
    `SELECT ${sel.sql}
       FROM kos k JOIN cities c ON c.id = k.city_id
      WHERE ${where.join(' AND ')}
      ORDER BY ${order}
      LIMIT ? OFFSET ?`,
    [...sel.params, ...params, limit, offset],
  );
  return attachFacilities(rows);
}

/** Kartu kos untuk daftar id tertentu (dengan urutan sesuai [ids]). */
async function cardsByIds(ids, userId = null) {
  if (!ids.length) return [];
  const sel = cardSelect(userId);
  const [rows] = await db.query(
    `SELECT ${sel.sql} FROM kos k JOIN cities c ON c.id = k.city_id
      WHERE k.id IN (?) AND k.is_active = 1`,
    [...sel.params, ids],
  );
  const byId = new Map(rows.map((r) => [r.id, r]));
  const ordered = ids.map((id) => byId.get(id)).filter(Boolean);
  return attachFacilities(ordered);
}

module.exports = { listKos, cardsByIds, cardSelect, attachFacilities, HAVERSINE };
