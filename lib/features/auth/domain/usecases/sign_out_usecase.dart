import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/auth_repository.dart';

class SignOutUseCase {
  final AuthRepository _repository;

  const SignOutUseCase(this._repository);

  Future<Result<Failure, void>> call() {
    return _repository.signOut();
  }
}
