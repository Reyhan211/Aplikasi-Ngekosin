const router = require('express').Router();
const bcrypt = require('bcryptjs');
const env = require('../config/env');
const { db, withTransaction } = require('../config/db');
const { HttpError, wrap, ok } = require('../utils/http');
const { signToken, auth, rateLimit } = require('../middleware/auth');

const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: env.authRateLimit });
const checkLimiter = rateLimit({ windowMs: 60 * 1000, max: 60 });
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_RE = /^\+?[0-9]{8,15}$/;
// 3-30 karakter: huruf kecil, angka, titik, garis bawah; tidak diawali/diakhiri . atau _ dan tanpa ".." / "__"
const USERNAME_RE = /^(?![._])(?!.*[._]{2})[a-z0-9._]{3,30}(?<![._])$/;
const RESERVED = new Set(['admin', 'administrator', 'root', 'system', 'support', 'api', 'ngekos', 'ngekosin', 'owner', 'pemilik', 'null', 'undefined']);

const normUsername = (v) => String(v || '').trim().replace(/^@/, '').toLowerCase();

/** Lempar 422 bila username tidak memenuhi aturan. */
function assertUsername(u) {
  if (!USERNAME_RE.test(u)) {
    throw new HttpError(422, 'Username 3-30 karakter: huruf kecil, angka, titik, atau garis bawah (tidak diawali/diakhiri simbol)');
  }
  if (RESERVED.has(u)) throw new HttpError(422, 'Username ini tidak tersedia');
}

const publicUser = (u) => ({
  id: u.id,
  name: u.name,
  username: u.username,
  email: u.email,
  role: u.role,
  phone: u.phone,
  owner_status: u.owner_status,
});

const cleanPhone = (p) => (p == null ? null : String(p).replace(/[\s-]/g, '') || null);

// POST /auth/register  { name, username, email, phone?, password, role? }
// role "pemilik" => akun dibuat sebagai pencari + pengajuan pemilik (menunggu admin).
router.post('/register', limiter, wrap(async (req, res) => {
  const name = String(req.body.name || '').trim();
  const username = normUsername(req.body.username);
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  const phone = cleanPhone(req.body.phone);
  const wantsOwner = req.body.role === 'pemilik';

  if (name.length < 2 || name.length > 100) throw new HttpError(422, 'Nama harus 2-100 karakter');
  assertUsername(username);
  if (!EMAIL_RE.test(email) || email.length > 150) throw new HttpError(422, 'Format email tidak valid');
  if (password.length < 8) throw new HttpError(422, 'Kata sandi minimal 8 karakter');
  if (phone && !PHONE_RE.test(phone)) throw new HttpError(422, 'Nomor HP tidak valid');

  const [[dupEmail]] = await db.query('SELECT id FROM users WHERE email = ?', [email]);
  if (dupEmail) throw new HttpError(409, 'Email sudah terdaftar');
  const [[dupUser]] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
  if (dupUser) throw new HttpError(409, 'Username sudah dipakai');

  const hash = await bcrypt.hash(password, 10);
  const user = await withTransaction(async (conn) => {
    const [r] = await conn.query(
      `INSERT INTO users (name, username, email, password_hash, phone, role, owner_status, coins)
       VALUES (?, ?, ?, ?, ?, 'pencari', ?, 500)`,
      [name, username, email, hash, phone, wantsOwner ? 'pending' : 'none'],
    ).catch((e) => {
      // dua orang mendaftar bersamaan dengan data yang sama
      if (e.code === 'ER_DUP_ENTRY') {
        throw new HttpError(409, String(e.sqlMessage).includes('username') ? 'Username sudah dipakai' : 'Email sudah terdaftar');
      }
      throw e;
    });
    await conn.query(
      "INSERT INTO coin_transactions (user_id, title, amount) VALUES (?, 'Bonus akun baru', 500)",
      [r.insertId],
    );
    const [[u]] = await conn.query('SELECT * FROM users WHERE id = ?', [r.insertId]);
    return u;
  });
  ok(res, { token: signToken(user), user: publicUser(user) }, 201);
}));

// POST /auth/login  { login | email | username, password }
// Identitas boleh berupa email ATAU username (aplikasi lama yang mengirim "email" tetap jalan).
router.post('/login', limiter, wrap(async (req, res) => {
  const ident = String(req.body.login ?? req.body.email ?? req.body.username ?? '').trim();
  const password = String(req.body.password || '');
  if (!ident || !password) throw new HttpError(422, 'Email/username dan kata sandi wajib diisi');
  const byEmail = ident.includes('@') && !ident.startsWith('@');
  const [[user]] = await db.query(
    `SELECT * FROM users WHERE ${byEmail ? 'email' : 'username'} = ?`,
    [byEmail ? ident.toLowerCase() : normUsername(ident)],
  );
  const valid = user && (await bcrypt.compare(password, user.password_hash));
  if (!valid) throw new HttpError(401, 'Email/username atau kata sandi salah');
  ok(res, { token: signToken(user), user: publicUser(user) });
}));

// GET /auth/check-username?username=  -> { available, reason? }  (dipakai form daftar)
router.get('/check-username', checkLimiter, wrap(async (req, res) => {
  const u = normUsername(req.query.username);
  if (!USERNAME_RE.test(u) || RESERVED.has(u)) return ok(res, { available: false, reason: 'format' });
  const [[hit]] = await db.query('SELECT id FROM users WHERE username = ?', [u]);
  ok(res, { available: !hit });
}));

// GET /auth/me
router.get('/me', auth, wrap(async (req, res) => ok(res, publicUser(req.user))));

// PUT /auth/profile  { name, phone? }
router.put('/profile', auth, wrap(async (req, res) => {
  const name = String(req.body.name || '').trim();
  const phone = cleanPhone(req.body.phone);
  if (name.length < 2 || name.length > 100) throw new HttpError(422, 'Nama harus 2-100 karakter');
  if (phone && !PHONE_RE.test(phone)) throw new HttpError(422, 'Nomor HP tidak valid');
  await db.query('UPDATE users SET name = ?, phone = ? WHERE id = ?', [name, phone, req.user.id]);
  ok(res, publicUser({ ...req.user, name, phone }));
}));

// PUT /auth/password  { old_password, new_password }
router.put('/password', auth, wrap(async (req, res) => {
  const oldPw = String(req.body.old_password || '');
  const newPw = String(req.body.new_password || '');
  if (newPw.length < 8) throw new HttpError(422, 'Kata sandi baru minimal 8 karakter');
  const [[u]] = await db.query('SELECT password_hash FROM users WHERE id = ?', [req.user.id]);
  if (!(await bcrypt.compare(oldPw, u.password_hash))) throw new HttpError(400, 'Kata sandi lama salah');
  await db.query('UPDATE users SET password_hash = ? WHERE id = ?', [await bcrypt.hash(newPw, 10), req.user.id]);
  ok(res, null);
}));

module.exports = router;
