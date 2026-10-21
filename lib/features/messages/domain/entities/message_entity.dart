enum MessageStatus {
  pending, // 🕒 Optimistic update
  sent, // ✓ Confirmed by server
  read, // ✓✓ Read by recipient
  failed, // ⚠️ Transmission failure
}

class MessageEntity {
  final String id;
  final String chatId;
  final String senderId;
  final String? content;
  final String type; // 'text', 'image', 'voice', 'file'
  final String? mediaUrl;
  final String? blurhash;
  final int? durationSec;
  final DateTime createdAt;
  final bool isMine;
  final bool isEdited;
  final MessageStatus status;

  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.content,
    this.type = 'text',
    this.mediaUrl,
    this.blurhash,
    this.durationSec,
    required this.createdAt,
    required this.isMine,
    this.isEdited = false,
    this.status = MessageStatus.sent,
  });

  MessageEntity copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? content,
    String? type,
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
    DateTime? createdAt,
    bool? isMine,
    bool? isEdited,
    MessageStatus? status,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      blurhash: blurhash ?? this.blurhash,
      durationSec: durationSec ?? this.durationSec,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
      isEdited: isEdited ?? this.isEdited,
      status: status ?? this.status,
    );
  }
}
