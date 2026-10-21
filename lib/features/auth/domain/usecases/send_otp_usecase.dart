import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/auth_repository.dart';

class SendOtpUseCase {
  final AuthRepository _repository;

  const SendOtpUseCase(this._repository);

  Future<Result<Failure, void>> call({
    required String email,
    String? username,
    String? displayName,
  }) {
    return _repository.sendOtp(
      email: email,
      username: username,
      displayName: displayName,
    );
  }
}
