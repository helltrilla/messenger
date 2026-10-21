import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  final AuthRepository _repository;

  const SignInUseCase(this._repository);

  Future<Result<Failure, UserEntity>> call({
    required String email,
    required String password,
  }) {
    return _repository.signIn(email: email, password: password);
  }
}
