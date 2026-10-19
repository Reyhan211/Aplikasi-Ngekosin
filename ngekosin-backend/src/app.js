const path = require('path');
const express = require('express');
const cors = require('cors');
const env = require('./config/env');
const { db } = require('./config/db');
const { wrap, ok } = require('./utils/http');
const { notFound, errorHandler } = require('./middleware/errors');

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 'loopback');
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Gambar yang bisa dibuka publik (aplikasi memuatnya lewat Image.network tanpa header login).
// Bukti pembayaran (uploads/proofs) sengaja TIDAK dibuka di sini; lihat GET /bookings/:id/proof.
const staticOpts = {
  index: false,
  setHeaders: (res) => res.setHeader('X-Content-Type-Options', 'nosniff'),
};
app.use('/uploads/chat', express.static(path.join(env.uploadsDir, 'chat'), staticOpts));
app.use('/uploads/kos', express.static(path.join(env.uploadsDir, 'kos'), staticOpts));

const api = express.Router();
api.get('/health', wrap(async (_req, res) => {
  await db.query('SELECT 1');
  ok(res, { status: 'ok', database: env.db.database });
}));

api.use('/auth', require('./routes/auth'));
api.use(require('./routes/places'));            // /cities, /landmarks
api.use('/kos', require('./routes/kos'));       // /kos, /kos/:id, /kos/:id/reviews
api.use(require('./routes/user'));              // /favorites, /recently-viewed, /coins, /vouchers, /promos
api.use('/bookings', require('./routes/bookings'));
api.use('/chat', require('./routes/chat'));
const { ownerRouter, adminRouter } = require('./routes/owner');
api.use('/owner', ownerRouter);
api.use('/admin', adminRouter);

app.use('/api/v1', api);
app.get('/', (_req, res) => res.json({ name: 'Ngekos.in API', version: 'v1', base: '/api/v1', health: '/api/v1/health' }));

app.use(notFound);
app.use(errorHandler);

module.exports = app;
