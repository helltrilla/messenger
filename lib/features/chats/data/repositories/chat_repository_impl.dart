import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _dataSource;

  ChatRepositoryImpl(this._dataSource);

  @override
  Future<Result<Failure, List<ChatEntity>>> getChats() async {
    try {
      final chats = await _dataSource.fetchChats();
      return Result.success(chats);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось загрузить чаты: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, String>> createDirectChat(String targetUserId) async {
    try {
      final chatId = await _dataSource.createDirectChat(targetUserId);
      return Result.success(chatId);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось создать диалог: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, String>> createGroupChat({
    required String title,
    required List<String> memberIds,
  }) async {
    try {
      final chatId = await _dataSource.createGroupChat(
        title: title,
        memberIds: memberIds,
      );
      return Result.success(chatId);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось создать группу: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, List<UserProfileEntity>>> searchUsers(
    String query,
  ) async {
    try {
      final users = await _dataSource.searchUsers(query);
      return Result.success(users);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Ошибка при поиске пользователей: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, void>> markChatAsRead(
    String chatId,
    String messageId,
  ) async {
    try {
      await _dataSource.markChatAsRead(chatId, messageId);
      return Result.success(null);
    } catch (e) {
      return Result.error(
        ServerFailure(
          message: 'Не удалось обновить статус прочтения: $e',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<Failure, void>> togglePinChat({
    required String chatId,
    required bool isPinned,
  }) async {
    try {
      await _dataSource.togglePinChat(chatId: chatId, isPinned: isPinned);
      return Result.success(null);
    } catch (e) {
      return Result.error(
        ServerFailure(
          message: 'Не удалось закрепить/открепить чат: $e',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<Failure, void>> pinMessage({
    required String chatId,
    String? messageId,
  }) async {
    try {
      await _dataSource.pinMessage(chatId: chatId, messageId: messageId);
      return Result.success(null);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось закрепить сообщение: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, ChatEntity>> getOrCreateSavedChat() async {
    try {
      final chat = await _dataSource.getOrCreateSavedChat();
      return Result.success(chat);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось открыть Избранное: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, void>> forwardToSavedMessages({
    required String? content,
    String type = 'text',
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
  }) async {
    try {
      await _dataSource.forwardToSavedMessages(
        content: content,
        type: type,
        mediaUrl: mediaUrl,
        blurhash: blurhash,
        durationSec: durationSec,
      );
      return Result.success(null);
    } catch (e) {
      return Result.error(
        ServerFailure(
          message: 'Не удалось сохранить в Избранное: $e',
          cause: e,
        ),
      );
    }
  }
}
