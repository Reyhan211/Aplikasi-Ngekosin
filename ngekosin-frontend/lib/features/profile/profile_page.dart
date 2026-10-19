import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/account_store.dart';
import '../../data/booking_store.dart';
import '../../data/owner_booking_store.dart';
import '../../data/favorites_store.dart';
import '../../data/models.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    AccountStore.instance.load(); // saldo koin & jumlah voucher
  }

  @override
  Widget build(BuildContext context) {
    // rebuild saat nama diubah / koin & voucher berubah
    return ListenableBuilder(
      listenable: Listenable.merge([AuthState.instance, AccountStore.instance]),
      builder: (context, _) {
        final user = AuthState.instance.user;
        final acc = AccountStore.instance;
        final isOwner = user?.role == 'pemilik';

        // (ikon, label, rute, info kecil di kanan)
        final menus = <(IconData, String, String, String?)>[
          (Icons.person_outline_rounded, 'Ubah profil', '/account/edit', null),
          (
            Icons.stars_rounded,
            'Koin Ngekos',
            '/account/coins',
            thousands(acc.coins),
          ),
          (
            Icons.local_offer_outlined,
            'Voucher & promo',
            '/account/vouchers',
            acc.activeVoucherCount > 0
                ? '${acc.activeVoucherCount} voucher'
                : null,
          ),
          (
            Icons.store_mall_directory_outlined,
            'Mode pemilik kos',
            '/account/owner',
            isOwner
                ? 'Aktif'
                : (acc.ownerStatus == OwnerStatus.pending ? 'Diproses' : null),
          ),
          (Icons.help_outline_rounded, 'Bantuan', '/account/help', null),
        ];

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              Text('Akun', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.marigold,
                        child: Text(
                          (user?.name.isNotEmpty ?? false)
                              ? user!.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              user == null
                                  ? ''
                                  : (user.username == null
                                      ? user.email
                                      : '@${user.username} · ${user.email}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final (icon, label, route, info) in menus)
                ListTile(
                  leading: Icon(icon, color: AppColors.ink),
                  title: Text(label),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (info != null)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.marigoldSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            info,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => context.push(route),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  FavoritesStore.instance.clear();
                  BookingStore.instance.clear();
                  OwnerBookingStore.instance.clear();
                  AccountStore.instance.clear();
                  AuthState.instance.logout(); // router otomatis ke /login
                },
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
