import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/message_entity.dart';
import '../repositories/message_repository.dart';

class SearchMessagesUseCase {
  final MessageRepository _repository;

  const SearchMessagesUseCase(this._repository);

  Future<Result<Failure, List<MessageEntity>>> call({
    required String chatId,
    required String query,
  }) {
    return _repository.searchMessages(chatId: chatId, query: query);
  }
}
