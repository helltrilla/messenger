import 'dart:typed_data';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';
import '../datasources/message_remote_data_source.dart';

class MessageRepositoryImpl implements MessageRepository {
  final MessageRemoteDataSource _dataSource;

  MessageRepositoryImpl(this._dataSource);

  @override
  String? get currentUserId => _dataSource.currentUserId;

  @override
  Future<Result<Failure, List<MessageEntity>>> getMessages({
    required String chatId,
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      final messages = await _dataSource.fetchMessages(
        chatId: chatId,
        limit: limit,
        before: before,
      );
      return Result.success(messages);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось получить сообщения: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, MessageEntity>> sendMessage({
    required String chatId,
    String? content,
    String type = 'text',
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
    String? replyToId,
  }) async {
    try {
      final message = await _dataSource.sendMessage(
        chatId: chatId,
        content: content,
        type: type,
        mediaUrl: mediaUrl,
        blurhash: blurhash,
        durationSec: durationSec,
        replyToId: replyToId,
      );
      return Result.success(message);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось отправить сообщение: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, void>> editMessage({
    required String messageId,
    required String chatId,
    required String newContent,
  }) async {
    try {
      await _dataSource.editMessage(
        messageId: messageId,
        chatId: chatId,
        newContent: newContent,
      );
      return Result.success(null);
    } catch (e) {
      return Result.error(
        ServerFailure(
          message: 'Не удалось отредактировать сообщение: $e',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<Failure, void>> deleteMessage({
    required String messageId,
    required String chatId,
    String? mediaUrl,
  }) async {
    try {
      await _dataSource.deleteMessage(
        messageId: messageId,
        chatId: chatId,
        mediaUrl: mediaUrl,
      );
      return Result.success(null);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось удалить сообщение: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, String>> uploadMedia({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final url = await _dataSource.uploadMedia(
        bytes: bytes,
        fileName: fileName,
      );
      return Result.success(url);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Ошибка загрузки медиа: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, void>> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    try {
      await _dataSource.toggleReaction(messageId: messageId, emoji: emoji);
      return Result.success(null);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Ошибка при отправке реакции: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, void>> setTyping({
    required String chatId,
    required bool isTyping,
  }) async {
    try {
      await _dataSource.setTyping(chatId: chatId, isTyping: isTyping);
      return Result.success(null);
    } catch (e) {
      return Result.error(
        ServerFailure(
          message: 'Ошибка обновления статуса набора: $e',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<Failure, void>> setUserPresence({
    required bool isOnline,
  }) async {
    try {
      await _dataSource.setUserPresence(isOnline: isOnline);
      return Result.success(null);
    } catch (e) {
      return Result.error(
        ServerFailure(
          message: 'Ошибка обновления статуса присутствия: $e',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<Failure, List<MessageEntity>>> searchMessages({
    required String chatId,
    required String query,
  }) async {
    try {
      final results = await _dataSource.searchMessages(
        chatId: chatId,
        query: query,
      );
      return Result.success(results);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Ошибка поиска сообщений: $e', cause: e),
      );
    }
  }
}
