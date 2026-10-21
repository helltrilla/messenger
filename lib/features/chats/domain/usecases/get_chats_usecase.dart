import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/chat_entity.dart';
import '../repositories/chat_repository.dart';

class GetChatsUseCase {
  final ChatRepository _repository;

  const GetChatsUseCase(this._repository);

  Future<Result<Failure, List<ChatEntity>>> call() {
    return _repository.getChats();
  }
}
