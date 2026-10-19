/** "Raka Pratama" -> "Raka P." (nama pada ulasan) */
function shortName(name = '') {
  const p = String(name).trim().split(/\s+/);
  if (!p[0]) return 'Pengguna';
  return p.length > 1 ? `${p[0]} ${p[1][0].toUpperCase()}.` : p[0];
}

const rupiah = (n) => 'Rp' + Number(n).toLocaleString('id-ID');

const pad = (n, len) => String(n).padStart(len, '0');

// ---------- tanggal (semua dihitung UTC; format "YYYY-MM-DD") ----------
function parseDate(s) {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const d = new Date(`${s}T00:00:00Z`);
  return Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== s ? null : d;
}
const fmtDate = (d) => d.toISOString().slice(0, 10);
const todayUtc = () => parseDate(fmtDate(new Date()));

/** Tambah bulan tanpa "meluber": 31 Jan + 1 bulan = 28/29 Feb. */
function addMonths(d, n) {
  const m = d.getUTCMonth() + n;
  const y = d.getUTCFullYear() + Math.floor(m / 12);
  const mo = ((m % 12) + 12) % 12;
  const last = new Date(Date.UTC(y, mo + 1, 0)).getUTCDate();
  return new Date(Date.UTC(y, mo, Math.min(d.getUTCDate(), last)));
}

/** Tanggal selesai sewa; aturannya sama dengan DurationUnit.endDate di aplikasi. */
function endDate(start, unit, count) {
  const addDays = (n) => new Date(start.getTime() + n * 86400000);
  switch (unit) {
    case 'harian': return addDays(count);
    case 'mingguan': return addDays(7 * count);
    case 'bulanan': return addMonths(start, count);
    case 'tahunan': return addMonths(start, 12 * count);
    default: return start;
  }
}

/** Batas jumlah periode per satuan (sama dengan DurationUnit.maxCount di aplikasi). */
const MAX_COUNT = { harian: 30, mingguan: 8, bulanan: 12, tahunan: 3 };

module.exports = { shortName, rupiah, pad, parseDate, fmtDate, todayUtc, endDate, MAX_COUNT };
