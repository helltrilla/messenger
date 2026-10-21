import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/message_entity.dart';
import '../repositories/message_repository.dart';

class GetMessagesUseCase {
  final MessageRepository _repository;

  const GetMessagesUseCase(this._repository);

  Future<Result<Failure, List<MessageEntity>>> call({
    required String chatId,
    int limit = 50,
    DateTime? before,
  }) {
    return _repository.getMessages(
      chatId: chatId,
      limit: limit,
      before: before,
    );
  }
}
