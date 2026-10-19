import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/account_store.dart';
import '../../models/account.dart';
import '../../shared/widgets/empty_state.dart';

/// Daftar voucher milik user + kolom untuk memasukkan kode baru.
/// Kode voucher dipakai di kolom promo saat Ajukan Sewa.
class VouchersPage extends StatefulWidget {
  const VouchersPage({super.key});

  @override
  State<VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends State<VouchersPage> {
  final _code = TextEditingController();
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    AccountStore.instance.load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _claim() async {
    FocusScope.of(context).unfocus();
    setState(() => _claiming = true);
    try {
      final v = await AccountStore.instance.claimVoucher(_code.text);
      if (!mounted) return;
      _code.clear();
      _toast('Voucher ${v.code} ditambahkan');
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _toast('Kode $code disalin. Tempel di kolom promo saat ajukan sewa.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voucher & promo')),
      body: ListenableBuilder(
        listenable: AccountStore.instance,
        builder: (context, _) {
          final list = AccountStore.instance.vouchers;
          return RefreshIndicator(
            onRefresh: AccountStore.instance.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _claiming ? null : _claim(),
                        decoration: const InputDecoration(hintText: 'Masukkan kode voucher'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _claiming ? null : _claim,
                      style: FilledButton.styleFrom(minimumSize: const Size(88, 52)),
                      child: _claiming
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Pakai'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Voucher saya', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  const SizedBox(
                    height: 320,
                    child: EmptyState(
                      icon: Icons.local_offer_outlined,
                      title: 'Belum ada voucher',
                      message: 'Punya kode promo? Masukkan di kolom atas untuk menambahkannya.',
                    ),
                  )
                else
                  for (final v in list) ...[
                    _VoucherCard(voucher: v, onCopy: () => _copy(v.code)),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final Voucher voucher;
  final VoidCallback onCopy;
  const _VoucherCard({required this.voucher, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final expired = v.expired;
    return Opacity(
      opacity: expired ? 0.55 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 92,
                color: AppColors.marigoldSoft,
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_offer_rounded, color: AppColors.ink),
                    const SizedBox(height: 6),
                    const Text('Diskon',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    Text(rupiahShort(v.discount),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.title, style: Theme.of(context).textTheme.titleMedium),
                      if (v.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(v.description,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Min. sewa ${rupiah(v.minAmount)}\n'
                        '${expired ? 'Kedaluwarsa' : 'Berlaku s/d'} '
                        '${DateFormat('d MMM yyyy', 'id_ID').format(v.expiresAt)}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: expired ? null : onCopy,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(v.code,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy_rounded, size: 16, color: AppColors.ink),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
