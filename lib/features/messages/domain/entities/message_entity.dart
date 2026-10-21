enum MessageStatus {
  pending, // 🕒 Optimistic update
  sent, // ✓ Confirmed by server
  read, // ✓✓ Read by recipient
  failed, // ⚠️ Transmission failure
}

class ReactionEntity {
  final String emoji;
  final int count;
  final bool hasReacted;
  final List<String> userIds;

  const ReactionEntity({
    required this.emoji,
    required this.count,
    this.hasReacted = false,
    this.userIds = const [],
  });

  ReactionEntity copyWith({
    String? emoji,
    int? count,
    bool? hasReacted,
    List<String>? userIds,
  }) {
    return ReactionEntity(
      emoji: emoji ?? this.emoji,
      count: count ?? this.count,
      hasReacted: hasReacted ?? this.hasReacted,
      userIds: userIds ?? this.userIds,
    );
  }
}

class MessageEntity {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String? content;
  final String type; // 'text', 'image', 'voice', 'file'
  final String? mediaUrl;
  final String? blurhash;
  final int? durationSec;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderName;
  final DateTime createdAt;
  final bool isMine;
  final bool isEdited;
  final MessageStatus status;
  final List<ReactionEntity> reactions;

  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    this.content,
    this.type = 'text',
    this.mediaUrl,
    this.blurhash,
    this.durationSec,
    this.replyToId,
    this.replyToContent,
    this.replyToSenderName,
    required this.createdAt,
    required this.isMine,
    this.isEdited = false,
    this.status = MessageStatus.sent,
    this.reactions = const [],
  });

  MessageEntity copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? content,
    String? type,
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
    DateTime? createdAt,
    bool? isMine,
    bool? isEdited,
    MessageStatus? status,
    List<ReactionEntity>? reactions,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      blurhash: blurhash ?? this.blurhash,
      durationSec: durationSec ?? this.durationSec,
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
      isEdited: isEdited ?? this.isEdited,
      status: status ?? this.status,
      reactions: reactions ?? this.reactions,
    );
  }
}
