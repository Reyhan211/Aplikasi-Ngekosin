import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

/// Pusat bantuan: FAQ + kontak.
/// TODO: ganti nomor WhatsApp & email di bawah dengan kontak asli.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _whatsapp = '6281234567890';
  static const _email = 'halo@ngekos.in';

  static const _faqs = <(String, String)>[
    (
      'Bagaimana cara mengajukan sewa kos?',
      'Buka halaman kos yang kamu mau, lalu tekan "Ajukan Sewa". Pilih tipe kamar, tanggal masuk, dan lama sewa, isi data penyewa, kemudian kirim pengajuan.'
    ),
    (
      'Berapa lama pengajuan dikonfirmasi pemilik?',
      'Pemilik kos punya waktu 24 jam untuk mengonfirmasi. Jika lewat dari itu, pengajuan akan kedaluwarsa dan kamu bisa mengajukan ulang.'
    ),
    (
      'Bagaimana cara membatalkan pengajuan?',
      'Buka tab Kos Saya, pilih pengajuan yang masih menunggu konfirmasi atau pembayaran, lalu tekan "Batalkan".'
    ),
    (
      'Bagaimana memakai kode promo atau voucher?',
      'Salin kode dari menu Voucher & promo, lalu tempel di kolom kode promo saat mengisi form Ajukan Sewa. Perhatikan minimal sewa dan masa berlakunya.'
    ),
    (
      'Bagaimana menghubungi pemilik kos?',
      'Tekan tombol chat di halaman detail kos. Percakapanmu tersimpan di tab Chat.'
    ),
    (
      'Apa itu Koin Ngekos?',
      'Koin adalah poin reward yang kamu dapat dari aktivitas seperti menyelesaikan masa sewa dan menulis ulasan. Saldo dan riwayatnya ada di menu Koin Ngekos.'
    ),
  ];

  Future<void> _open(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tidak dapat membuka aplikasi. Coba lagi nanti.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Pertanyaan umum', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _faqs.length; i++) ...[
                  if (i > 0) const Divider(),
                  ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text(_faqs[i].$1,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    children: [
                      Text(_faqs[i].$2,
                          style: const TextStyle(color: AppColors.textMuted, height: 1.45)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Masih butuh bantuan?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_rounded, color: AppColors.success),
                  title: const Text('WhatsApp'),
                  subtitle: const Text('Chat dengan tim Ngekos.in'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _open(
                    context,
                    Uri.parse('https://wa.me/$_whatsapp?text=${Uri.encodeComponent('Halo Ngekos.in, saya butuh bantuan.')}'),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded, color: AppColors.ink),
                  title: const Text('Email'),
                  subtitle: const Text(_email),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _open(
                    context,
                    Uri.parse('mailto:$_email?subject=${Uri.encodeComponent('Bantuan Ngekos.in')}'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('Ngekos.in v1.0.0',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
