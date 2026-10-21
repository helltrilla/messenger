import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/chat_repository.dart';

class PinMessageUseCase {
  final ChatRepository _repository;

  const PinMessageUseCase(this._repository);

  Future<Result<Failure, void>> call({
    required String chatId,
    String? messageId,
  }) {
    return _repository.pinMessage(chatId: chatId, messageId: messageId);
  }
}
