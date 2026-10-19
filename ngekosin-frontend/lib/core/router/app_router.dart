import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/area.dart';
import '../../models/campus.dart';
import '../../models/chat.dart';
import '../auth/auth_state.dart';
import '../../features/area/all_areas_page.dart';
import '../../features/area/all_campuses_page.dart';
import '../../features/area/area_kos_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/booking/booking_page.dart';
import '../../features/chat/chat_list_page.dart';
import '../../features/payment/payment_page.dart';
import '../../features/chat/chat_room_page.dart';
import '../../features/explore/explore_page.dart';
import '../../features/favorites/favorites_page.dart';
import '../../features/home/home_page.dart';
import '../../features/kos/kos_detail_page.dart';
import '../../features/kos/reviews_page.dart';
import '../../features/kos_saya/kos_saya_page.dart';
import '../../features/profile/coins_page.dart';
import '../../features/profile/edit_profile_page.dart';
import '../../features/profile/help_page.dart';
import '../../features/profile/owner_mode_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/vouchers_page.dart';
import '../../shared/widgets/main_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Tab yang wajib login.
const _protectedTabs = ['/favorites', '/kos-saya', '/chat', '/profile', '/account', '/payment'];

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/home',
  refreshListenable: AuthState.instance,
  redirect: (context, state) {
    final auth = AuthState.instance;
    final loc = state.matchedLocation;
    if (!auth.isLoggedIn && _protectedTabs.any(loc.startsWith)) return '/login';
    // form Ajukan Sewa juga wajib login
    if (!auth.isLoggedIn && loc.endsWith('/booking')) return '/login';
    if (auth.isLoggedIn && (loc == '/login' || loc == '/register')) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),

    // Halaman di luar bottom nav (menutupi nav bar)
    GoRoute(
      path: '/kos/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          KosDetailPage(kosId: int.parse(state.pathParameters['id']!)),
    ),
    // Pencarian: dibuka dari kolom cari & shortcut di Beranda
    GoRoute(
      path: '/explore',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => ExplorePage(
        initialQuery: state.uri.queryParameters['q'],
        initialType: state.uri.queryParameters['type'],
      ),
    ),
    GoRoute(
      path: '/kos/:id/reviews',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => ReviewsPage(
        kosId: int.parse(state.pathParameters['id']!),
        kosName: (state.extra as String?) ?? 'kos ini',
      ),
    ),
    GoRoute(
      path: '/areas',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const AllAreasPage(),
    ),
    GoRoute(
      path: '/area/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) {
        final area = state.extra as Area?;
        // dibuka tanpa data area (mis. refresh web): tampilkan daftar semua area
        return area == null ? const AllAreasPage() : AreaKosPage(area: area);
      },
    ),
    GoRoute(
      path: '/campuses',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const AllCampusesPage(),
    ),
    GoRoute(
      path: '/campus/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) {
        final campus = state.extra as Campus?;
        return campus == null ? const AllCampusesPage() : AreaKosPage(campus: campus);
      },
    ),
    GoRoute(
      path: '/kos/:id/booking',
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          BookingPage(kosId: int.parse(state.pathParameters['id']!)),
    ),
    // Ruang chat (menutupi bottom nav). `extra` = ChatRoom agar header langsung tampil.
    GoRoute(
      path: '/chat/:roomId',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => ChatRoomPage(
        roomId: int.parse(state.pathParameters['roomId']!),
        room: state.extra as ChatRoom?,
      ),
    ),
    // Halaman dari menu Akun (menutupi bottom nav)
    GoRoute(
      path: '/account/edit',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const EditProfilePage(),
    ),
    GoRoute(
      path: '/account/coins',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const CoinsPage(),
    ),
    GoRoute(
      path: '/account/vouchers',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const VouchersPage(),
    ),
    GoRoute(
      path: '/account/owner',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const OwnerModePage(),
    ),
    GoRoute(
      path: '/account/help',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const HelpPage(),
    ),
    // Pembayaran sewa (menutupi bottom nav)
    GoRoute(
      path: '/payment/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          PaymentPage(bookingId: int.parse(state.pathParameters['id']!)),
    ),
    // TODO: /booking/:id, /owner/...

    // 5 tab bottom nav, masing-masing punya stack navigasi sendiri
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/favorites', builder: (_, __) => const FavoritesPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/kos-saya',
            builder: (_, state) => KosSayaPage(
              tab: state.uri.queryParameters['tab'],
              stamp: state.uri.queryParameters['t'],
            ),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/chat', builder: (_, __) => const ChatListPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        ]),
      ],
    ),
  ],
);
