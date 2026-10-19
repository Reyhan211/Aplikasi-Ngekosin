import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/booking_store.dart';
import '../../models/booking.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/kos_card.dart';
import '../kos/sections.dart';

enum _MethodKind { bank, ewallet, qris }

class _PayMethod {
  final String code;
  final String name;
  final _MethodKind kind;
  final IconData icon;
  const _PayMethod(this.code, this.name, this.kind, this.icon);

  /// Transfer bank dibayar manual -> wajib unggah bukti.
  bool get needsProof => kind == _MethodKind.bank;
}

const _methods = [
  _PayMethod('bca', 'BCA Virtual Account', _MethodKind.bank, Icons.account_balance_rounded),
  _PayMethod('mandiri', 'Mandiri Virtual Account', _MethodKind.bank, Icons.account_balance_rounded),
  _PayMethod('bni', 'BNI Virtual Account', _MethodKind.bank, Icons.account_balance_rounded),
  _PayMethod('gopay', 'GoPay', _MethodKind.ewallet, Icons.account_balance_wallet_rounded),
  _PayMethod('dana', 'DANA', _MethodKind.ewallet, Icons.account_balance_wallet_rounded),
  _PayMethod('qris', 'QRIS', _MethodKind.qris, Icons.qr_code_2_rounded),
];

/// Halaman pembayaran sewa: ringkasan, rincian biaya, pilih metode,
/// instruksi, (unggah bukti bayar), lalu [BookingStore.pay].
/// Rute: /payment/:id (wajib login, dijaga di app_router.dart).
class PaymentPage extends StatefulWidget {
  final int bookingId;
  const PaymentPage({super.key, required this.bookingId});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

  _PayMethod _method = _methods.first;
  XFile? _proof;
  bool _paying = false;

