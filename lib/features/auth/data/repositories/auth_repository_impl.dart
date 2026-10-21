import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  UserEntity? get currentUser => _dataSource.currentUser;

  @override
  Future<Result<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _dataSource.signIn(email: email, password: password);
      return Result.success(user);
    } on AuthException catch (e) {
      return Result.error(AuthFailure(message: e.message, cause: e));
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось войти: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      final user = await _dataSource.signUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
      );
      return Result.success(user);
    } on AuthException catch (e) {
      return Result.error(AuthFailure(message: e.message, cause: e));
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось зарегистрироваться: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, void>> sendOtp({
    required String email,
    String? username,
    String? displayName,
  }) async {
    try {
      await _dataSource.sendOtp(
        email: email,
        username: username,
        displayName: displayName,
      );
      return Result.success(null);
    } on AuthException catch (e) {
      return Result.error(AuthFailure(message: e.message, cause: e));
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось отправить код: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, UserEntity>> verifyOtp({
    required String email,
    required String token,
  }) async {
    try {
      final user = await _dataSource.verifyOtp(email: email, token: token);
      return Result.success(user);
    } on AuthException catch (e) {
      return Result.error(AuthFailure(message: e.message, cause: e));
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось подтвердить код: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<Failure, void>> signOut() async {
    try {
      await _dataSource.signOut();
      return Result.success(null);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Не удалось выйти: $e', cause: e),
      );
    }
  }
}
