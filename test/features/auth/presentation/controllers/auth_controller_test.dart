import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/errors/failure.dart';
import 'package:messenger/core/errors/result.dart';
import 'package:messenger/features/auth/domain/entities/user_entity.dart';
import 'package:messenger/features/auth/domain/repositories/auth_repository.dart';
import 'package:messenger/features/auth/presentation/controllers/auth_controller.dart';
import 'package:messenger/features/auth/presentation/controllers/auth_providers.dart';

class MockAuthRepository implements AuthRepository {
  bool sendOtpSuccess = true;
  bool verifyOtpSuccess = true;

  @override
  UserEntity? get currentUser => null;

  @override
  Future<Result<Failure, void>> sendOtp({
    required String email,
    String? username,
    String? displayName,
  }) async {
    if (sendOtpSuccess) return Result.success(null);
    return Result.error(const AuthFailure(message: 'Failed to send OTP'));
  }

  @override
  Future<Result<Failure, UserEntity>> verifyOtp({
    required String email,
    required String token,
  }) async {
    if (verifyOtpSuccess) {
      return Result.success(
        UserEntity(
          id: 'user-abc',
          email: email,
          username: 'mockuser',
          displayName: 'Mock User',
        ),
      );
    }
    return Result.error(const AuthFailure(message: 'Invalid code'));
  }

  @override
  Future<Result<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<Result<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async => throw UnimplementedError();

  @override
  Future<Result<Failure, void>> signOut() async => Result.success(null);
}

void main() {
  late MockAuthRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(mockRepo)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthController OTP tests', () {
    test('sendOtp returns true and clears error on success', () async {
      final controller = container.read(authControllerProvider.notifier);
      final result = await controller.sendOtp(email: 'test@example.com');

      expect(result, isTrue);
      expect(container.read(authControllerProvider).hasError, isFalse);
    });

    test('sendOtp returns false and sets state error on failure', () async {
      mockRepo.sendOtpSuccess = false;
      final controller = container.read(authControllerProvider.notifier);
      final result = await controller.sendOtp(email: 'fail@example.com');

      expect(result, isFalse);
      expect(container.read(authControllerProvider).hasError, isTrue);
    });

    test(
      'verifyOtp returns true and sets UserEntity state on success',
      () async {
        final controller = container.read(authControllerProvider.notifier);
        final result = await controller.verifyOtp(
          email: 'test@example.com',
          token: '123456',
        );

        expect(result, isTrue);
        expect(container.read(authControllerProvider).value?.id, 'user-abc');
      },
    );

    test('verifyOtp returns false and sets state error on failure', () async {
      mockRepo.verifyOtpSuccess = false;
      final controller = container.read(authControllerProvider.notifier);
      final result = await controller.verifyOtp(
        email: 'test@example.com',
        token: '000000',
      );

      expect(result, isFalse);
      expect(container.read(authControllerProvider).hasError, isTrue);
    });
  });
}
