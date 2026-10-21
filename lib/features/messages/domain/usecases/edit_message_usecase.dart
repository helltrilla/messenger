import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/message_repository.dart';

class EditMessageUseCase {
  final MessageRepository _repository;

  const EditMessageUseCase(this._repository);

  Future<Result<Failure, void>> call({
    required String messageId,
    required String chatId,
    required String newContent,
  }) {
    return _repository.editMessage(
      messageId: messageId,
      chatId: chatId,
      newContent: newContent,
    );
  }
}
