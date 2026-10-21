import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/message_repository.dart';

class SetTypingUseCase {
  final MessageRepository _repository;

  const SetTypingUseCase(this._repository);

  Future<Result<Failure, void>> call({
    required String chatId,
    required bool isTyping,
  }) {
    return _repository.setTyping(chatId: chatId, isTyping: isTyping);
  }
}
