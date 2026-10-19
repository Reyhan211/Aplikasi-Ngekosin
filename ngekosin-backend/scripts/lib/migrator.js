// Pelaksana migrasi sederhana (mirip Laravel/Knex): file SQL bernomor di database/migrations,
// riwayatnya dicatat di tabel `migrations`.
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const env = require('../../src/config/env');

const DIR = path.join(__dirname, '..', '..', 'database', 'migrations');
const SEED = path.join(__dirname, '..', '..', 'database', 'seed.sql');
const DB = env.db.database;
const q = (s) => '`' + s + '`';

/** Sambung ke MySQL (tanpa memilih database dulu). */
async function connect() {
  try {
    return await mysql.createConnection({
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
}

/** Buat database bila belum ada, lalu pakai. */
async function useDatabase(conn) {
  await conn.query(`CREATE DATABASE IF NOT EXISTS ${q(DB)} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  await conn.query(`USE ${q(DB)}`);
  await conn.query(`CREATE TABLE IF NOT EXISTS \`migrations\` (
    \`id\` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    \`migration\` VARCHAR(190) NOT NULL,
    \`batch\` INT NOT NULL,
    \`executed_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (\`id\`),
    UNIQUE KEY \`uq_migrations_name\` (\`migration\`)
  ) ENGINE=InnoDB`);
}

function files() {
  return fs.readdirSync(DIR).filter((f) => f.endsWith('.sql')).sort();
}

/** Pisahkan bagian "-- +migrate Up" dan "-- +migrate Down" dari satu file. */
function parse(file) {
  const text = fs.readFileSync(path.join(DIR, file), 'utf8');
  const upAt = text.indexOf('-- +migrate Up');
  const downAt = text.indexOf('-- +migrate Down');
  if (upAt === -1) throw new Error(`${file}: penanda "-- +migrate Up" tidak ditemukan`);
  const up = text.slice(upAt + '-- +migrate Up'.length, downAt === -1 ? undefined : downAt).trim();
  const down = downAt === -1 ? '' : text.slice(downAt + '-- +migrate Down'.length).trim();
  return { up, down };
}

async function executed(conn) {
  const [rows] = await conn.query('SELECT migration, batch FROM `migrations` ORDER BY id');
  return rows;
}

/** Jalankan semua migrasi yang belum dijalankan. */
async function migrate(conn) {
  let done = await executed(conn);
  const all = files();

  // Database lama (dibuat dari schema.sql, belum ada catatan migrasi): tandai saja, jangan buat ulang.
  if (done.length === 0) {
    const [[{ n }]] = await conn.query(
      "SELECT COUNT(*) AS n FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'users'", [DB]);
    if (n > 0) {
      console.log('Database lama terdeteksi (tabel sudah ada). Migrasi ditandai sudah dijalankan.');
      for (const f of all) await conn.query('INSERT INTO `migrations` (migration, batch) VALUES (?, 1)', [f]);
      return 0;
    }
  }

  const have = new Set(done.map((r) => r.migration));
  const pending = all.filter((f) => !have.has(f));
  if (!pending.length) {
    console.log('Tidak ada migrasi baru. Semua sudah dijalankan.');
    return 0;
  }
  const batch = done.reduce((m, r) => Math.max(m, r.batch), 0) + 1;
  for (const f of pending) {
    process.stdout.write(`Migrating : ${f} ... `);
    try {
      await conn.query(parse(f).up);
      await conn.query('INSERT INTO `migrations` (migration, batch) VALUES (?, ?)', [f, batch]);
      console.log('selesai');
    } catch (err) {
      console.log('GAGAL');
      throw err;
    }
  }
  return pending.length;
}

/** Batalkan batch migrasi terakhir (urutan dibalik). */
async function rollback(conn) {
  const done = await executed(conn);
  if (!done.length) {
    console.log('Tidak ada migrasi untuk dibatalkan.');
    return 0;
  }
  const last = Math.max(...done.map((r) => r.batch));
  const batch = done.filter((r) => r.batch === last).reverse();
  await conn.query('SET FOREIGN_KEY_CHECKS = 0');
  try {
    for (const r of batch) {
      process.stdout.write(`Rolling back: ${r.migration} ... `);
      const { down } = parse(r.migration);
      if (down) await conn.query(down);
      await conn.query('DELETE FROM `migrations` WHERE migration = ?', [r.migration]);
      console.log('selesai');
    }
  } finally {
    await conn.query('SET FOREIGN_KEY_CHECKS = 1');
  }
  return batch.length;
}

async function status(conn) {
  const done = new Map((await executed(conn)).map((r) => [r.migration, r.batch]));
  console.log('\nStatus  Batch  Migrasi');
  for (const f of files()) {
    console.log(`${done.has(f) ? 'Ran    ' : 'Pending'}  ${String(done.get(f) ?? '-').padEnd(5)}  ${f}`);
  }
  console.log('');
}

/** Hapus seluruh database lalu buat ulang (SEMUA DATA HILANG). */
async function dropDatabase(conn) {
  console.log(`Menghapus database "${DB}" ...`);
  await conn.query(`DROP DATABASE IF EXISTS ${q(DB)}`);
}

/** Isi data awal. onlyIfEmpty: lewati bila tabel users sudah berisi. */
async function seed(conn, { onlyIfEmpty = false } = {}) {
  if (onlyIfEmpty) {
    const [[{ n }]] = await conn.query('SELECT COUNT(*) AS n FROM users');
    if (n > 0) {
      console.log('Data sudah ada, seed dilewati. (Pakai "npm run db:reset" untuk mulai dari nol.)');
      return false;
    }
  }
  console.log('Mengisi data awal (database/seed.sql) ...');
  await conn.query(fs.readFileSync(SEED, 'utf8'));
  return true;
}

module.exports = { connect, useDatabase, migrate, rollback, status, dropDatabase, seed, DB };
