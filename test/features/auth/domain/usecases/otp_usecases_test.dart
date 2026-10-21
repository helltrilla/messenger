import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/errors/failure.dart';
import 'package:messenger/core/errors/result.dart';
import 'package:messenger/features/auth/domain/entities/user_entity.dart';
import 'package:messenger/features/auth/domain/repositories/auth_repository.dart';
import 'package:messenger/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:messenger/features/auth/domain/usecases/verify_otp_usecase.dart';

class FakeAuthRepository implements AuthRepository {
  bool sendOtpSuccess = true;
  bool verifyOtpSuccess = true;
  String? lastEmailSent;
  String? lastTokenVerified;

  @override
  UserEntity? get currentUser => null;

  @override
  Future<Result<Failure, void>> sendOtp({
    required String email,
    String? username,
    String? displayName,
  }) async {
    lastEmailSent = email;
    if (sendOtpSuccess) {
      return Result.success(null);
    } else {
      return Result.error(const AuthFailure(message: 'Failed to send OTP'));
    }
  }

  @override
  Future<Result<Failure, UserEntity>> verifyOtp({
    required String email,
    required String token,
  }) async {
    lastEmailSent = email;
    lastTokenVerified = token;
    if (verifyOtpSuccess) {
      return Result.success(
        UserEntity(
          id: 'test-user-id',
          email: email,
          username: 'testuser',
          displayName: 'Test User',
        ),
      );
    } else {
      return Result.error(const AuthFailure(message: 'Invalid OTP code'));
    }
  }

  @override
  Future<Result<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<Failure, void>> signOut() async {
    return Result.success(null);
  }
}

void main() {
  late FakeAuthRepository fakeRepo;
  late SendOtpUseCase sendOtpUseCase;
  late VerifyOtpUseCase verifyOtpUseCase;

  setUp(() {
    fakeRepo = FakeAuthRepository();
    sendOtpUseCase = SendOtpUseCase(fakeRepo);
    verifyOtpUseCase = VerifyOtpUseCase(fakeRepo);
  });

  group('SendOtpUseCase tests', () {
    test('returns success when OTP is sent successfully', () async {
      final result = await sendOtpUseCase(
        email: 'test@example.com',
        username: 'telegram_user',
        displayName: 'Telegram User',
      );

      expect(result.isSuccess, isTrue);
      expect(fakeRepo.lastEmailSent, 'test@example.com');
    });

    test('returns failure when repository fails to send OTP', () async {
      fakeRepo.sendOtpSuccess = false;

      final result = await sendOtpUseCase(email: 'fail@example.com');

      expect(result.isError, isTrue);
      expect(result.failureOrNull?.message, 'Failed to send OTP');
    });
  });

  group('VerifyOtpUseCase tests', () {
    test('returns user entity when OTP verification succeeds', () async {
      final result = await verifyOtpUseCase(
        email: 'test@example.com',
        token: '12345678',
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.id, 'test-user-id');
      expect(result.dataOrNull?.email, 'test@example.com');
      expect(fakeRepo.lastTokenVerified, '12345678');
    });

    test('returns failure when OTP code is invalid', () async {
      fakeRepo.verifyOtpSuccess = false;

      final result = await verifyOtpUseCase(
        email: 'test@example.com',
        token: '000000',
      );

      expect(result.isError, isTrue);
      expect(result.failureOrNull?.message, 'Invalid OTP code');
    });
  });
}