  Future<void> _pickProof() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (img != null) setState(() => _proof = img);
  }

  /// Nomor VA tiruan (mock): prefix bank + id booking + kode tanggal.
  String _vaNumber(Booking b) {
    final prefix = switch (_method.code) {
      'bca' => '39358',
      'mandiri' => '70012',
      _ => '8808',
    };
    final day = b.createdAt.day.toString().padLeft(2, '0');
    final month = b.createdAt.month.toString().padLeft(2, '0');
    return '$prefix${b.id.toString().padLeft(4, '0')}$day${month}01';
  }

  Future<void> _pay(Booking b) async {
    if (_method.needsProof && _proof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unggah bukti transfer dulu ya')),
      );
      return;
    }
    setState(() => _paying = true);
    try {
      await BookingStore.instance
          .pay(b, method: _method.code, proof: _method.needsProof ? _proof : null);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
          title: const Text('Pembayaran berhasil'),
          content: Text(
            'Pembayaran ${rupiah(b.total)} untuk ${b.kosName} '
            '(${b.code}) sudah kami terima.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Lihat di Kos Saya'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/kos-saya?tab=pengajuan&t=${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BookingStore.instance,
      builder: (context, _) {
        final b = BookingStore.instance.byId(widget.bookingId);
        if (b == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pembayaran')),
            body: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Pengajuan tidak ditemukan',
              message: 'Buka lagi dari halaman Kos Saya.',
              actionLabel: 'Ke Kos Saya',
              onAction: () => context.go('/kos-saya'),
            ),
          );
        }
        if (!b.canPay && !_paying) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pembayaran')),
            body: EmptyState(
              icon: Icons.verified_rounded,
              title: 'Tidak ada tagihan',
              message: 'Pengajuan ${b.code} tidak memerlukan pembayaran saat ini.',
              actionLabel: 'Ke Kos Saya',
              onAction: () => context.go('/kos-saya'),
            ),
          );
        }
        return _buildForm(context, b);
      },
    );
  }

  Widget _buildForm(BuildContext context, Booking b) {
    final theme = Theme.of(context);
    final needsProof = _method.needsProof;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total bayar',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text(rupiah(b.total), style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FilledButton(
                  onPressed: _paying ? null : () => _pay(b),
                  style: AppTheme.ctaStyle,
                  child: _paying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.ink),
                        )
                      : Text(needsProof ? 'Kirim bukti bayar' : 'Bayar sekarang'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          // ringkasan sewa
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TypeBadge(b.kosType),
                      const Spacer(),
                      Text(b.code,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(b.kosName, style: theme.textTheme.titleMedium),
                  Text(b.kosLocation,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                  const Divider(height: 22),
                  _Line('Tipe kamar', b.roomName),
                  _Line('Masuk', _dateFmt.format(b.checkin)),
                  _Line('Keluar', _dateFmt.format(b.checkout)),
                  _Line('Durasi', '${b.durationCount} ${b.unit.noun} · ${b.occupants} penghuni'),
                ],
              ),
            ),
          ),

          // rincian biaya
          DetailBlock(
            title: 'Rincian biaya',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _Line('Sewa (${b.durationCount} ${b.unit.noun} × ${rupiah(b.pricePerUnit)})',
                        rupiah(b.pricePerUnit * b.durationCount)),
                    if (b.deposit > 0) _Line('Deposit', rupiah(b.deposit)),
                    _Line('Biaya admin', rupiah(b.adminFee)),
                    if (b.discount > 0)
                      _Line('Diskon', '-${rupiah(b.discount)}', valueColor: AppColors.success),
                    const Divider(height: 22),
                    _Line('Total', rupiah(b.total), bold: true),
                  ],
                ),
              ),
            ),
          ),

          // metode
          DetailBlock(
            title: 'Metode pembayaran',
            child: Column(
              children: [
                for (final m in _methods)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MethodTile(
                      method: m,
                      selected: _method.code == m.code,
                      onTap: () => setState(() => _method = m),
                    ),
                  ),
              ],
            ),
          ),

          // instruksi
          DetailBlock(
            title: 'Cara bayar',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _Instructions(
                  method: _method,
                  va: _vaNumber(b),
                  total: b.total,
                ),
              ),
            ),
          ),

          // bukti bayar (transfer bank)
          if (needsProof)
            DetailBlock(
              title: 'Bukti transfer',
              child: _ProofPicker(
                file: _proof,
                onPick: _pickProof,
                onRemove: () => setState(() => _proof = null),
              ),
            ),

          const SizedBox(height: 16),
          const Text(
            'Dengan membayar, kamu menyetujui syarat sewa kos ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _Line(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final w = bold ? FontWeight.w800 : FontWeight.w500;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: w,
                    color: bold ? AppColors.textPrimary : AppColors.textMuted)),
          ),
          const SizedBox(width: 12),
          Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: bold ? 16 : 13.5, fontWeight: w, color: valueColor)),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final _PayMethod method;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTile(
      {required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.marigoldSoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
              width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(method.icon, color: AppColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(method.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.ink : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Instructions extends StatelessWidget {
  final _PayMethod method;
  final String va;
  final int total;
  const _Instructions(
      {required this.method, required this.va, required this.total});

  @override
  Widget build(BuildContext context) {
    switch (method.kind) {
      case _MethodKind.bank:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nomor Virtual Account',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(va,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(letterSpacing: 1)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: va));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nomor VA disalin')));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Salin'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Step('1', 'Buka m-banking / ATM ${method.name.split(' ').first}.'),
            _Step('2', 'Pilih Transfer › Virtual Account, masukkan nomor di atas.'),
            _Step('3', 'Pastikan nominal tepat ${rupiah(total)}, lalu konfirmasi.'),
            _Step('4', 'Simpan bukti transfer dan unggah di bawah.'),
          ],
        );
      case _MethodKind.ewallet:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Step('1', 'Tekan "Bayar sekarang", kamu diarahkan ke aplikasi ${method.name}.'),
            _Step('2', 'Cek nominal ${rupiah(total)} lalu masukkan PIN.'),
            _Step('3', 'Kembali ke Ngekos.in, status otomatis diperbarui.'),
          ],
        );
      case _MethodKind.qris:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(Icons.qr_code_2_rounded,
                    size: 130, color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 12),
            _Step('1', 'Buka aplikasi bank / e-wallet apa pun yang mendukung QRIS.'),
            _Step('2', 'Pindai kode di atas, cek nominal ${rupiah(total)}.'),
            _Step('3', 'Selesaikan pembayaran, status otomatis diperbarui.'),
          ],
        );
    }
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step(this.n, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.marigoldSoft, shape: BoxShape.circle),
            child: Text(n,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}

class _ProofPicker extends StatelessWidget {
  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _ProofPicker(
      {required this.file, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final f = file;
    if (f == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_rounded, size: 32, color: AppColors.ink),
              SizedBox(height: 6),
              Text('Pilih foto bukti transfer',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text('JPG / PNG',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: kIsWeb
              ? Image.network(f.path,
                  height: 220, width: double.infinity, fit: BoxFit.cover)
              : Image.file(File(f.path),
                  height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _RoundBtn(Icons.edit_rounded, onPick),
              const SizedBox(width: 8),
              _RoundBtn(Icons.close_rounded, onRemove),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: AppColors.ink),
        ),
      ),
    );
  }
}
