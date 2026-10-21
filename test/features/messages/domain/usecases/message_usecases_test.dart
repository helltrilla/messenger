import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/errors/failure.dart';
import 'package:messenger/core/errors/result.dart';
import 'package:messenger/features/messages/domain/entities/message_entity.dart';
import 'package:messenger/features/messages/domain/repositories/message_repository.dart';
import 'package:messenger/features/messages/domain/usecases/delete_message_usecase.dart';
import 'package:messenger/features/messages/domain/usecases/edit_message_usecase.dart';

class MockMessageRepository implements MessageRepository {
  bool editCalled = false;
  bool deleteCalled = false;
  String? lastEditedMessageId;
  String? lastEditedContent;
  String? lastDeletedMessageId;
  String? lastDeletedMediaUrl;
  bool shouldFail = false;

  @override
  String? get currentUserId => 'test-user-id';

  @override
  Future<Result<Failure, void>> editMessage({
    required String messageId,
    required String chatId,
    required String newContent,
  }) async {
    editCalled = true;
    lastEditedMessageId = messageId;
    lastEditedContent = newContent;
    if (shouldFail) {
      return Result.error(ServerFailure(message: 'Failed to edit'));
    }
    return Result.success(null);
  }

  @override
  Future<Result<Failure, void>> deleteMessage({
    required String messageId,
    required String chatId,
    String? mediaUrl,
  }) async {
    deleteCalled = true;
    lastDeletedMessageId = messageId;
    lastDeletedMediaUrl = mediaUrl;
    if (shouldFail) {
      return Result.error(ServerFailure(message: 'Failed to delete'));
    }
    return Result.success(null);
  }

  @override
  Future<Result<Failure, List<MessageEntity>>> getMessages({
    required String chatId,
    int limit = 50,
    DateTime? before,
  }) async => Result.success([]);

  @override
  Future<Result<Failure, MessageEntity>> sendMessage({
    required String chatId,
    String? content,
    String type = 'text',
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
  }) async => Result.success(
    MessageEntity(
      id: '1',
      chatId: chatId,
      senderId: 'test-user-id',
      createdAt: DateTime.now(),
      isMine: true,
    ),
  );

  @override
  Future<Result<Failure, String>> uploadMedia({
    required Uint8List bytes,
    required String fileName,
  }) async => Result.success('https://example.com/media.jpg');
}

void main() {
  group('EditMessageUseCase & DeleteMessageUseCase tests', () {
    late MockMessageRepository mockRepository;
    late EditMessageUseCase editMessageUseCase;
    late DeleteMessageUseCase deleteMessageUseCase;

    setUp(() {
      mockRepository = MockMessageRepository();
      editMessageUseCase = EditMessageUseCase(mockRepository);
      deleteMessageUseCase = DeleteMessageUseCase(mockRepository);
    });

    test(
      'EditMessageUseCase calls repository.editMessage and returns success',
      () async {
        final result = await editMessageUseCase(
          messageId: 'msg-100',
          chatId: 'chat-200',
          newContent: 'Updated message content',
        );

        expect(mockRepository.editCalled, isTrue);
        expect(mockRepository.lastEditedMessageId, 'msg-100');
        expect(mockRepository.lastEditedContent, 'Updated message content');
        expect(result.isSuccess, isTrue);
      },
    );

    test('EditMessageUseCase returns failure when repository fails', () async {
      mockRepository.shouldFail = true;
      final result = await editMessageUseCase(
        messageId: 'msg-100',
        chatId: 'chat-200',
        newContent: 'Updated message content',
      );

      expect(mockRepository.editCalled, isTrue);
      expect(result.isError, isTrue);
    });

    test(
      'DeleteMessageUseCase calls repository.deleteMessage with mediaUrl and returns success',
      () async {
        final result = await deleteMessageUseCase(
          messageId: 'msg-100',
          chatId: 'chat-200',
          mediaUrl: 'https://storage/chat-media/uploads/photo.jpg',
        );

        expect(mockRepository.deleteCalled, isTrue);
        expect(mockRepository.lastDeletedMessageId, 'msg-100');
        expect(
          mockRepository.lastDeletedMediaUrl,
          'https://storage/chat-media/uploads/photo.jpg',
        );
        expect(result.isSuccess, isTrue);
      },
    );

    test(
      'DeleteMessageUseCase returns failure when repository fails',
      () async {
        mockRepository.shouldFail = true;
        final result = await deleteMessageUseCase(
          messageId: 'msg-100',
          chatId: 'chat-200',
        );

        expect(mockRepository.deleteCalled, isTrue);
        expect(result.isError, isTrue);
      },
    );
  });
}
