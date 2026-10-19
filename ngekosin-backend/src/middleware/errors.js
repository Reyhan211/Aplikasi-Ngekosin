const multer = require('multer');
const { HttpError } = require('../utils/http');

const notFound = (req, _res, next) =>
  next(new HttpError(404, `Endpoint ${req.method} ${req.originalUrl} tidak ditemukan`));

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, _next) {
  let status = 500;
  let message = 'Terjadi kesalahan pada server';

  if (err instanceof HttpError) {
    status = err.status;
    message = err.message;
  } else if (err instanceof multer.MulterError) {
    status = 400;
    message = err.code === 'LIMIT_FILE_SIZE' ? 'Ukuran gambar maksimal 5 MB' : 'Upload file gagal';
  } else if (err.type === 'entity.parse.failed') {
    status = 400;
    message = 'Format JSON tidak valid';
  } else if (err.code === 'ER_DUP_ENTRY') {
    status = 409;
    message = 'Data sudah ada';
  } else {
    console.error(`[ERROR] ${req.method} ${req.originalUrl}`, err);
  }

  res.status(status).json({ success: false, message });
}

module.exports = { notFound, errorHandler };
