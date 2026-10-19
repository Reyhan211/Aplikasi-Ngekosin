import 'dart:math' as math;
import 'kos.dart';
import 'kos_detail.dart';

/// Satuan periode sewa. [apiValue] dikirim ke backend (kolom `duration_unit`).
enum DurationUnit {
  harian('harian', 'Harian', 'hari', 30),
  mingguan('mingguan', 'Mingguan', 'minggu', 8),
  bulanan('bulanan', 'Bulanan', 'bulan', 12),
  tahunan('tahunan', 'Tahunan', 'tahun', 3);

  const DurationUnit(this.apiValue, this.label, this.noun, this.maxCount);
  final String apiValue;
  final String label;
  final String noun;
  final int maxCount;

  static DurationUnit fromApi(String v) =>
      values.firstWhere((u) => u.apiValue == v, orElse: () => DurationUnit.bulanan);

  /// Harga per satuan untuk tipe kamar ini; null = periode tidak tersedia.
  int? priceOf(RoomType r) => switch (this) {
        DurationUnit.harian => r.priceDaily,
        DurationUnit.mingguan => r.priceWeekly,
        DurationUnit.bulanan => r.priceMonthly,
        DurationUnit.tahunan => r.priceYearly,
      };

  DateTime endDate(DateTime start, int count) => switch (this) {
        DurationUnit.harian => DateTime(start.year, start.month, start.day + count),
        DurationUnit.mingguan => DateTime(start.year, start.month, start.day + 7 * count),
        DurationUnit.bulanan => _addMonths(start, count),
        DurationUnit.tahunan => _addMonths(start, 12 * count),
      };
}

/// Tambah bulan tanpa "meluber" (31 Jan + 1 bulan = 28/29 Feb, bukan 3 Mar).
DateTime _addMonths(DateTime d, int n) {
  final m = d.month - 1 + n;
  final y = d.year + m ~/ 12;
  final mo = m % 12 + 1;
  final lastDay = DateTime(y, mo + 1, 0).day;
  return DateTime(y, mo, math.min(d.day, lastDay));
}

/// Rincian biaya. Ini hanya ESTIMASI di aplikasi; server menghitung ulang
/// semuanya saat POST /bookings (lihat docs/API.md).
class BookingPricing {
  static const int adminFee = 5000;

  final int pricePerUnit;
  final int count;
  final int deposit;
  final int discount;

  const BookingPricing({
    required this.pricePerUnit,
    required this.count,
    required this.deposit,
    this.discount = 0,
  });

  int get subtotal => pricePerUnit * count;
  int get total => math.max(0, subtotal + deposit + adminFee - discount);
}

/// Data yang dikirim saat "Ajukan Sewa".
class BookingDraft {
  final Kos kos;
  final RoomType room;
  final DateTime checkin;
  final DurationUnit unit;
  final int count;
  final int occupants;
  final String tenantName;
  final String tenantPhone;
  final String? note;
  final String? promoCode;
  final int discount;

  const BookingDraft({
    required this.kos,
    required this.room,
    required this.checkin,
    required this.unit,
    required this.count,
    required this.occupants,
    required this.tenantName,
    required this.tenantPhone,
    this.note,
    this.promoCode,
    this.discount = 0,
  });
}

/// Kelompok tab di halaman Kos Saya.
enum BookingGroup { ditempati, pengajuan, riwayat }

class Booking {
  final int id;
  final String code;
  final int kosId;
  final String kosName;
  final String kosType;
  final String kosLocation;
  final String? coverUrl;
  final String roomName;
  final DateTime checkin;
  final DateTime checkout;
  final DurationUnit unit;
  final int durationCount;
  final int pricePerUnit;
  final int deposit;
  final int adminFee;
  final int discount;
  final int total;
  final int occupants;
  final String tenantName;
  final String tenantPhone;
  final String? note;

  /// menunggu_konfirmasi | menunggu_pembayaran | dibayar | aktif |
  /// selesai | ditolak | dibatalkan | kadaluarsa
  final String status;
  final DateTime createdAt;
  final DateTime? expiresAt;

