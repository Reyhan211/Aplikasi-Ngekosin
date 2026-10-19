import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/booking_store.dart';
import '../../models/booking.dart';
import '../../shared/widgets/kos_card.dart';

const _amber = Color(0xFF9A6A00);

/// Label + warna untuk kolom `status` booking.
(String, Color) bookingStatusInfo(String s) => switch (s) {
      'menunggu_konfirmasi' => ('Menunggu konfirmasi', _amber),
      'menunggu_pembayaran' => ('Menunggu pembayaran', _amber),
      'dibayar' => ('Sudah dibayar', AppColors.success),
      'aktif' => ('Aktif', AppColors.success),
      'selesai' => ('Selesai', AppColors.textMuted),
      'ditolak' => ('Ditolak', AppColors.danger),
      'dibatalkan' => ('Dibatalkan', AppColors.textMuted),
      'kadaluarsa' => ('Kedaluwarsa', AppColors.textMuted),
      _ => (s, AppColors.textMuted),
    };

/// Kartu satu pengajuan / sewa di halaman Kos Saya.
/// TODO: Perpanjang & Chat (aktif), Beri ulasan (selesai).
class BookingCard extends StatelessWidget {
  final Booking booking;
  const BookingCard({super.key, required this.booking});

  static final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');
  static final _timeFmt = DateFormat('d MMM, HH:mm', 'id_ID');

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pengajuan?'),
        content: Text('Pengajuan ${booking.code} untuk ${booking.kosName} akan dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await BookingStore.instance.cancel(booking);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final (label, color) = bookingStatusInfo(b.status);
    final pending = b.status == 'menunggu_konfirmasi' || b.status == 'menunggu_pembayaran';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/kos/${b.kosId}'),
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
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(b.kosName, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(b.kosLocation,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const Divider(height: 24),
              _Info(Icons.meeting_room_outlined, b.roomName),
              _Info(Icons.calendar_month_outlined,
                  '${_dateFmt.format(b.checkin)} - ${_dateFmt.format(b.checkout)}'),
              _Info(Icons.schedule_rounded,
                  '${b.durationCount} ${b.unit.noun} · ${b.occupants} penghuni'),
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
              if (pending && b.expiresAt != null) ...[
                const SizedBox(height: 6),
                Text('Batas konfirmasi: ${_timeFmt.format(b.expiresAt!)}',
                    style: const TextStyle(color: _amber, fontSize: 12)),
              ],
              if (b.canPay) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.push('/payment/${b.id}'),
                  style: AppTheme.ctaStyle.copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
                  ),
                  icon: const Icon(Icons.payments_rounded, size: 20),
                  label: const Text('Bayar sekarang'),
                ),
              ],
              if (b.canCancel) ...[
                SizedBox(height: b.canPay ? 8 : 12),
                OutlinedButton(
                  onPressed: () => _cancel(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: const Text('Batalkan pengajuan'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}
