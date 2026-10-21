import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpUseCase {
  final AuthRepository _repository;

  const SignUpUseCase(this._repository);

  Future<Result<Failure, UserEntity>> call({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) {
    return _repository.signUp(
      email: email,
      password: password,
      username: username,
      displayName: displayName,
    );
  }
}
