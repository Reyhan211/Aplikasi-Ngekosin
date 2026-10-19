import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

/// Kerangka 5 tab. Bottom nav berbentuk "pill" melayang (beda dari Mamikos
/// yang memakai bar datar penuh lebar).
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  static const _items = <_NavItem>[
    _NavItem('Beranda', Icons.home_outlined, Icons.home_rounded),
    _NavItem('Favorit', Icons.favorite_border_rounded, Icons.favorite_rounded),
    _NavItem('Kos Saya', Icons.home_work_outlined, Icons.home_work_rounded),
    _NavItem('Chat', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
    _NavItem('Akun', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // konten tampil di belakang pill nav
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final selected = navigationShell.currentIndex == i;
              return Expanded(
                flex: selected ? 3 : 2, // tab aktif dapat ruang lebih untuk label
                child: _NavButton(
                  item: _items[i],
                  selected: selected,
                  onTap: () => navigationShell.goBranch(
                    i,
                    // tap tab aktif lagi = kembali ke halaman awal tab itu
                    initialLocation: i == navigationShell.currentIndex,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem(this.label, this.icon, this.activeIcon);
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
                horizontal: selected ? 10 : 6, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.marigold : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            // FittedBox: kalau layar sangat sempit, isi mengecil, tidak meluber
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 22,
                    color: selected ? AppColors.ink : Colors.white70,
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
