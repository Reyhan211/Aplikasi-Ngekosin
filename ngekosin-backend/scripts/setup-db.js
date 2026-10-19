// Satu perintah untuk menyiapkan database:
//   npm run db:setup   -> buat database, jalankan migrasi, isi data awal bila masih kosong
//   npm run db:reset   -> HAPUS database lalu buat ulang dari nol (migrasi + data awal)
const m = require('./lib/migrator');

const reset = process.argv.includes('--reset');

(async () => {
  const conn = await m.connect();
  try {
    if (reset) await m.dropDatabase(conn);
    await m.useDatabase(conn);
    console.log('Menjalankan migrasi (database/migrations) ...');
    await m.migrate(conn);
    await m.seed(conn, { onlyIfEmpty: !reset });

    const [[c]] = await conn.query(
      `SELECT (SELECT COUNT(*) FROM users) AS users, (SELECT COUNT(*) FROM kos) AS kos,
              (SELECT COUNT(*) FROM room_types) AS rooms, (SELECT COUNT(*) FROM reviews) AS reviews`);
    console.log(`\nSelesai. Database "${m.DB}": ${c.users} user, ${c.kos} kos, ${c.rooms} tipe kamar, ${c.reviews} ulasan.`);
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
})();
