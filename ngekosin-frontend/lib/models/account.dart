/// Satu baris riwayat koin. [amount] positif = masuk, negatif = dipakai.
class CoinTx {
  final String title;
  final int amount;
  final DateTime date;
  const CoinTx({required this.title, required this.amount, required this.date});

  factory CoinTx.fromJson(Map<String, dynamic> j) => CoinTx(
        title: (j['title'] ?? '').toString(),
        amount: int.tryParse('${j['amount']}') ?? 0,
        date: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      );
}

/// Voucher / kode promo milik user. Kodenya dipakai di kolom promo saat Ajukan Sewa.
class Voucher {
  final String code;
  final String title;
  final String description;
  final int discount; // potongan dalam rupiah
  final int minAmount; // minimal total sewa
  final DateTime expiresAt;

  const Voucher({
    required this.code,
    required this.title,
    required this.description,
    required this.discount,
    required this.minAmount,
    required this.expiresAt,
  });

  bool get expired => expiresAt.isBefore(DateTime.now());

  factory Voucher.fromJson(Map<String, dynamic> j) => Voucher(
        code: (j['code'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        discount: int.tryParse('${j['discount']}') ?? 0,
        minAmount: int.tryParse('${j['min_amount']}') ?? 0,
        expiresAt: DateTime.tryParse('${j['expires_at']}') ??
            DateTime.now().add(const Duration(days: 30)),
      );
}

/// Status pengajuan jadi pemilik kos.
enum OwnerStatus { none, pending }
