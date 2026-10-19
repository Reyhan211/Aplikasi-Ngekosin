const os = require('os');
const env = require('./config/env');
const { db } = require('./config/db');
const app = require('./app');
const { expireStale } = require('./services/bookings');

function lanAddresses() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((i) => i && i.family === 'IPv4' && !i.internal)
    .map((i) => i.address);
}

async function main() {
  try {
    await db.query('SELECT 1 FROM users LIMIT 1');
  } catch (err) {
    console.error('\n[!] Tidak bisa membaca database "' + env.db.database + '": ' + (err.code || err.message));
    if (err.code === 'ECONNREFUSED') console.error('    MySQL belum jalan. Buka Laragon lalu klik "Start All".');
    else if (err.code === 'ER_BAD_DB_ERROR' || err.code === 'ER_NO_SUCH_TABLE') console.error('    Database belum dibuat. Jalankan:  npm run db:setup');
    else if (err.code === 'ER_ACCESS_DENIED_ERROR') console.error('    User/password MySQL salah. Periksa DB_USER dan DB_PASSWORD di file .env');
    process.exit(1);
  }

  // Pengajuan sewa yang lewat 24 jam otomatis kedaluwarsa dan stoknya dikembalikan.
  setInterval(() => expireStale().catch((e) => console.error('[expire]', e.message)), 5 * 60 * 1000).unref();

  app.listen(env.port, '0.0.0.0', () => {
    console.log(`\nNgekos.in API berjalan di port ${env.port}`);
    console.log(`  Komputer ini       : http://localhost:${env.port}/api/v1`);
    console.log(`  Emulator Android   : http://10.0.2.2:${env.port}/api/v1`);
    for (const ip of lanAddresses()) console.log(`  HP fisik (satu WiFi): http://${ip}:${env.port}/api/v1`);
    console.log('');
  });
}

main();
