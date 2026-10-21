import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/chat_repository.dart';

class CreateGroupChatUseCase {
  final ChatRepository _repository;

  const CreateGroupChatUseCase(this._repository);

  Future<Result<Failure, String>> call({
    required String title,
    required List<String> memberIds,
  }) {
    return _repository.createGroupChat(title: title, memberIds: memberIds);
  }
}
