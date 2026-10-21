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
}
