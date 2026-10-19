// Perintah migrasi:
//   npm run migrate            -> jalankan migrasi yang belum dijalankan
//   npm run migrate:status     -> lihat status tiap migrasi
//   npm run migrate:rollback   -> batalkan batch migrasi terakhir
//   npm run migrate:fresh      -> HAPUS database, migrasi ulang dari nol
//   npm run seed               -> isi data awal (database/seed.sql)
const m = require('./lib/migrator');

const commands = {
  up: async (c) => { await m.migrate(c); },
  rollback: async (c) => { await m.rollback(c); },
  status: async (c) => { await m.status(c); },
  fresh: async (c) => {
    await m.dropDatabase(c);
    await m.useDatabase(c);
    await m.migrate(c);
  },
  seed: async (c) => { await m.seed(c); },
};

(async () => {
  const name = process.argv[2] || 'up';
  if (!commands[name]) {
    console.error(`Perintah "${name}" tidak dikenal. Pilihan: ${Object.keys(commands).join(', ')}`);
    process.exit(1);
  }
  const conn = await m.connect();
  try {
    if (name !== 'fresh') await m.useDatabase(conn);
    await commands[name](conn);
  } catch (err) {
    console.error('\nGagal:', err.sqlMessage || err.message);
    process.exitCode = 1;
  } finally {
    await conn.end();
  }
})();
