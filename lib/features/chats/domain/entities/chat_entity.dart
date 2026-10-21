class ChatEntity {
  final String id;
  final String type; // 'direct' or 'group'
  final String title;
  final String? avatarUrl;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? partnerId;
  final String? partnerUsername;
  final String? lastMessageSenderId;
  final bool isLastMessageRead;

  const ChatEntity({
    required this.id,
    required this.type,
    required this.title,
    this.avatarUrl,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.partnerId,
    this.partnerUsername,
    this.lastMessageSenderId,
    this.isLastMessageRead = false,
  });

  ChatEntity copyWith({
    String? id,
    String? type,
    String? title,
    String? avatarUrl,
    String? lastMessageText,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? partnerId,
    String? partnerUsername,
    String? lastMessageSenderId,
    bool? isLastMessageRead,
  }) {
    return ChatEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      partnerId: partnerId ?? this.partnerId,
      partnerUsername: partnerUsername ?? this.partnerUsername,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      isLastMessageRead: isLastMessageRead ?? this.isLastMessageRead,
    );
  }
}
