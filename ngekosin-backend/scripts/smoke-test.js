// Uji menyeluruh REST API. Jalankan server dulu (npm start), lalu:  npm run test:api
// Aman dijalankan berulang kali: memakai akun baru dengan email acak.
const BASE = process.env.API_URL || 'http://localhost:3000/api/v1';

let passed = 0;
let failed = 0;
const failures = [];

function check(name, cond, extra = '') {
  if (cond) {
    passed += 1;
    console.log(`  \x1b[32m✓\x1b[0m ${name}`);
  } else {
    failed += 1;
    failures.push(name);
    console.log(`  \x1b[31m✗ ${name}\x1b[0m ${extra}`);
  }
}
const section = (t) => console.log(`\n\x1b[1m${t}\x1b[0m`);

async function call(method, path, { token, json, form, query } = {}) {
  const url = new URL(BASE + path);
  for (const [k, v] of Object.entries(query || {})) url.searchParams.set(k, v);
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  let body;
  if (json) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(json);
  } else if (form) {
    body = form;
  }
  const res = await fetch(url, { method, headers, body });
  let data = null;
  try { data = await res.json(); } catch { /* bukan JSON */ }
  return { status: res.status, ok: data?.success === true, data: data?.data, message: data?.message };
}
const get = (p, o) => call('GET', p, o);
const post = (p, json, o = {}) => call('POST', p, { ...o, json });

// PNG 1x1 valid, dikirim sebagai application/octet-stream seperti Flutter fromBytes
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64');
const imageForm = (field, extra = {}) => {
  const f = new FormData();
  for (const [k, v] of Object.entries(extra)) f.append(k, v);
  f.append(field, new Blob([PNG], { type: 'application/octet-stream' }), 'foto.png');
  return f;
};

const tomorrow = () => new Date(Date.now() + 86400000).toISOString().slice(0, 10);

