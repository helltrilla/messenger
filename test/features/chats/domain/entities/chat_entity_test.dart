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

    test('Chat folder filtering and unread counters work accurately', () {
      final chats = [
        const ChatEntity(
          id: '1',
          type: 'direct',
          title: 'Alice',
          unreadCount: 3,
        ),
        const ChatEntity(id: '2', type: 'direct', title: 'Bob', unreadCount: 0),
        const ChatEntity(id: '3', type: 'group', title: 'Team', unreadCount: 5),
        const ChatEntity(
          id: '4',
          type: 'saved',
          title: 'Избранное',
          unreadCount: 1,
        ),
      ];

      // Folder 0: All
      expect(chats.length, 4);
      final unreadAll = chats.fold<int>(0, (s, c) => s + c.unreadCount);
      expect(unreadAll, 9);

      // Folder 1: Direct
      final direct = chats.where((c) => c.type == 'direct').toList();
      expect(direct.length, 2);
      final unreadDirect = direct.fold<int>(0, (s, c) => s + c.unreadCount);
      expect(unreadDirect, 3);

      // Folder 2: Group
      final group = chats.where((c) => c.type == 'group').toList();
      expect(group.length, 1);
      final unreadGroup = group.fold<int>(0, (s, c) => s + c.unreadCount);
      expect(unreadGroup, 5);

      // Folder 3: Saved
      final saved = chats.where((c) => c.type == 'saved').toList();
      expect(saved.length, 1);
      final unreadSaved = saved.fold<int>(0, (s, c) => s + c.unreadCount);
      expect(unreadSaved, 1);
    });
  });
}
