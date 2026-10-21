import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/chat_repository.dart';

class TogglePinChatUseCase {
  final ChatRepository _repository;

  const TogglePinChatUseCase(this._repository);

  Future<Result<Failure, void>> call({
    required String chatId,
    required bool isPinned,
  }) {
    return _repository.togglePinChat(chatId: chatId, isPinned: isPinned);
  }
}
