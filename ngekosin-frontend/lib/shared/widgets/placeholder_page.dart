import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Halaman sementara untuk fitur yang belum dikerjakan.
/// Daftar [todo] membantu pembagian tugas anggota tim.
class PlaceholderBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> todo;
  const PlaceholderBody({super.key, required this.icon, required this.title, required this.todo});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
      children: [
        Icon(icon, size: 56, color: AppColors.ink),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('Yang perlu dikerjakan:', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        for (final t in todo)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_box_outline_blank_rounded, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(t)),
              ],
            ),
          ),
      ],
    );
  }
}
