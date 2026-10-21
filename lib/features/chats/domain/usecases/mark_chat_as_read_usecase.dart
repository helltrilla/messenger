import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/chat_repository.dart';

class MarkChatAsReadUseCase {
  final ChatRepository _repository;

  const MarkChatAsReadUseCase(this._repository);

  Future<Result<Failure, void>> call({
    required String chatId,
    required String messageId,
  }) {
    return _repository.markChatAsRead(chatId, messageId);
  }
}
