const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const multer = require('multer');
const env = require('../config/env');
const { HttpError } = require('./http');

// Gambar ditahan di memori (maks. 5 MB), diperiksa isinya, baru ditulis ke disk.
// Pemeriksaan "magic bytes" dipakai karena Flutter sering mengirim gambar
// dengan content-type application/octet-stream.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 1 },
});

function sniffImage(buf) {
  if (buf.length < 12) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  if (buf.slice(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'png';
  if (buf.slice(0, 4).toString('latin1') === 'GIF8') return 'gif';
  if (buf.slice(0, 4).toString('latin1') === 'RIFF' && buf.slice(8, 12).toString('latin1') === 'WEBP') return 'webp';
  if (buf.slice(4, 8).toString('latin1') === 'ftyp') return 'heic';
  return null;
}

/**
 * Simpan file hasil multer ke uploads/<subdir>/ dan kembalikan path relatif
 * ("uploads/chat/abc.jpg") yang disimpan di database.
 */
async function saveImage(file, subdir) {
  const ext = sniffImage(file.buffer);
  if (!ext) throw new HttpError(400, 'File harus berupa gambar (JPG, PNG, WEBP, GIF)');
  const dir = path.join(env.uploadsDir, subdir);
  await fs.promises.mkdir(dir, { recursive: true });
  const name = `${Date.now()}-${crypto.randomBytes(8).toString('hex')}.${ext}`;
  await fs.promises.writeFile(path.join(dir, name), file.buffer);
  return `uploads/${subdir}/${name}`;
}

module.exports = { upload, saveImage };