async function main() {
  const stamp = Date.now();

  section('Health & data publik');
  let r = await get('/health');
  check('GET /health', r.ok && r.data.status === 'ok');

  r = await get('/cities/popular');
  check('GET /cities/popular -> 7 kota', r.ok && r.data.length === 7);
  check('  urutan Yogyakarta, Jakarta, ... & kos_count terisi', r.data[0].name === 'Yogyakarta' && r.data.find((c) => c.name === 'Surabaya').kos_count === 6);

  r = await get('/landmarks', { query: { type: 'kampus', popular: '1' } });
  check('GET /landmarks?type=kampus -> 11 kampus', r.ok && r.data.length === 11);
  check('  field short_name & city ada', r.data[0].short_name === 'UGM' && r.data[0].city === 'Jogja');
  r = await get('/landmarks', { query: { type: 'kampus', q: 'universitas negeri surabaya' } });
  check('GET /landmarks?q=universitas negeri surabaya -> UNESA', r.ok && r.data.length === 1 && r.data[0].short_name === 'UNESA');

  section('Daftar kos, pencarian & filter');
  r = await get('/kos');
  check('GET /kos -> 18 kos', r.ok && r.data.length === 18, `dapat ${r.data?.length}`);
  const k1 = r.data.find((k) => k.id === 1);
  check('  bentuk kartu (id, kos_type, city, min_price, rating, facilities)',
    k1.kos_type === 'putri' && k1.city === 'Malang' && k1.min_price === 1200000 && k1.rating_avg === 4.7 &&
    k1.available_rooms === 3 && k1.facilities.length === 4 && k1.is_favorite === false, JSON.stringify(k1));
  check('  rekomendasi: urut rating lalu jumlah ulasan (Anggrek 4.8/64 dulu)', r.data[0].id === 3 && r.data[1].id === 13);

  r = await get('/kos', { query: { type: 'putri' } });
  check('filter type=putri', r.ok && r.data.length > 0 && r.data.every((k) => k.kos_type === 'putri'));
  r = await get('/kos', { query: { city_id: 4 } });
  check('filter city_id=4 (Surabaya) -> 6 kos', r.ok && r.data.length === 6);
  r = await get('/kos', { query: { sort: 'price_asc' } });
  check('sort=price_asc -> termurah Rp750.000', r.data[0].min_price === 750000);
  r = await get('/kos', { query: { sort: 'price_desc' } });
  check('sort=price_desc -> termahal Rp2.600.000', r.data[0].min_price === 2600000);
  r = await get('/kos', { query: { available: '1' } });
  check('available=1 -> kos penuh (id 12) tidak muncul', r.data.length === 17 && !r.data.some((k) => k.id === 12));
  r = await get('/kos', { query: { promo: '1' } });
  check('promo=1 -> 6 kos berlabel diskon', r.data.length === 6 && r.data.every((k) => k.promo_label));
  r = await get('/kos/featured');
  check('GET /kos/featured -> rating >= 4.6', r.ok && r.data.length === 7 && r.data.every((k) => k.rating_avg >= 4.6));
  r = await get('/kos/promo');
  check('GET /kos/promo', r.ok && r.data.length === 6);

  r = await get('/kos', { query: { q: 'unesa' } });
  check('q=unesa -> kos dekat UNESA (8,15,16,18)', r.ok && JSON.stringify(r.data.map((k) => k.id).sort((a, b) => a - b)) === '[8,15,16,18]', JSON.stringify(r.data?.map((k) => k.id)));
  r = await get('/kos', { query: { q: 'kos dekat Universitas Negeri Surabaya' } });
  check('q="kos dekat Universitas Negeri Surabaya" (stop words diabaikan)', r.ok && r.data.some((k) => k.id === 15));
  r = await get('/kos', { query: { q: 'melati' } });
  check('q=melati -> Kos Melati Asri', r.data.length === 1 && r.data[0].id === 1);
  r = await get('/kos', { query: { landmark_id: 9, radius_km: 3 } });
  check('landmark_id=9 (ITS) radius 3km -> kos 17', r.ok && r.data.length === 1 && r.data[0].id === 17);
  r = await get('/kos', { query: { q: 'tidakadakos' } });
  check('q tak cocok -> daftar kosong', r.ok && r.data.length === 0);
  r = await get('/kos', { query: { q: "x' OR 1=1 --" } });
  check('q berisi karakter SQL aman', r.ok);

  section('Detail kos');
  r = await get('/kos/8');
  check('GET /kos/8', r.ok && r.data.name === 'Kos Cempaka Residence');
  check('  alamat, koordinat, deskripsi', r.data.address.includes('Wonokromo') && typeof r.data.latitude === 'number' && r.data.description.length > 20);
  check('  fasilitas lengkap (nama, kategori, ikon)', r.data.facilities.length >= 9 && r.data.facilities[0].category && r.data.facilities.some((f) => f.name === 'AC' && f.icon === 'ac_unit'));
  check('  rules (3), rating_breakdown (6 aspek), owner.name', r.data.rules.length === 3 && Object.keys(r.data.rating_breakdown).length === 6 && r.data.owner.name === 'Bu Sari');
  check('  rooms: tipe Standar dengan harga bulanan', r.data.rooms.length === 1 && r.data.rooms[0].price_monthly === 1600000);
  const k6 = (await get('/kos/6')).data;
  check('  kos 6: 2 tipe kamar (Standar + Deluxe)', k6.rooms.length === 2 && k6.rooms[1].name.includes('Deluxe'));
  r = await get('/kos/9999');
  check('GET /kos/9999 -> 404', r.status === 404 && r.ok === false);
  r = await get('/kos/abc');
  check('GET /kos/abc -> 400', r.status === 400);
  r = await get('/kos/1/reviews', { query: { limit: 3 } });
  check('GET /kos/1/reviews?limit=3', r.ok && r.data.length === 3 && r.data[0].user_name && r.data[0].rating_overall > 0 && typeof r.data[0].ratings.cleanliness === 'number');

  section('Autentikasi');
  const email = `uji${stamp}@example.com`;
  const username = `penguji_${stamp}`;
  r = await get('/auth/check-username', { query: { username } });
  check('GET /auth/check-username (belum dipakai) -> available', r.ok && r.data.available === true);
  r = await get('/auth/check-username', { query: { username: 'raka' } });
  check('  username "raka" sudah dipakai -> tidak available', r.ok && r.data.available === false);
  r = await get('/auth/check-username', { query: { username: 'admin' } });
  check('  username "admin" (dicadangkan) -> tidak available', r.data.available === false);
  r = await post('/auth/register', { name: 'Penguji Satu', username, email, password: 'rahasia123', phone: '0812-3456-7890' });
  check('POST /auth/register -> 201 + token + username', r.status === 201 && r.data.token && r.data.user.role === 'pencari' && r.data.user.username === username, r.message);
  let token = r.data.token;
  const me = r.data.user;
  r = await post('/auth/register', { name: 'Penguji Satu', username: `lain_${stamp}`, email, password: 'rahasia123' });
  check('  email dobel -> 409', r.status === 409 && r.message.includes('Email'));
  r = await post('/auth/register', { name: 'Penguji Satu', username: username.toUpperCase(), email: `lain${stamp}@example.com`, password: 'rahasia123' });
  check('  username dobel (beda huruf besar/kecil) -> 409', r.status === 409 && r.message.includes('Username'), r.message);
  for (const bad of ['ab', 'a b c', 'user!name', '.titik', 'dua__garis', 'admin', '']) {
    r = await post('/auth/register', { name: 'Penguji', username: bad, email: `x${stamp}@example.com`, password: 'rahasia123' });
    check(`  username "${bad}" ditolak -> 422`, r.status === 422, `status ${r.status}`);
  }
  r = await post('/auth/register', { name: 'Penguji', username: `ok_${stamp}`, email: `y${stamp}@example.com`, password: 'rahasia123' });
  check('  username diawali @ dan huruf besar dinormalkan', (await post('/auth/register', { name: 'Penguji', username: `@Kecil_${stamp}`, email: `z${stamp}@example.com`, password: 'rahasia123' })).data?.user?.username === `kecil_${stamp}`);
  r = await post('/auth/register', { name: 'A', username: 'valid_name', email: 'bukan-email', password: '123' });
  check('  data tidak valid -> 422', r.status === 422);
  r = await get('/auth/check-username', { query: { username } });
  check('  check-username setelah daftar -> tidak available', r.data.available === false);
  r = await post('/auth/login', { email, password: 'salah-total' });
  check('POST /auth/login sandi salah -> 401', r.status === 401 && r.message.includes('salah'));
  r = await post('/auth/login', { email, password: 'rahasia123' });
  check('POST /auth/login pakai email -> token', r.ok && r.data.token && r.data.user.email === email);
  token = r.data.token;
  r = await post('/auth/login', { login: username.toUpperCase(), password: 'rahasia123' });
  check('POST /auth/login pakai username (login) -> token', r.ok && r.data.user.id === me.id, r.message);
  r = await post('/auth/login', { email: `@${username}`, password: 'rahasia123' });
  check('  field "email" berisi @username tetap jalan (kompatibel aplikasi)', r.ok && r.data.user.id === me.id);
  r = await post('/auth/login', { login: 'raka', password: 'password123' });
  check('  akun demo login via username "raka"', r.ok && r.data.user.username === 'raka');
  r = await get('/auth/me', { token });
  check('GET /auth/me (ada username)', r.ok && r.data.id === me.id && r.data.username === username);
  r = await get('/auth/me');
  check('tanpa token -> 401', r.status === 401);
  r = await get('/auth/me', { token: 'token.palsu.sekali' });
  check('token palsu -> 401', r.status === 401);
  r = await call('PUT', '/auth/profile', { token, json: { name: 'Penguji Dua', phone: '081299998888' } });
  check('PUT /auth/profile', r.ok && r.data.name === 'Penguji Dua' && r.data.phone === '081299998888');
  r = await call('PUT', '/auth/password', { token, json: { old_password: 'salah', new_password: 'barubaru123' } });
  check('PUT /auth/password sandi lama salah -> 400', r.status === 400);
  r = await call('PUT', '/auth/password', { token, json: { old_password: 'rahasia123', new_password: 'barubaru123' } });
  check('PUT /auth/password', r.ok);
  r = await post('/auth/login', { email, password: 'barubaru123' });
  check('  login dengan sandi baru', r.ok);
  token = r.data.token;

  section('Koin & voucher');
  r = await get('/coins', { token });
  check('GET /coins -> saldo 500 (bonus akun baru)', r.ok && r.data.balance === 500 && r.data.history[0].title === 'Bonus akun baru');
  r = await get('/vouchers', { token });
  check('GET /vouchers -> kosong untuk akun baru', r.ok && r.data.length === 0);
  r = await post('/vouchers/claim', { code: 'hemat50' }, { token });
  check('POST /vouchers/claim HEMAT50 -> 201', r.status === 201 && r.data.code === 'HEMAT50' && r.data.discount === 50000);
  r = await post('/vouchers/claim', { code: 'HEMAT50' }, { token });
  check('  klaim dua kali -> 409', r.status === 409);
  r = await post('/vouchers/claim', { code: 'NGAWUR' }, { token });
  check('  kode ngawur -> 400', r.status === 400);
  r = await get('/vouchers', { token });
  check('GET /vouchers -> 1 voucher', r.ok && r.data.length === 1);

  section('Favorit & terakhir dilihat');
  r = await post('/favorites/3', {}, { token });
  check('POST /favorites/3 -> 201', r.status === 201);
  r = await post('/favorites/4', {}, { token });
  r = await get('/favorites', { token });
  check('GET /favorites -> 2 kos, is_favorite true', r.ok && r.data.length === 2 && r.data.every((k) => k.is_favorite));
  check('  urutan: lama dulu (3 lalu 4)', r.data[0].id === 3 && r.data[1].id === 4);
  r = await get('/kos/3', { token });
  check('GET /kos/3 (login) -> is_favorite true', r.ok && r.data.is_favorite === true);
  r = await call('DELETE', '/favorites/3', { token });
  check('DELETE /favorites/3', r.ok);
  r = await get('/favorites', { token });
  check('  sisa 1 favorit', r.data.length === 1 && r.data[0].id === 4);
  await get('/kos/11', { token });
  r = await get('/recently-viewed', { token });
  check('GET /recently-viewed -> terbaru dulu (11, lalu 3)', r.ok && r.data[0].id === 11 && r.data[1].id === 3);
  r = await post('/favorites/9999', {}, { token });
  check('favorit kos tak ada -> 404', r.status === 404);

  section('Ulasan');
  r = await get('/kos/7/reviews/me', { token });
  check('GET /kos/7/reviews/me belum ada -> 404', r.status === 404);
  const before = (await get('/kos/7')).data;
  r = await post('/kos/7/reviews', { ratings: { cleanliness: 5, comfort: 4, safety: 5, price: 3, room_facility: 4 }, comment: 'x' }, { token });
  check('POST ulasan kurang aspek -> 422', r.status === 422);
  const ratings = { cleanliness: 5, comfort: 4, safety: 5, price: 3, room_facility: 4, public_facility: 4 };
  r = await post('/kos/7/reviews', { ratings, comment: 'Nyaman dan bersih.' }, { token });
  check('POST /kos/7/reviews -> 201, rating_overall = rata-rata (4.2)', r.status === 201 && r.data.rating_overall === 4.2 && r.data.user_name === 'Penguji D.');
  let after = (await get('/kos/7')).data;
  check('  rating_count kos bertambah 1', after.rating_count === before.rating_count + 1);
  check('  rating_avg ikut berubah', after.rating_avg !== before.rating_avg);
  r = await post('/kos/7/reviews', { ratings: { ...ratings, price: 5 }, comment: 'Revisi.' }, { token });
  check('POST ulasan lagi -> 200 (memperbarui, bukan duplikat)', r.status === 200 && r.data.comment === 'Revisi.');
  after = (await get('/kos/7')).data;
  check('  rating_count tetap', after.rating_count === before.rating_count + 1);
  r = await get('/kos/7/reviews/me', { token });
  check('GET /kos/7/reviews/me', r.ok && r.data.ratings.price === 5);
  r = await get('/coins', { token });
  check('  koin +50 hanya sekali (550)', r.data.balance === 550);

  section('Kode promo');
  r = await post('/promos/validate', { code: 'NGEKOSBARU', kos_id: 7, amount: 400000 }, { token });
  check('promo di bawah minimal -> 400 + pesan', r.status === 400 && r.message.includes('Minimal sewa'), r.message);
  r = await post('/promos/validate', { code: 'NGEKOSBARU', kos_id: 7, amount: 1250000 }, { token });
  check('POST /promos/validate NGEKOSBARU -> diskon 100000', r.ok && r.data.discount === 100000);
  r = await post('/promos/validate', { code: 'LIBURAN15', kos_id: 7, amount: 1250000 }, { token });
  check('voucher privat yang belum diklaim -> 400', r.status === 400 && r.message.includes('Klaim'));
  r = await post('/promos/validate', { code: 'NGAWUR', kos_id: 7, amount: 1250000 }, { token });
  check('kode tidak ada -> 400', r.status === 400);

  section('Booking (ajukan sewa)');
  const detail = (await get('/kos/7')).data;
  const room = detail.rooms[0];
  const draft = {
    kos_id: 7, room_type_id: room.id, checkin_date: tomorrow(), duration_unit: 'bulanan',
    duration_count: 3, occupants: 1, tenant_name: 'Penguji Dua', tenant_phone: '081299998888',
  };
  r = await post('/bookings', { ...draft, checkin_date: '2020-01-01' }, { token });
  check('tanggal masuk masa lalu -> 422', r.status === 422);
  r = await post('/bookings', { ...draft, duration_unit: 'harian' }, { token });
  check('periode tidak tersedia (harian) -> 400', r.status === 400 && r.message.includes('harian'), r.message);
  r = await post('/bookings', { ...draft, duration_count: 99 }, { token });
  check('durasi melebihi batas -> 422', r.status === 422);
  r = await post('/bookings', draft);
  check('tanpa login -> 401', r.status === 401);

  const stockBefore = (await get('/kos/7')).data.rooms[0].stock;
  r = await post('/bookings', { ...draft, promo_code: 'NGEKOSBARU', note: 'Lantai bawah ya' }, { token });
  check('POST /bookings -> 201 status menunggu_konfirmasi', r.status === 201 && r.data.status === 'menunggu_konfirmasi', r.message);
  const b1 = r.data;
  const sub = room.price_monthly * 3;
  check('  harga dihitung server: subtotal + deposit + admin 5000 - diskon',
    b1.price_per_unit === room.price_monthly && b1.deposit === room.deposit && b1.admin_fee === 5000 &&
    b1.discount === 100000 && b1.total_amount === sub + room.deposit + 5000 - 100000, JSON.stringify(b1));
  check('  kode NGK-YYYYMMDD-000N & expires_at ada', /^NGK-\d{8}-\d{4}$/.test(b1.code) && !!b1.expires_at);
  const co = new Date(b1.checkout_date + 'T00:00:00Z');
  const ci = new Date(b1.checkin_date + 'T00:00:00Z');
  check('  checkout = checkin + 3 bulan', (co.getUTCFullYear() * 12 + co.getUTCMonth()) - (ci.getUTCFullYear() * 12 + ci.getUTCMonth()) === 3);
  check('  info kos tertanam (name, location, kos_type)', b1.kos.name === 'Kos Mawar Putri' && b1.kos.location === 'Gubeng, Surabaya');
  check('  stok kamar berkurang 1', (await get('/kos/7')).data.rooms[0].stock === stockBefore - 1);
  r = await post('/promos/validate', { code: 'NGEKOSBARU', kos_id: 7, amount: 1250000 }, { token });
  check('  voucher yang sudah dipakai -> ditolak', r.status === 400 && r.message.includes('sudah kamu pakai'));

  r = await get('/bookings', { token });
  check('GET /bookings -> 1 pengajuan', r.ok && r.data.length === 1 && r.data[0].id === b1.id);
  r = await get(`/bookings/${b1.id}`, { token });
  check('GET /bookings/:id', r.ok && r.data.code === b1.code);

  r = await post(`/bookings/${b1.id}/cancel`, {}, { token });
  check('POST /bookings/:id/cancel -> dibatalkan', r.ok && r.data.status === 'dibatalkan');
  check('  stok kamar kembali', (await get('/kos/7')).data.rooms[0].stock === stockBefore);
  r = await post('/promos/validate', { code: 'NGEKOSBARU', kos_id: 7, amount: 1250000 }, { token });
  check('  voucher pulih setelah dibatalkan', r.ok && r.data.discount === 100000);
  r = await post(`/bookings/${b1.id}/cancel`, {}, { token });
  check('  batalkan dua kali -> 409', r.status === 409);

  section('Pembayaran');
  r = await post('/bookings', draft, { token });
  const b2 = r.data;
  r = await call('POST', `/bookings/${b2.id}/pay`, { token, form: (() => { const f = new FormData(); f.append('method', 'bca'); return f; })() });
  check('transfer bank tanpa bukti -> 422', r.status === 422);
  r = await call('POST', `/bookings/${b2.id}/pay`, { token, form: (() => { const f = new FormData(); f.append('method', 'bitcoin'); return f; })() });
  check('metode tidak dikenal -> 422', r.status === 422);
  r = await call('POST', `/bookings/${b2.id}/pay`, { token, form: (() => { const f = new FormData(); f.append('method', 'bca'); f.append('proof', new Blob(['ini bukan gambar sama sekali'], { type: 'image/png' }), 'x.png'); return f; })() });
  check('bukti bukan gambar sungguhan -> 400', r.status === 400);
  r = await call('POST', `/bookings/${b2.id}/pay`, { token, form: imageForm('proof', { method: 'bca' }) });
  check('POST /bookings/:id/pay (BCA + bukti) -> dibayar', r.ok && r.data.status === 'dibayar' && r.data.payment.method === 'bca' && r.data.payment.has_proof === true, r.message);
  r = await call('POST', `/bookings/${b2.id}/pay`, { token, form: imageForm('proof', { method: 'bca' }) });
  check('  bayar dua kali -> 409', r.status === 409);
  const proofRes = await fetch(`${BASE}/bookings/${b2.id}/proof`, { headers: { Authorization: `Bearer ${token}` } });
  check('GET /bookings/:id/proof (penyewa) -> gambar', proofRes.status === 200 && proofRes.headers.get('content-type').startsWith('image/'));
  const proofAnon = await fetch(`${BASE}/bookings/${b2.id}/proof`);
  check('  tanpa login -> 401', proofAnon.status === 401);

  r = await post('/bookings', { ...draft, checkin_date: tomorrow() }, { token });
  const b3 = r.data;
  r = await call('POST', `/bookings/${b3.id}/pay`, { token, form: (() => { const f = new FormData(); f.append('method', 'gopay'); return f; })() });
  check('bayar GoPay tanpa bukti -> dibayar', r.ok && r.data.status === 'dibayar' && r.data.payment.status === 'berhasil');

  section('Alur pemilik kos (Bu Sari)');
  r = await post('/auth/login', { email: 'sari@ngekos.in', password: 'password123' });
  const owner = r.data.token;
  check('login pemilik', r.ok && r.data.user.role === 'pemilik');
  r = await get('/owner/kos', { token: owner });
  check('GET /owner/kos -> 18 kos', r.ok && r.data.length === 18);
  r = await get('/owner/bookings', { token: owner, query: { status: 'dibayar' } });
  check('GET /owner/bookings?status=dibayar -> berisi pengajuan penguji', r.ok && r.data.some((b) => b.id === b2.id) && r.data.some((b) => b.id === b3.id));
  r = await get('/owner/bookings', { token });
  check('pencari mengakses /owner/bookings -> 403', r.status === 403);
  r = await post(`/owner/bookings/${b2.id}/confirm`, {}, { token: owner });
  check('confirm pengajuan yang sudah dibayar -> 409', r.status === 409);
  r = await post(`/owner/bookings/${b2.id}/activate`, {}, { token: owner });
  check('POST /owner/bookings/:id/activate -> aktif', r.ok && r.data.status === 'aktif');
  r = await get('/bookings', { token, query: { status: 'aktif' } });
  check('  pencari melihat sewa aktif', r.ok && r.data.length === 1);
  const coinsBefore = (await get('/coins', { token })).data.balance;
  r = await post(`/owner/bookings/${b2.id}/complete`, {}, { token: owner });
  check('POST /owner/bookings/:id/complete -> selesai', r.ok && r.data.status === 'selesai');
  const coinsAfter = (await get('/coins', { token })).data;
  check('  koin bertambah saat sewa selesai', coinsAfter.balance > coinsBefore && coinsAfter.history[0].title === 'Menyelesaikan masa sewa');

  r = await post('/bookings', draft, { token });
  const b4 = r.data;
  r = await post(`/owner/bookings/${b4.id}/confirm`, {}, { token: owner });
  check('POST /owner/bookings/:id/confirm -> menunggu_pembayaran', r.ok && r.data.status === 'menunggu_pembayaran');
  const stock4 = (await get('/kos/7')).data.rooms[0].stock;
  r = await post(`/owner/bookings/${b4.id}/reject`, {}, { token: owner });
  check('POST /owner/bookings/:id/reject -> ditolak, stok kembali', r.ok && r.data.status === 'ditolak' && (await get('/kos/7')).data.rooms[0].stock === stock4 + 1);

  r = await get('/kos/7/reviews', { token });
  const myReviewId = r.data[0].id;
  r = await post(`/owner/reviews/${myReviewId}/reply`, { reply: 'Terima kasih, Kak!' }, { token: owner });
  check('POST /owner/reviews/:id/reply', r.ok);
  r = await get('/kos/7/reviews', { token });
  check('  balasan tampil di ulasan', r.data.some((x) => x.owner_reply === 'Terima kasih, Kak!'));

  section('Chat');
  r = await post('/chat/rooms', { kos_id: 7 }, { token });
  check('POST /chat/rooms -> 201 room baru', r.status === 201 && r.data.kos.id === 7 && r.data.other_name === 'Bu Sari', JSON.stringify(r.data));
  const roomId = r.data.id;
  r = await post('/chat/rooms', { kos_id: 7 }, { token });
  check('  kos sama lagi -> 200, room yang sama', r.status === 200 && r.data.id === roomId);
  r = await post('/chat/rooms', { kos_id: 7 }, { token: owner });
  check('  pemilik chat ke kos sendiri -> 403', r.status === 403);
  r = await call('POST', `/chat/rooms/${roomId}/messages`, { token, form: (() => { const f = new FormData(); f.append('body', 'Halo Bu, kamar masih kosong?'); return f; })() });
  check('POST /chat/rooms/:id/messages (multipart teks) -> 201', r.status === 201 && r.data.body.startsWith('Halo') && r.data.sender_id === me.id);
  const msg1 = r.data.id;
  r = await call('POST', `/chat/rooms/${roomId}/messages`, { token, form: imageForm('image') });
  check('  kirim gambar (octet-stream) -> image_url', r.status === 201 && /^uploads\/chat\/.+\.png$/.test(r.data.image_url), JSON.stringify(r.data));
  const imgPath = r.data.image_url;
  const imgRes = await fetch(BASE.replace('/api/v1', '') + '/' + imgPath);
  check('  gambar chat bisa dibuka publik', imgRes.status === 200 && imgRes.headers.get('content-type') === 'image/png');
  r = await call('POST', `/chat/rooms/${roomId}/messages`, { token, form: (() => { const f = new FormData(); f.append('image', new Blob(['bukan gambar bukan gambar'], { type: 'image/jpeg' }), 'a.jpg'); return f; })() });
  check('  file palsu (bukan gambar) -> 400', r.status === 400);
  r = await post(`/chat/rooms/${roomId}/messages`, { body: '   ' }, { token });
  check('  pesan kosong -> 422', r.status === 422);

  r = await get('/chat/rooms', { token: owner });
  const ownerRoom = r.data.find((x) => x.id === roomId);
  check('pemilik melihat room + unread 2 + nama lawan = pencari', ownerRoom && ownerRoom.unread_count === 2 && ownerRoom.other_name === 'Penguji Dua', JSON.stringify(ownerRoom));
  r = await get(`/chat/rooms/${roomId}/messages`, { token: owner });
  check('GET messages (pemilik) -> 2 pesan', r.ok && r.data.length === 2);
  r = await get('/chat/rooms', { token: owner });
  check('  unread pemilik direset 0', r.data.find((x) => x.id === roomId).unread_count === 0);
  r = await post(`/chat/rooms/${roomId}/messages`, { body: 'Masih ada, silakan survei 🙂' }, { token: owner });
  check('pemilik membalas (JSON) -> 201', r.status === 201);
  r = await get(`/chat/rooms/${roomId}/messages`, { token, query: { after_id: msg1 } });
  check('polling after_id -> hanya pesan setelah id tsb (gambar + balasan)', r.ok && r.data.length === 2 && r.data[1].body.includes('survei'), JSON.stringify(r.data));
  r = await get('/chat/rooms', { token });
  const myRoom = r.data.find((x) => x.id === roomId);
  check('daftar room pencari: last_message = balasan, unread direset', myRoom.last_message.includes('survei') && myRoom.unread_count === 0, JSON.stringify(myRoom));
  r = await get('/chat/rooms/1/messages', { token });
  check('room milik orang lain -> 404', r.status === 404);

  section('Pengajuan jadi pemilik & admin');
  r = await post('/owner/apply', {}, { token });
  check('POST /owner/apply -> pending', r.status === 201 && r.data.owner_status === 'pending');
  r = await post('/owner/apply', {}, { token });
  check('  ajukan lagi -> 409', r.status === 409);
  r = await get('/owner/status', { token });
  check('GET /owner/status', r.ok && r.data.owner_status === 'pending');
  r = await get('/admin/owner-applications', { token });
  check('pencari mengakses admin -> 403', r.status === 403);
  r = await post('/auth/login', { email: 'admin@ngekos.in', password: 'admin123' });
  const admin = r.data.token;
  r = await get('/admin/owner-applications', { token: admin });
  check('GET /admin/owner-applications', r.ok && r.data.some((u) => u.id === me.id));
  r = await post(`/admin/owner-applications/${me.id}/approve`, {}, { token: admin });
  check('POST /admin/owner-applications/:id/approve', r.ok && r.data.owner_status === 'approved');
  r = await get('/auth/me', { token });
  check('  role berubah jadi pemilik', r.data.role === 'pemilik');

  section('Lain-lain');
  r = await get('/endpoint-yang-tidak-ada');
  check('endpoint tak dikenal -> 404 JSON', r.status === 404 && r.ok === false);
  const bad = await fetch(`${BASE}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{rusak' });
  check('JSON rusak -> 400', bad.status === 400);

  console.log(`\n${failed ? '\x1b[31m' : '\x1b[32m'}${passed} lulus, ${failed} gagal\x1b[0m`);
  if (failed) {
    console.log('Gagal:\n - ' + failures.join('\n - '));
    process.exit(1);
  }
}

main().catch((e) => {
  console.error('\nTest berhenti karena error:', e.message);
  console.error('Pastikan server sudah jalan (npm start) di', BASE);
  process.exit(1);
});
