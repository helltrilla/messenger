import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/features/chats/domain/entities/chat_entity.dart';

void main() {
  group('ChatEntity tests', () {
    test('copyWith updates unreadCount and lastMessageText correctly', () {
      final now = DateTime.now();
      const chat = ChatEntity(
        id: 'chat-1',
        type: 'direct',
        title: 'User A',
        unreadCount: 5,
        lastMessageText: 'Hello',
      );

      expect(chat.unreadCount, 5);

      final updated = chat.copyWith(
        unreadCount: 0,
        lastMessageText: 'New message',
        lastMessageAt: now,
      );

      expect(updated.id, 'chat-1');
      expect(updated.title, 'User A');
      expect(updated.unreadCount, 0);
      expect(updated.lastMessageText, 'New message');
      expect(updated.lastMessageAt, now);
    });
  });
}
