import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUseCase {
  final AuthRepository _repository;

  const VerifyOtpUseCase(this._repository);

  Future<Result<Failure, UserEntity>> call({
    required String email,
    required String token,
  }) {
    return _repository.verifyOtp(email: email, token: token);
  }
}
