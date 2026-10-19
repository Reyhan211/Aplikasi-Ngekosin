import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Pembungkus FutureBuilder: loading, error + tombol coba lagi, kosong, data.
class AsyncList<T> extends StatelessWidget {
  final Future<List<T>> future;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, List<T>) builder;
  final double loadingHeight;
  final String emptyText;

  const AsyncList({
    super.key,
    required this.future,
    required this.onRetry,
    required this.builder,
    this.loadingHeight = 180,
    this.emptyText = 'Belum ada data.',
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            height: loadingHeight,
            child: const Center(child: CircularProgressIndicator(color: AppColors.ink)),
          );
        }
        if (snap.hasError) {
          return SizedBox(
            height: loadingHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat data.',
                      style: TextStyle(color: AppColors.textMuted)),
                  TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
                ],
              ),
            ),
          );
        }
        final data = snap.data ?? <T>[];
        if (data.isEmpty) {
          return SizedBox(
            height: loadingHeight,
            child: Center(
              child: Text(emptyText, style: const TextStyle(color: AppColors.textMuted)),
            ),
          );
        }
        return builder(context, data);
      },
    );
  }
}
