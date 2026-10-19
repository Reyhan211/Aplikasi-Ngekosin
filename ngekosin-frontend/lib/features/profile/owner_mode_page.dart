import 'package:flutter/material.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/account_store.dart';
import '../../models/account.dart';

/// Mode pemilik kos: penjelasan + pengajuan jadi pemilik.
/// Dashboard pemilik (kelola kos, booking masuk) belum ada: lihat TODO /owner di router.
class OwnerModePage extends StatefulWidget {
  const OwnerModePage({super.key});

  @override
  State<OwnerModePage> createState() => _OwnerModePageState();
}

class _OwnerModePageState extends State<OwnerModePage> {
  bool _submitting = false;

  static const _benefits = <(IconData, String, String)>[
    (Icons.add_home_work_outlined, 'Pasang iklan kos', 'Tambahkan kos, foto, dan tipe kamar dengan mudah.'),
    (Icons.fact_check_outlined, 'Kelola pengajuan sewa', 'Terima atau tolak pengajuan dari calon penyewa.'),
    (Icons.chat_bubble_outline_rounded, 'Chat langsung', 'Jawab pertanyaan calon penyewa lewat aplikasi.'),
    (Icons.payments_outlined, 'Pantau pendapatan', 'Lihat riwayat pembayaran dan okupansi kamar.'),
  ];

  Future<void> _apply() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daftar sebagai pemilik kos?'),
        content: const Text(
            'Pengajuanmu akan ditinjau tim Ngekos.in. Kamu tetap bisa mencari dan menyewa kos seperti biasa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajukan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await AccountStore.instance.applyOwner();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mode pemilik kos')),
      body: ListenableBuilder(
        listenable: Listenable.merge([AuthState.instance, AccountStore.instance]),
        builder: (context, _) {
          final isOwner = AuthState.instance.user?.role == 'pemilik';
          final pending = AccountStore.instance.ownerStatus == OwnerStatus.pending;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.store_mall_directory_rounded, color: AppColors.marigold, size: 32),
                    SizedBox(height: 12),
                    Text('Punya kos? Kelola di Ngekos.in',
                        style: TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('Jangkau ribuan pencari kos dan kelola semuanya dari satu aplikasi.',
                        style: TextStyle(color: Colors.white70, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (isOwner)
                _StatusCard(
                  icon: Icons.verified_rounded,
                  color: AppColors.success,
                  title: 'Kamu sudah terdaftar sebagai pemilik',
                  message: 'Dashboard pemilik sedang disiapkan dan akan segera tersedia.',
                )
              else if (pending)
                _StatusCard(
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.marigold,
                  title: 'Pengajuan sedang ditinjau',
                  message: 'Kami akan memberi kabar setelah pengajuanmu selesai diperiksa.',
                ),
              if (isOwner || pending) const SizedBox(height: 20),
              Text('Yang bisa kamu lakukan', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < _benefits.length; i++) ...[
                      if (i > 0) const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.marigoldSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_benefits[i].$1, color: AppColors.ink, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_benefits[i].$2,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(_benefits[i].$3,
                                      style: const TextStyle(
                                          color: AppColors.textMuted, fontSize: 13, height: 1.35)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isOwner && !pending) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _apply,
                  style: AppTheme.ctaStyle,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                      : const Text('Daftar sebagai pemilik kos'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(message,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
