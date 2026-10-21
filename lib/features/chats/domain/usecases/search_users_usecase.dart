import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/user_profile_entity.dart';
import '../repositories/chat_repository.dart';

class SearchUsersUseCase {
  final ChatRepository _repository;

  const SearchUsersUseCase(this._repository);

  Future<Result<Failure, List<UserProfileEntity>>> call(String query) {
    return _repository.searchUsers(query);
  }
}
