import '../../domain/entities/chat_entity.dart';

class ChatModel extends ChatEntity {
  const ChatModel({
    required super.id,
    required super.type,
    required super.title,
    super.avatarUrl,
    super.lastMessageText,
    super.lastMessageAt,
    super.unreadCount,
    super.partnerId,
    super.partnerUsername,
    super.lastMessageSenderId,
    super.isLastMessageRead,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String currentUserId) {
    String chatTitle = map['title'] ?? 'Чат';
    String? avatar = map['avatar_url'];
    String? partnerId;
    String? partnerUsername;

    if (map['type'] == 'direct' && map['members'] != null) {
      final members = map['members'] as List<dynamic>;
      for (final m in members) {
        final profile = m['profile'] ?? m['profiles'];
        if (profile != null && profile['id'] != currentUserId) {
          partnerId = profile['id'];
          partnerUsername = profile['username'];
          chatTitle =
              profile['display_name'] ?? profile['username'] ?? 'Пользователь';
          avatar = profile['avatar_url'];
          break;
        }
      }
    }

    int unread = 0;
    bool isLastRead = false;
    if (map['members'] != null) {
      final members = map['members'] as List<dynamic>;
      for (final m in members) {
        if (m['user_id'] == currentUserId) {
          unread = m['unread_count'] ?? 0;
        } else {
          final partnerUnread = m['unread_count'] as int? ?? 0;
          if (partnerUnread == 0) {
            isLastRead = true;
          }
        }
      }
    }

    return ChatModel(
      id: map['id'],
      type: map['type'] ?? 'direct',
      title: chatTitle,
      avatarUrl: avatar,
      lastMessageText: map['last_message_text'],
      lastMessageAt: map['last_message_at'] != null
          ? DateTime.tryParse(map['last_message_at'])
          : null,
      unreadCount: unread,
      partnerId: partnerId,
      partnerUsername: partnerUsername,
      lastMessageSenderId: map['last_message_sender_id'],
      isLastMessageRead: isLastRead,
    );
  }
}
