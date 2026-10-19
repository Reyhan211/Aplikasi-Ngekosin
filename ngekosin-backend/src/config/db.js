const mysql = require('mysql2/promise');
const env = require('./env');

const pool = mysql.createPool({
  ...env.db,
  waitForConnections: true,
  connectionLimit: 10,
  charset: 'utf8mb4',
  timezone: 'Z',          // DATETIME dibaca/ditulis sebagai UTC
  decimalNumbers: true,   // DECIMAL -> number, bukan string
  dateStrings: ['DATE'],  // kolom DATE tetap "YYYY-MM-DD"
});

// Semua koneksi memakai UTC supaya NOW() / CURRENT_TIMESTAMP konsisten.
pool.pool.on('connection', (conn) => conn.query("SET time_zone = '+00:00'"));

/** Jalankan [fn] di dalam transaksi; otomatis commit / rollback. */
async function withTransaction(fn) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await fn(conn);
    await conn.commit();
    return result;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { db: pool, withTransaction };
