import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    super.content,
    super.type,
    super.mediaUrl,
    super.blurhash,
    super.durationSec,
    required super.createdAt,
    required super.isMine,
    super.isEdited,
    super.status,
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

    return MessageModel(
      id: map['id'],
      chatId: map['chat_id'],
      senderId: map['sender_id'],
      content: map['content'],
      type: map['type'] ?? 'text',
      mediaUrl: map['media_url'],
      blurhash: map['blurhash'],
      durationSec: map['duration_sec'],
      createdAt: DateTime.parse(map['created_at']),
      isMine: isMine,
      isEdited: map['is_edited'] == true,
      status: status,
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
    };
  }
}
