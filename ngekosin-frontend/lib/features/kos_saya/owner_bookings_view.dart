import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/owner_booking_store.dart';
import '../../models/booking.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/kos_card.dart';
import 'booking_card.dart';

/// Tampilan pemilik kos di tab Kos Saya: siapa yang mengajukan / membayar,
/// bukti transfer, dan tombol Setujui / Tolak / Aktifkan / Selesaikan.
class OwnerBookingsView extends StatefulWidget {
  const OwnerBookingsView({super.key});

  @override
  State<OwnerBookingsView> createState() => _OwnerBookingsViewState();
}

class _OwnerBookingsViewState extends State<OwnerBookingsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    OwnerBookingStore.instance.load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _label(String text, int n) => n > 0 ? '$text ($n)' : text;

  @override
  Widget build(BuildContext context) {
    final store = OwnerBookingStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Column(
        children: [
          TabBar(
            controller: _tabs,
            labelColor: AppColors.ink,
            indicatorColor: AppColors.marigold,
            indicatorWeight: 3,
            tabs: [
              Tab(text: _label('Perlu tindakan', store.count(OwnerGroup.perluTindakan))),
              Tab(text: _label('Berjalan', store.count(OwnerGroup.berjalan))),
              const Tab(text: 'Riwayat'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [for (final g in OwnerGroup.values) _OwnerList(group: g)],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerList extends StatelessWidget {
  final OwnerGroup group;
  const _OwnerList({required this.group});

  @override
  Widget build(BuildContext context) {
    final store = OwnerBookingStore.instance;
    final items = store.byGroup(group);

    if (items.isEmpty) {
      if (store.loading) {
        return const Center(child: CircularProgressIndicator(color: AppColors.ink));
      }
      if (store.error != null) {
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Gagal memuat',
          message: store.error!,
          actionLabel: 'Coba lagi',
          onAction: store.load,
        );
      }
      final (icon, title, msg) = switch (group) {
        OwnerGroup.perluTindakan => (
            Icons.inbox_outlined,
            'Tidak ada yang perlu ditindak',
            'Pengajuan baru dan pembayaran yang perlu diverifikasi muncul di sini.'
          ),
        OwnerGroup.berjalan => (
            Icons.key_outlined,
            'Belum ada sewa berjalan',
            'Penyewa yang menunggu bayar atau sedang menempati kosmu muncul di sini.'
          ),
        OwnerGroup.riwayat => (
            Icons.history_rounded,
            'Belum ada riwayat',
            'Sewa yang selesai, ditolak, atau dibatalkan tercatat di sini.'
          ),
      };
      return RefreshIndicator(
        onRefresh: store.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: 360, child: EmptyState(icon: icon, title: title, message: msg))],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: store.load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _OwnerBookingCard(booking: items[i]),
      ),
    );
  }
}

const _methodNames = {
  'bca': 'BCA Virtual Account',
  'mandiri': 'Mandiri Virtual Account',
  'bni': 'BNI Virtual Account',
  'gopay': 'GoPay',
  'dana': 'DANA',
  'qris': 'QRIS',
};

class _OwnerBookingCard extends StatefulWidget {
  final Booking booking;
  const _OwnerBookingCard({required this.booking});

  @override
  State<_OwnerBookingCard> createState() => _OwnerBookingCardState();
}

class _OwnerBookingCardState extends State<_OwnerBookingCard> {
  static final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');
  static final _timeFmt = DateFormat('d MMM, HH:mm', 'id_ID');
  bool _busy = false;

  Booking get b => widget.booking;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Konfirmasi lalu jalankan aksi ke server.
  Future<void> _run({
    required String action,
    required String title,
    required String message,
    required String confirmLabel,
    required String success,
    bool danger = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: danger ? AppColors.danger : AppColors.ink),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await OwnerBookingStore.instance.act(b, action);
      if (mounted) _snack(success);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: b.tenantPhone);
    var launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {}
    if (!launched) {
      await Clipboard.setData(ClipboardData(text: b.tenantPhone));
      if (mounted) _snack('Nomor ${b.tenantPhone} disalin');
    }
  }

  void _showProof() {
    final store = OwnerBookingStore.instance;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Bukti transfer',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  store.proofUrl(b),
                  headers: store.headers,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 140,
                    child: Center(child: Text('Gambar tidak bisa dimuat')),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = bookingStatusInfo(b.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TypeBadge(b.kosType),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(b.kosName, style: Theme.of(context).textTheme.titleMedium),
            Text('${b.roomName} · ${b.kosLocation}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const Divider(height: 24),

            // ---- siapa penyewanya
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.marigoldSoft,
                  child: Text(
                    b.tenantName.isEmpty ? '?' : b.tenantName[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.tenantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(b.tenantPhone,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Hubungi penyewa',
                  onPressed: _call,
                  icon: const Icon(Icons.call_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Info(Icons.calendar_month_outlined,
                '${_dateFmt.format(b.checkin)} - ${_dateFmt.format(b.checkout)}'),
            _Info(Icons.schedule_rounded,
                '${b.durationCount} ${b.unit.noun} · ${b.occupants} penghuni'),
            if (b.note != null) _Info(Icons.sticky_note_2_outlined, 'Catatan: ${b.note}'),

            // ---- pembayaran
            if (b.payMethod != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments_rounded, size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dibayar via ${_methodNames[b.payMethod] ?? b.payMethod}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                    if (b.payStatus == 'menunggu_verifikasi')
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 26),
                        child: Text('Menunggu verifikasi dari kamu',
                            style: TextStyle(color: Color(0xFF9A6A00), fontSize: 12.5)),
                      ),
                    if (b.hasProof)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _showProof,
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: const Text('Lihat bukti transfer'),
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (b.status == 'menunggu_pembayaran' || b.status == 'menunggu_konfirmasi') ...[
              const SizedBox(height: 10),
              Text(
                b.status == 'menunggu_konfirmasi'
                    ? 'Belum dibayar. Penyewa bisa membayar setelah kamu setujui.'
                    : 'Disetujui, menunggu penyewa membayar.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(b.code,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
                Text(rupiah(b.total), style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            if (b.expiresAt != null &&
                (b.status == 'menunggu_konfirmasi' || b.status == 'menunggu_pembayaran')) ...[
              const SizedBox(height: 4),
              Text('Batas waktu: ${_timeFmt.format(b.expiresAt!)}',
                  style: const TextStyle(color: Color(0xFF9A6A00), fontSize: 12)),
            ],
            ..._actions(),
          ],
        ),
      ),
    );
  }

  /// Tombol sesuai status pengajuan.
  List<Widget> _actions() {
    if (_busy) {
      return const [
        SizedBox(height: 14),
        Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      ];
    }
    final reject = OutlinedButton(
      onPressed: () => _run(
        action: 'reject',
        title: 'Tolak pengajuan?',
        message: 'Pengajuan ${b.code} dari ${b.tenantName} akan ditolak dan kamar kembali tersedia.',
        confirmLabel: 'Ya, tolak',
        success: 'Pengajuan ditolak',
        danger: true,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
      ),
      child: const Text('Tolak'),
    );
    FilledButton primary(String text, IconData icon, VoidCallback onTap) => FilledButton.icon(
          onPressed: onTap,
          style: AppTheme.ctaStyle.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
          ),
          icon: Icon(icon, size: 20),
          label: Text(text),
        );

    switch (b.status) {
      case 'menunggu_konfirmasi':
        return [
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: reject),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: primary(
                  'Setujui',
                  Icons.check_rounded,
                  () => _run(
                    action: 'confirm',
                    title: 'Setujui pengajuan?',
                    message: '${b.tenantName} akan diminta membayar ${rupiah(b.total)}.',
                    confirmLabel: 'Ya, setujui',
                    success: 'Pengajuan disetujui, menunggu pembayaran',
                  ),
                ),
              ),
            ],
          ),
        ];
      case 'menunggu_pembayaran':
        return [const SizedBox(height: 12), reject];
      case 'dibayar':
        return [
          const SizedBox(height: 14),
          primary(
            'Verifikasi & aktifkan sewa',
            Icons.verified_rounded,
            () => _run(
              action: 'activate',
              title: 'Aktifkan sewa?',
              message:
                  'Pastikan pembayaran ${rupiah(b.total)} dari ${b.tenantName} sudah kamu terima. '
                  'Sewa akan berstatus aktif.',
              confirmLabel: 'Ya, aktifkan',
              success: 'Sewa diaktifkan',
            ),
          ),
        ];
      case 'aktif':
        return [
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => _run(
              action: 'complete',
              title: 'Selesaikan sewa?',
              message:
                  'Masa sewa ${b.tenantName} dinyatakan selesai. Kamar kembali tersedia dan '
                  'penyewa mendapat koin.',
              confirmLabel: 'Ya, selesaikan',
              success: 'Sewa diselesaikan',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.ink),
            ),
            child: const Text('Selesaikan sewa'),
          ),
        ];
      default:
        return const [];
    }
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}
