import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/errors/failure.dart';
import 'package:messenger/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:messenger/features/auth/data/models/user_model.dart';
import 'package:messenger/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  bool throwAuthException = false;
  bool throwGenericException = false;

  @override
  UserModel? get currentUser => null;

  @override
  Future<void> sendOtp({
    required String email,
    String? username,
    String? displayName,
  }) async {
    if (throwAuthException) {
      throw const AuthException('Rate limit exceeded');
    }
    if (throwGenericException) {
      throw Exception('Socket timeout');
    }
  }

  @override
  Future<UserModel> verifyOtp({
    required String email,
    required String token,
  }) async {
    if (throwAuthException) {
      throw const AuthException('Token expired');
    }
    if (throwGenericException) {
      throw Exception('Network unreachable');
    }
    return UserModel(
      id: 'verified-id',
      email: email,
      username: 'user_123',
      displayName: 'Verified User',
    );
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  late FakeAuthRemoteDataSource fakeDataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    fakeDataSource = FakeAuthRemoteDataSource();
    repository = AuthRepositoryImpl(fakeDataSource);
  });

  group('AuthRepositoryImpl OTP tests', () {
    test('sendOtp returns Result.success when dataSource succeeds', () async {
      final result = await repository.sendOtp(email: 'test@example.com');
      expect(result.isSuccess, isTrue);
    });

    test(
      'sendOtp returns Result.error(AuthFailure) on AuthException',
      () async {
        fakeDataSource.throwAuthException = true;
        final result = await repository.sendOtp(email: 'test@example.com');
        expect(result.isError, isTrue);
        expect(result.failureOrNull, isA<AuthFailure>());
        expect(result.failureOrNull?.message, 'Rate limit exceeded');
      },
    );

    test(
      'sendOtp returns Result.error(ServerFailure) on generic Exception',
      () async {
        fakeDataSource.throwGenericException = true;
        final result = await repository.sendOtp(email: 'test@example.com');
        expect(result.isError, isTrue);
        expect(result.failureOrNull, isA<ServerFailure>());
      },
    );

    test(
      'verifyOtp returns Result.success(UserEntity) on valid token',
      () async {
        final result = await repository.verifyOtp(
          email: 'test@example.com',
          token: '123456',
        );
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull?.id, 'verified-id');
      },
    );

    test(
      'verifyOtp returns Result.error(AuthFailure) on invalid token',
      () async {
        fakeDataSource.throwAuthException = true;
        final result = await repository.verifyOtp(
          email: 'test@example.com',
          token: '000000',
        );
        expect(result.isError, isTrue);
        expect(result.failureOrNull, isA<AuthFailure>());
        expect(result.failureOrNull?.message, 'Token expired');
      },
    );
  });
}