  /// Info pembayaran terakhir (null bila belum bayar).
  /// [payStatus]: menunggu_verifikasi | berhasil | ditolak
  final String? payMethod;
  final String? payStatus;
  final bool hasProof;

  const Booking({
    required this.id,
    required this.code,
    required this.kosId,
    required this.kosName,
    required this.kosType,
    required this.kosLocation,
    this.coverUrl,
    required this.roomName,
    required this.checkin,
    required this.checkout,
    required this.unit,
    required this.durationCount,
    required this.pricePerUnit,
    required this.deposit,
    required this.adminFee,
    required this.discount,
    required this.total,
    required this.occupants,
    required this.tenantName,
    required this.tenantPhone,
    this.note,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.payMethod,
    this.payStatus,
    this.hasProof = false,
  });

  BookingGroup get group => switch (status) {
        'aktif' => BookingGroup.ditempati,
        'menunggu_konfirmasi' || 'menunggu_pembayaran' || 'dibayar' => BookingGroup.pengajuan,
        _ => BookingGroup.riwayat,
      };

  bool get canCancel => status == 'menunggu_konfirmasi' || status == 'menunggu_pembayaran';

  /// Tombol Bayar tampil selama pengajuan belum dibayar.
  bool get canPay => status == 'menunggu_konfirmasi' || status == 'menunggu_pembayaran';

  Booking withStatus(String s) => Booking(
        id: id, code: code, kosId: kosId, kosName: kosName, kosType: kosType,
        kosLocation: kosLocation, coverUrl: coverUrl, roomName: roomName,
        checkin: checkin, checkout: checkout, unit: unit, durationCount: durationCount,
        pricePerUnit: pricePerUnit, deposit: deposit, adminFee: adminFee,
        discount: discount, total: total, occupants: occupants,
        tenantName: tenantName, tenantPhone: tenantPhone, note: note,
        status: s, createdAt: createdAt, expiresAt: expiresAt,
        payMethod: payMethod, payStatus: payStatus, hasProof: hasProof,
      );

  /// Bentuk JSON: lihat "Booking" di docs/API.md.
  factory Booking.fromJson(Map<String, dynamic> j) {
    final kos = (j['kos'] as Map?) ?? const {};
    int n(String k) => int.tryParse('${j[k]}') ?? 0;
    final note = j['note']?.toString();
    final pay = (j['payment'] as Map?) ?? const {};
    return Booking(
      id: int.parse(j['id'].toString()),
      code: (j['code'] ?? '').toString(),
      kosId: int.tryParse('${kos['id']}') ?? 0,
      kosName: (kos['name'] ?? '').toString(),
      kosType: (kos['kos_type'] ?? 'campur').toString(),
      kosLocation: (kos['location'] ?? '').toString(),
      coverUrl: kos['cover_url']?.toString(),
      roomName: (j['room_type_name'] ?? '').toString(),
      checkin: DateTime.tryParse('${j['checkin_date']}') ?? DateTime.now(),
      checkout: DateTime.tryParse('${j['checkout_date']}') ?? DateTime.now(),
      unit: DurationUnit.fromApi('${j['duration_unit']}'),
      durationCount: n('duration_count'),
      pricePerUnit: n('price_per_unit'),
      deposit: n('deposit'),
      adminFee: n('admin_fee'),
      discount: n('discount'),
      total: n('total_amount'),
      occupants: n('occupants'),
      tenantName: (j['tenant_name'] ?? '').toString(),
      tenantPhone: (j['tenant_phone'] ?? '').toString(),
      note: (note == null || note.isEmpty) ? null : note,
      status: (j['status'] ?? 'menunggu_konfirmasi').toString(),
      createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      expiresAt: DateTime.tryParse('${j['expires_at']}'),
      payMethod: pay['method']?.toString(),
      payStatus: pay['status']?.toString(),
      hasProof: pay['has_proof'] == true,
    );
  }
}
