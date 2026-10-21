import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/chat_entity.dart';
import '../entities/user_profile_entity.dart';

abstract class ChatRepository {
  Future<Result<Failure, List<ChatEntity>>> getChats();
  Future<Result<Failure, String>> createDirectChat(String targetUserId);
  Future<Result<Failure, List<UserProfileEntity>>> searchUsers(String query);
  Future<Result<Failure, void>> markChatAsRead(String chatId, String messageId);
}
