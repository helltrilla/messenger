import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    super.senderName,
    super.content,
    super.type,
    super.mediaUrl,
    super.blurhash,
    super.durationSec,
    super.replyToId,
    super.replyToContent,
    super.replyToSenderName,
    required super.createdAt,
    required super.isMine,
    super.isEdited,
    super.status,
    super.reactions,
  });

  factory MessageModel.fromMap(
    Map<String, dynamic> map,
    String currentUserId, {
    bool? isReadExplicit,
  }) {
    final isMine = map['sender_id'] == currentUserId;
    final isRead = isReadExplicit ?? (map['is_read'] == true);

    MessageStatus status = MessageStatus.sent;
    if (isMine) {
      status = isRead ? MessageStatus.read : MessageStatus.sent;
    }

    // Parse sender name
    final profile = map['profile'] ?? map['profiles'];
    final senderName = profile != null
        ? (profile['display_name'] ?? profile['username'])
        : null;

    // Parse reactions
    final rawReactions = map['reactions'] as List<dynamic>? ?? [];
    final reactionMap = <String, List<String>>{};
    for (final r in rawReactions) {
      if (r is Map) {
        final emoji = r['emoji'] as String?;
        final uid = r['user_id'] as String?;
        if (emoji != null && uid != null) {
          reactionMap.putIfAbsent(emoji, () => []).add(uid);
        }
      }
    }
    final reactionEntities = reactionMap.entries.map((entry) {
      return ReactionEntity(
        emoji: entry.key,
        count: entry.value.length,
        hasReacted: entry.value.contains(currentUserId),
        userIds: entry.value,
      );
    }).toList();

    // Parse reply info
    final replyMap = map['reply_to'] ?? map['reply_to_message'];
    String? replyContent;
    String? replySenderName;
    if (replyMap != null && replyMap is Map<String, dynamic>) {
      replyContent = replyMap['content'];
      final replyProfile = replyMap['profile'] ?? replyMap['profiles'];
      if (replyProfile != null && replyProfile is Map) {
        replySenderName =
            replyProfile['display_name'] ?? replyProfile['username'];
      }
    }

    return MessageModel(
      id: map['id'],
      chatId: map['chat_id'],
      senderId: map['sender_id'],
      senderName: senderName,
      content: map['content'],
      type: map['type'] ?? 'text',
      mediaUrl: map['media_url'],
      blurhash: map['blurhash'],
      durationSec: map['duration_sec'],
      replyToId: map['reply_to_id'],
      replyToContent: replyContent,
      replyToSenderName: replySenderName,
      createdAt: DateTime.parse(map['created_at']),
      isMine: isMine,
      isEdited: map['is_edited'] == true,
      status: status,
      reactions: reactionEntities,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'type': type,
      'media_url': mediaUrl,
      'blurhash': blurhash,
      'duration_sec': durationSec,
      'reply_to_id': replyToId,
    };
  }
}
