import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  UserEntity? get currentUser;
  Future<Result<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  });
  Future<Result<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  });
  Future<Result<Failure, void>> sendOtp({
    required String email,
    String? username,
    String? displayName,
  });
  Future<Result<Failure, UserEntity>> verifyOtp({
    required String email,
    required String token,
  });
  Future<Result<Failure, void>> signOut();
}
