const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { db } = require('../config/db');
const { HttpError, wrap } = require('../utils/http');

const signToken = (user) =>
  jwt.sign({ id: user.id, role: user.role }, env.jwtSecret, { expiresIn: env.jwtExpires });

async function loadUser(req) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return null;
  let payload;
  try {
    payload = jwt.verify(token, env.jwtSecret);
  } catch {
    throw new HttpError(401, 'Sesi berakhir, silakan login ulang');
  }
  const [[user]] = await db.query(
    'SELECT id, name, username, email, phone, role, owner_status FROM users WHERE id = ?',
    [payload.id],
  );
  if (!user) throw new HttpError(401, 'Akun tidak ditemukan, silakan login ulang');
  return user;
}

/** Wajib login. Mengisi req.user. */
const auth = wrap(async (req, _res, next) => {
  const user = await loadUser(req);
  if (!user) throw new HttpError(401, 'Silakan login terlebih dahulu');
  req.user = user;
  next();
});

/** Login opsional: req.user terisi bila token valid, selain itu null. */
const optionalAuth = wrap(async (req, _res, next) => {
  req.user = (await loadUser(req)) || null;
  next();
});

/** Batasi akses berdasarkan peran. Pakai setelah [auth]. */
const requireRole = (...roles) => (req, _res, next) => {
  if (!roles.includes(req.user.role)) {
    return next(new HttpError(403, 'Kamu tidak punya akses ke fitur ini'));
  }
  next();
};

/** Pembatas sederhana (di memori) per IP, untuk endpoint login/daftar. */
function rateLimit({ windowMs, max }) {
  const hits = new Map();
  setInterval(() => {
    const now = Date.now();
    for (const [k, v] of hits) if (v.reset < now) hits.delete(k);
  }, windowMs).unref();
  return (req, _res, next) => {
    const now = Date.now();
    const key = req.ip;
    let h = hits.get(key);
    if (!h || h.reset < now) h = { count: 0, reset: now + windowMs };
    h.count += 1;
    hits.set(key, h);
    if (h.count > max) return next(new HttpError(429, 'Terlalu banyak percobaan, coba lagi beberapa menit lagi'));
    next();
  };
}

module.exports = { signToken, auth, optionalAuth, requireRole, rateLimit };
