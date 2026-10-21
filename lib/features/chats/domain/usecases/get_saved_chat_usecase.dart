import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/chat_entity.dart';
import '../repositories/chat_repository.dart';

class GetSavedChatUseCase {
  final ChatRepository _repository;

  const GetSavedChatUseCase(this._repository);

  Future<Result<Failure, ChatEntity>> call() {
    return _repository.getOrCreateSavedChat();
  }
}
