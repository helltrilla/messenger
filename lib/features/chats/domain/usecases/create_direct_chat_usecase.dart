import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/chat_repository.dart';

class CreateDirectChatUseCase {
  final ChatRepository _repository;

  const CreateDirectChatUseCase(this._repository);

  Future<Result<Failure, String>> call(String targetUserId) {
    return _repository.createDirectChat(targetUserId);
  }
}
