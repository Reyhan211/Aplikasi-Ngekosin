const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });

const env = {
  port: Number(process.env.PORT) || 3000,
  db: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'ngekosin',
  },
  jwtSecret: process.env.JWT_SECRET || 'ngekosin-dev-secret-ganti-di-produksi',
  jwtExpires: process.env.JWT_EXPIRES || '30d',
  authRateLimit: Number(process.env.AUTH_RATE_LIMIT) || 60,
  uploadsDir: path.join(__dirname, '..', '..', 'uploads'),
};

if (process.env.NODE_ENV === 'production' && !process.env.JWT_SECRET) {
  console.error('JWT_SECRET wajib diisi saat NODE_ENV=production.');
  process.exit(1);
}

module.exports = env;
