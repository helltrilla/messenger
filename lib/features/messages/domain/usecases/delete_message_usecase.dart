import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/message_repository.dart';

class DeleteMessageUseCase {
  final MessageRepository _repository;

  const DeleteMessageUseCase(this._repository);

  Future<Result<Failure, void>> call({
    required String messageId,
    required String chatId,
    String? mediaUrl,
  }) {
    return _repository.deleteMessage(
      messageId: messageId,
      chatId: chatId,
      mediaUrl: mediaUrl,
    );
  }
}
