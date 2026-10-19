import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/chat_repository.dart';
import '../../models/chat.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/smart_image.dart';

/// Tab Chat: daftar percakapan dengan pemilik kos.
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _repo = ChatRepository.instance;
  late Future<List<ChatRoom>> _future = _repo.rooms();

  void _reload() => setState(() => _future = _repo.rooms());

  Future<void> _open(ChatRoom r) async {
    await context.push('/chat/${r.id}', extra: r);
    if (mounted) _reload(); // segarkan preview & badge setelah kembali
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Chat', style: Theme.of(context).textTheme.headlineSmall),
          ),
          Expanded(
            child: FutureBuilder<List<ChatRoom>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.ink));
                }
                if (snap.hasError) {
                  return EmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Gagal memuat chat',
                    message: 'Periksa koneksi internet kamu lalu coba lagi.',
                    actionLabel: 'Coba lagi',
                    onAction: _reload,
                  );
                }
                final rooms = snap.data ?? const <ChatRoom>[];
                if (rooms.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Belum ada percakapan',
                    message:
                        'Buka detail kos lalu ketuk tombol chat untuk bertanya langsung ke pemilik.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.ink,
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _RoomTile(room: rooms[i], onTap: () => _open(rooms[i])),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final ChatRoom room;
  final VoidCallback onTap;
  const _RoomTile({required this.room, required this.onTap});

  static String _time(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return DateFormat('HH:mm').format(t);
    if (diff == 1) return 'Kemarin';
    return DateFormat('d MMM', 'id_ID').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = room.unread > 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: SmartImage(
                    path: room.kosCoverUrl,
                    fallback: const _CoverFallback(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.kosName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(room.otherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      room.lastMessage ?? 'Mulai percakapan…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread ? AppColors.textPrimary : AppColors.textMuted,
                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_time(room.lastMessageAt),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.marigold, borderRadius: BorderRadius.circular(10)),
                      child: Text('${room.unread}',
                          style: const TextStyle(
                              color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 12)),
                    )
                  else
                    const SizedBox(height: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.marigoldSoft,
        child: const Icon(Icons.home_work_rounded, color: AppColors.ink),
      );
}
