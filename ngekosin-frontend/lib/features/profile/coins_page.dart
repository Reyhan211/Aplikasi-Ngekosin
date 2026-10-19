import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/account_store.dart';
import '../../models/account.dart';

/// Saldo & riwayat Koin Ngekos.
class CoinsPage extends StatefulWidget {
  const CoinsPage({super.key});

  @override
  State<CoinsPage> createState() => _CoinsPageState();
}

class _CoinsPageState extends State<CoinsPage> {
  @override
  void initState() {
    super.initState();
    AccountStore.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koin Ngekos')),
      body: ListenableBuilder(
        listenable: AccountStore.instance,
        builder: (context, _) {
          final s = AccountStore.instance;
          final history = s.history;
          return RefreshIndicator(
            onRefresh: s.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _BalanceCard(coins: s.coins),
                const SizedBox(height: 24),
                Text('Cara dapat koin', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                const Card(
                  child: Column(
                    children: [
                      _EarnRow(
                        icon: Icons.home_work_outlined,
                        text: 'Selesaikan masa sewa kos',
                        reward: '+500',
                      ),
                      Divider(),
                      _EarnRow(
                        icon: Icons.rate_review_outlined,
                        text: 'Tulis ulasan setelah menempati kos',
                        reward: '+50',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Riwayat koin', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Belum ada riwayat koin.',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < history.length; i++) ...[
                          if (i > 0) const Divider(),
                          _TxRow(tx: history[i]),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int coins;
  const _BalanceCard({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.ink, AppColors.inkDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.stars_rounded, color: AppColors.marigold, size: 20),
              SizedBox(width: 8),
              Text('Saldo koin kamu', style: TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            thousands(coins),
            style: const TextStyle(
                color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, height: 1.1),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kumpulkan koin dari setiap sewa dan ulasan.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String reward;
  const _EarnRow({required this.icon, required this.text, required this.reward});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          Text(reward,
              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final CoinTx tx;
  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final plus = tx.amount >= 0;
    final color = plus ? AppColors.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(plus ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(DateFormat('d MMM yyyy', 'id_ID').format(tx.date),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text('${plus ? '+' : '-'}${thousands(tx.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
