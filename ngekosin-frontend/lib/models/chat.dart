import 'dart:typed_data';

/// Satu percakapan antara pencari kos dan pemilik (tabel `chat_rooms`).
/// Bentuk JSON yang diharapkan dari GET /chat/rooms:
/// { id, kos: {id, name, cover_url}, other_name, last_message,
///   last_message_at, unread_count }
class ChatRoom {
  final int id;
  final int kosId;
  final String kosName;
  final String? kosCoverUrl;
  final String otherName; // nama lawan bicara (pemilik kos)
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unread;

  const ChatRoom({
    required this.id,
    required this.kosId,
    required this.kosName,
    this.kosCoverUrl,
    required this.otherName,
    this.lastMessage,
    this.lastMessageAt,
    this.unread = 0,
  });

  ChatRoom copyWith({String? lastMessage, DateTime? lastMessageAt, int? unread}) =>
      ChatRoom(
        id: id,
        kosId: kosId,
        kosName: kosName,
        kosCoverUrl: kosCoverUrl,
        otherName: otherName,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unread: unread ?? this.unread,
      );

  factory ChatRoom.fromJson(Map<String, dynamic> j) {
    final kos = (j['kos'] as Map?) ?? const {};
    final last = j['last_message']?.toString();
    return ChatRoom(
      id: int.parse(j['id'].toString()),
      kosId: int.tryParse('${kos['id'] ?? j['kos_id']}') ?? 0,
      kosName: (kos['name'] ?? j['kos_name'] ?? '').toString(),
      kosCoverUrl: (kos['cover_url'] ?? j['cover_url'])?.toString(),
      otherName: (j['other_name'] ?? 'Pemilik kos').toString(),
      lastMessage: (last == null || last.isEmpty) ? null : last,
      lastMessageAt: DateTime.tryParse('${j['last_message_at']}')?.toLocal(),
      unread: int.tryParse('${j['unread_count']}') ?? 0,
    );
  }
}

/// Satu pesan. Isi bisa teks, gambar, atau keduanya.
/// JSON: { id, room_id, sender_id, body, image_url, created_at }
class ChatMessage {
  final int id;
  final int roomId;
  final int senderId;
  final String body;
  final String? imageUrl;

  /// Hanya dipakai mode mock: gambar yang baru dipilih disimpan di memori.
  final Uint8List? localImage;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.body = '',
    this.imageUrl,
    this.localImage,
    required this.createdAt,
  });

  bool get hasImage => imageUrl != null || localImage != null;

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final img = j['image_url']?.toString();
    return ChatMessage(
      id: int.parse(j['id'].toString()),
      roomId: int.tryParse('${j['room_id']}') ?? 0,
      senderId: int.tryParse('${j['sender_id']}') ?? 0,
      body: (j['body'] ?? '').toString(),
      imageUrl: (img == null || img.isEmpty) ? null : img,
      // server menyimpan UTC ("...Z"); tampilkan dalam waktu perangkat (WIB)
      createdAt: (DateTime.tryParse('${j['created_at']}') ?? DateTime.now()).toLocal(),
    );
  }
}
