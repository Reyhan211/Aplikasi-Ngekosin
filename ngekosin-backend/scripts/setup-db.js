// Membuat database + tabel + data awal.
//   npm run db:setup   -> buat database; isi data awal bila masih kosong
//   npm run db:reset   -> HAPUS database lalu buat ulang dari nol
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const env = require('../src/config/env');

const reset = process.argv.includes('--reset');
const read = (f) => fs.readFileSync(path.join(__dirname, '..', 'database', f), 'utf8');

async function main() {
  let conn;
  try {
    conn = await mysql.createConnection({
      host: env.db.host,
      port: env.db.port,
      user: env.db.user,
      password: env.db.password,
      charset: 'utf8mb4',
      multipleStatements: true,
    });
  } catch (err) {
    console.error('Gagal terhubung ke MySQL:', err.code || err.message);
    if (err.code === 'ECONNREFUSED') console.error('-> Buka Laragon lalu klik "Start All" (pastikan MySQL hijau).');
    if (err.code === 'ER_ACCESS_DENIED_ERROR') console.error('-> Periksa DB_USER / DB_PASSWORD di file .env');
    process.exit(1);
  }

  try {
    if (reset) {
      console.log(`Menghapus database "${env.db.database}" ...`);
      await conn.query(`DROP DATABASE IF EXISTS \`${env.db.database}\``);
    }
    console.log('Membuat database dan tabel (schema.sql) ...');
    await conn.query(read('schema.sql'));

    const [[{ n }]] = await conn.query('SELECT COUNT(*) AS n FROM users');
    if (n === 0) {
      console.log('Mengisi data awal (seed.sql) ...');
      await conn.query(read('seed.sql'));
    } else {
      console.log('Data sudah ada, seed dilewati. (Pakai "npm run db:reset" untuk mulai dari nol.)');
    }

    const [[c]] = await conn.query(
      `SELECT (SELECT COUNT(*) FROM users) AS users, (SELECT COUNT(*) FROM kos) AS kos,
              (SELECT COUNT(*) FROM room_types) AS rooms, (SELECT COUNT(*) FROM reviews) AS reviews`);
    console.log(`\nSelesai. Database "${env.db.database}": ${c.users} user, ${c.kos} kos, ${c.rooms} tipe kamar, ${c.reviews} ulasan.`);
    console.log('\nAkun demo:');
    console.log('  raka@ngekos.in   / password123   (pencari kos, username: raka)');
    console.log('  sari@ngekos.in   / password123   (pemilik kos, username: sari)');
    console.log('  admin@ngekos.in  / admin123      (admin, username: admin)');
    console.log('  (login bisa pakai email ATAU username)');
  } catch (err) {
    console.error('\nSetup gagal:', err.sqlMessage || err.message);
    process.exitCode = 1;
  } finally {
    await conn.end();
  }
}

main();
