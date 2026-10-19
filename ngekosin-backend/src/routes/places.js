const router = require('express').Router();
const { db } = require('../config/db');
const { wrap, ok } = require('../utils/http');

// GET /cities/popular -> "Area Kos Populer"
router.get('/cities/popular', wrap(async (_req, res) => {
  const [rows] = await db.query(
    `SELECT c.id, c.name, c.image_url,
            (SELECT COUNT(*) FROM kos k WHERE k.city_id = c.id AND k.is_active = 1) AS kos_count
       FROM cities c WHERE c.is_popular = 1 ORDER BY c.sort_order, c.id`,
  );
  ok(res, rows);
}));

// GET /cities
router.get('/cities', wrap(async (_req, res) => {
  const [rows] = await db.query(
    `SELECT c.id, c.name, c.image_url,
            (SELECT COUNT(*) FROM kos k WHERE k.city_id = c.id AND k.is_active = 1) AS kos_count
       FROM cities c ORDER BY c.name`,
  );
  ok(res, rows);
}));

// GET /landmarks?type=kampus&q=&popular=1&city_id=
router.get('/landmarks', wrap(async (req, res) => {
  const where = [];
  const params = [];
  if (req.query.type) {
    where.push('l.type = ?');
    params.push(String(req.query.type));
  }
  if (req.query.popular === '1') where.push('l.is_popular = 1');
  if (Number(req.query.city_id) > 0) {
    where.push('l.city_id = ?');
    params.push(Number(req.query.city_id));
  }
  const tokens = String(req.query.q || '').toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
  for (const t of tokens) {
    where.push('(l.short_name LIKE ? OR l.name LIKE ? OR l.city_label LIKE ?)');
    params.push(`%${t}%`, `%${t}%`, `%${t}%`);
  }
  const [rows] = await db.query(
    `SELECT l.id, l.type, l.short_name, l.name, l.city_label AS city, l.latitude, l.longitude
       FROM landmarks l ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      ORDER BY l.sort_order, l.id LIMIT 50`,
    params,
  );
  ok(res, rows);
}));

module.exports = router;
