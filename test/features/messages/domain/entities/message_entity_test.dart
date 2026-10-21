import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/features/messages/data/models/message_model.dart';
import 'package:messenger/features/messages/domain/entities/message_entity.dart';

void main() {
  group('MessageEntity tests', () {
    test('copyWith updates status correctly for optimistic updates', () {
      final now = DateTime.now();
      final message = MessageEntity(
        id: 'temp-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        content: 'Hello World',
        createdAt: now,
        isMine: true,
        status: MessageStatus.pending,
      );

      expect(message.status, MessageStatus.pending);

      final sentMessage = message.copyWith(
        id: 'server-123',
        status: MessageStatus.sent,
      );

      expect(sentMessage.id, 'server-123');
      expect(sentMessage.status, MessageStatus.sent);
      expect(sentMessage.content, 'Hello World');
      expect(sentMessage.isMine, isTrue);
    });

    test('MessageModel.fromMap parses is_read and sets status to read', () {
      final now = DateTime.now();
      final map = {
        'id': 'msg-1',
        'chat_id': 'chat-1',
        'sender_id': 'my-uid',
        'content': 'Test message',
        'created_at': now.toIso8601String(),
        'is_read': true,
      };

      final readMessage = MessageModel.fromMap(map, 'my-uid');
      expect(readMessage.isMine, isTrue);
      expect(readMessage.status, MessageStatus.read);

      final unreadMap = {
        'id': 'msg-2',
        'chat_id': 'chat-1',
        'sender_id': 'my-uid',
        'content': 'Unread message',
        'created_at': now.toIso8601String(),
        'is_read': false,
      };

      final unreadMessage = MessageModel.fromMap(unreadMap, 'my-uid');
      expect(unreadMessage.isMine, isTrue);
      expect(unreadMessage.status, MessageStatus.sent);
    });

    test(
      'MessageModel.fromMap parses is_edited correctly and copyWith retains/updates it',
      () {
        final now = DateTime.now();
        final map = {
          'id': 'msg-edit-1',
          'chat_id': 'chat-1',
          'sender_id': 'my-uid',
          'content': 'Original text',
          'created_at': now.toIso8601String(),
          'is_edited': true,
        };

        final model = MessageModel.fromMap(map, 'my-uid');
        expect(model.isEdited, isTrue);

        final editedCopy = model.copyWith(
          content: 'New edited text',
          isEdited: true,
        );
        expect(editedCopy.content, 'New edited text');
        expect(editedCopy.isEdited, isTrue);
      },
    );

    test('Video note message entity supports type, mediaUrl and durationSec', () {
      final now = DateTime.now();
      final videoMsg = MessageEntity(
        id: 'video-1',
        chatId: 'chat-10',
        senderId: 'user-1',
        type: 'video',
        mediaUrl:
            'https://supabase.co/storage/v1/object/public/chat-media/circle.mp4',
        durationSec: 18,
        createdAt: now,
        isMine: true,
        status: MessageStatus.sent,
      );

      expect(videoMsg.type, 'video');
      expect(videoMsg.durationSec, 18);
      expect(videoMsg.mediaUrl, contains('circle.mp4'));

      final updated = videoMsg.copyWith(status: MessageStatus.read);
      expect(updated.status, MessageStatus.read);
      expect(updated.type, 'video');
    });
  });
}
