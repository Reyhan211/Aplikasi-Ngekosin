const { db, withTransaction } = require('../config/db');
const { HttpError } = require('../utils/http');
const { rupiah } = require('../utils/format');

const PENDING = ['menunggu_konfirmasi', 'menunggu_pembayaran'];
const ADMIN_FEE = 5000;
const COIN_RATE = 2000; // 1 koin untuk setiap Rp2.000 subtotal saat sewa selesai

const BOOKING_FROM = `
  FROM bookings b
  JOIN kos k         ON k.id = b.kos_id
  JOIN cities c      ON c.id = k.city_id
  JOIN room_types rt ON rt.id = b.room_type_id
  LEFT JOIN payments p ON p.id = (SELECT MAX(id) FROM payments WHERE booking_id = b.id)`;

const BOOKING_COLS = `
  b.*, k.name AS kos_name, k.kos_type, k.district, k.cover_url, k.owner_id, c.name AS city_name,
  rt.name AS room_type_name,
  p.method AS pay_method, p.status AS pay_status, p.paid_at AS pay_paid_at,
  (p.proof_url IS NOT NULL) AS pay_has_proof`;

/** Bentuk JSON booking sesuai Booking.fromJson di aplikasi. */
function toBooking(r) {
  return {
    id: r.id,
    code: r.code,
    user_id: r.user_id,
    kos: {
      id: r.kos_id,
      name: r.kos_name,
      kos_type: r.kos_type,
      location: r.district ? `${r.district}, ${r.city_name}` : r.city_name,
      cover_url: r.cover_url,
    },
    room_type_id: r.room_type_id,
    room_type_name: r.room_type_name,
    checkin_date: r.checkin_date,
    checkout_date: r.checkout_date,
    duration_unit: r.duration_unit,
    duration_count: r.duration_count,
    price_per_unit: r.price_per_unit,
    deposit: r.deposit,
    admin_fee: r.admin_fee,
    discount: r.discount,
    total_amount: r.total_amount,
    occupants: r.occupants,
    tenant_name: r.tenant_name,
    tenant_phone: r.tenant_phone,
    note: r.note,
    promo_code: r.promo_code,
    status: r.status,
    created_at: r.created_at,
    expires_at: r.expires_at,
    payment: r.pay_method
      ? { method: r.pay_method, status: r.pay_status, paid_at: r.pay_paid_at, has_proof: !!r.pay_has_proof }
      : null,
  };
}

/** Kembalikan stok kamar + pulihkan voucher yang dipakai booking ini. */
async function releaseBooking(conn, b) {
  await conn.query('UPDATE room_types SET stock = stock + 1 WHERE id = ?', [b.room_type_id]);
  if (b.promo_code) {
    await conn.query(
      `UPDATE user_vouchers uv JOIN vouchers v ON v.id = uv.voucher_id
          SET uv.used_at = NULL
        WHERE uv.user_id = ? AND v.code = ?`,
      [b.user_id, b.promo_code],
    );
  }
}

/** Pengajuan yang lewat batas waktu 24 jam -> status `kadaluarsa`. */
async function expireStale() {
  await withTransaction(async (conn) => {
    const [rows] = await conn.query(
      `SELECT id, user_id, room_type_id, promo_code FROM bookings
        WHERE status IN ('menunggu_konfirmasi','menunggu_pembayaran')
          AND expires_at IS NOT NULL AND expires_at < NOW()
          FOR UPDATE`,
    );
    for (const b of rows) {
      await conn.query("UPDATE bookings SET status = 'kadaluarsa' WHERE id = ?", [b.id]);
      await releaseBooking(conn, b);
    }
  });
}

async function findBooking(id) {
  const [[row]] = await db.query(`SELECT ${BOOKING_COLS} ${BOOKING_FROM} WHERE b.id = ?`, [id]);
  return row ? toBooking(row) : null;
}

/**
 * Validasi kode promo untuk [userId]. Mengembalikan { voucher, discount }
 * atau melempar HttpError berisi pesan yang ditampilkan di aplikasi.
 */
async function resolveVoucher(conn, userId, rawCode, amount) {
  const code = String(rawCode || '').trim().toUpperCase();
  const invalid = new HttpError(400, 'Kode promo tidak valid atau sudah berakhir');
  if (!code) throw invalid;
  const [[v]] = await conn.query(
    'SELECT * FROM vouchers WHERE code = ? AND is_active = 1 AND expires_at > NOW()',
    [code],
  );
  if (!v) throw invalid;
  const [[mine]] = await conn.query(
    'SELECT used_at FROM user_vouchers WHERE user_id = ? AND voucher_id = ?',
    [userId, v.id],
  );
  if (!v.is_public && !mine) throw new HttpError(400, 'Klaim voucher ini dulu di menu Voucher');
  if (mine && mine.used_at) throw new HttpError(400, 'Kode promo ini sudah kamu pakai');
  if (amount < v.min_amount) throw new HttpError(400, `Minimal sewa ${rupiah(v.min_amount)} untuk kode ini`);
  return { voucher: v, discount: Math.min(v.discount, amount) };
}

module.exports = {
  PENDING, ADMIN_FEE, COIN_RATE, BOOKING_COLS, BOOKING_FROM,
  toBooking, releaseBooking, expireStale, findBooking, resolveVoucher,
};
