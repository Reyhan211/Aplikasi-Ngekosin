const router = require('express').Router();
const { db, withTransaction } = require('../config/db');
const { HttpError, wrap, ok, idParam, toInt } = require('../utils/http');
const { auth } = require('../middleware/auth');
const { upload, saveImage } = require('../utils/upload');

router.use(auth);

const ROOM_SELECT = `
  SELECT r.id, r.kos_id, r.user_id, r.owner_id, r.last_message, r.last_message_at,
         k.name AS kos_name, k.cover_url,
         CASE WHEN r.user_id = ? THEN ou.name ELSE uu.name END AS other_name,
         CASE WHEN r.user_id = ? THEN r.user_unread ELSE r.owner_unread END AS unread_count
    FROM chat_rooms r
    JOIN kos k ON k.id = r.kos_id
    JOIN users uu ON uu.id = r.user_id
    JOIN users ou ON ou.id = r.owner_id`;

const toRoom = (r) => ({
  id: r.id,
  kos: { id: r.kos_id, name: r.kos_name, cover_url: r.cover_url },
  other_name: r.other_name,
  last_message: r.last_message,
  last_message_at: r.last_message_at,
  unread_count: r.unread_count,
});

async function getRoom(id, me) {
  const [[room]] = await db.query(`${ROOM_SELECT} WHERE r.id = ? AND (r.user_id = ? OR r.owner_id = ?)`, [me, me, id, me, me]);
  if (!room) throw new HttpError(404, 'Percakapan tidak ditemukan');
  return room;
}

// GET /chat/rooms
router.get('/rooms', wrap(async (req, res) => {
  const me = req.user.id;
  const [rows] = await db.query(
    `${ROOM_SELECT} WHERE r.user_id = ? OR r.owner_id = ?
      ORDER BY r.last_message_at IS NULL, r.last_message_at DESC, r.id DESC`,
    [me, me, me, me],
  );
  ok(res, rows.map(toRoom));
}));

// POST /chat/rooms  { kos_id }  -> membuat room, atau mengembalikan room yang sudah ada
router.post('/rooms', wrap(async (req, res) => {
  const kosId = toInt(req.body.kos_id);
  if (!(kosId > 0)) throw new HttpError(422, 'kos_id wajib diisi');
  const [[kos]] = await db.query('SELECT id, owner_id FROM kos WHERE id = ? AND is_active = 1', [kosId]);
  if (!kos) throw new HttpError(404, 'Kos tidak ditemukan');
  if (kos.owner_id === req.user.id) throw new HttpError(403, 'Kamu tidak bisa chat dengan kos milik sendiri');

  const [ins] = await db.query(
    'INSERT IGNORE INTO chat_rooms (kos_id, user_id, owner_id) VALUES (?, ?, ?)',
    [kosId, req.user.id, kos.owner_id],
  );
  const [[found]] = await db.query('SELECT id FROM chat_rooms WHERE kos_id = ? AND user_id = ?', [kosId, req.user.id]);
  ok(res, toRoom(await getRoom(found.id, req.user.id)), ins.affectedRows ? 201 : 200);
}));

const toMessage = (m) => ({
  id: m.id,
  room_id: m.room_id,
  sender_id: m.sender_id,
  body: m.body || '',
  image_url: m.image_url,
  created_at: m.created_at,
});

// GET /chat/rooms/:id/messages?after_id=  (dipakai polling; juga menandai terbaca)
router.get('/rooms/:id/messages', wrap(async (req, res) => {
  const room = await getRoom(idParam(req), req.user.id);
  const after = Math.max(parseInt(req.query.after_id, 10) || 0, 0);
  const [rows] = await db.query(
    'SELECT * FROM chat_messages WHERE room_id = ? AND id > ? ORDER BY id ASC LIMIT 500', [room.id, after]);
  if (room.unread_count > 0) {
    const col = room.user_id === req.user.id ? 'user_unread' : 'owner_unread';
    await db.query(`UPDATE chat_rooms SET ${col} = 0 WHERE id = ?`, [room.id]);
  }
  ok(res, rows.map(toMessage));
}));

// POST /chat/rooms/:id/messages  (multipart/form-data atau JSON: body, image)
router.post('/rooms/:id/messages', upload.single('image'), wrap(async (req, res) => {
  const room = await getRoom(idParam(req), req.user.id);
  const body = String(req.body.body || '').trim();
  if (body.length > 2000) throw new HttpError(422, 'Pesan maksimal 2000 karakter');
  if (!body && !req.file) throw new HttpError(422, 'Pesan kosong');
  const imageUrl = req.file ? await saveImage(req.file, 'chat') : null;

  const msg = await withTransaction(async (conn) => {
    const [ins] = await conn.query(
      'INSERT INTO chat_messages (room_id, sender_id, body, image_url) VALUES (?, ?, ?, ?)',
      [room.id, req.user.id, body || null, imageUrl],
    );
    const otherCol = room.user_id === req.user.id ? 'owner_unread' : 'user_unread';
    await conn.query(
      `UPDATE chat_rooms SET last_message = ?, last_message_at = NOW(), ${otherCol} = ${otherCol} + 1 WHERE id = ?`,
      [(body || '📷 Foto').slice(0, 255), room.id],
    );
    const [[m]] = await conn.query('SELECT * FROM chat_messages WHERE id = ?', [ins.insertId]);
    return m;
  });
  ok(res, toMessage(msg), 201);
}));

module.exports = router;
