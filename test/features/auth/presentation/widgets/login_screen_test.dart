import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/errors/failure.dart';
import 'package:messenger/core/errors/result.dart';
import 'package:messenger/features/auth/domain/entities/user_entity.dart';
import 'package:messenger/features/auth/domain/repositories/auth_repository.dart';
import 'package:messenger/features/auth/presentation/controllers/auth_providers.dart';
import 'package:messenger/features/auth/presentation/login_screen.dart';

class MockAuthRepository implements AuthRepository {
  @override
  UserEntity? get currentUser => null;

  @override
  Future<Result<Failure, void>> sendOtp({
    required String email,
    String? username,
    String? displayName,
  }) async {
    return Result.success(null);
  }

  @override
  Future<Result<Failure, UserEntity>> verifyOtp({
    required String email,
    required String token,
  }) async {
    return Result.success(
      UserEntity(
        id: 'verified-id',
        email: email,
        username: 'test_user',
        displayName: 'Test User',
      ),
    );
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
  testWidgets('LoginScreen renders email input by default', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Вход в Telegram 2.0'), findsOneWidget);
    expect(find.text('Получить код'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets(
    'LoginScreen transitions to code verification when OTP is requested',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      // Enter valid email
      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.pump();

      // Tap "Получить код"
      await tester.tap(find.text('Получить код'));
      await tester.pumpAndSettle();

      // Should now show code verification screen
      expect(find.text('Код подтверждения'), findsOneWidget);
      expect(
        find.text(
          'Мы отправили 8-значный проверочный код на:\nuser@example.com',
        ),
        findsOneWidget,
      );
      expect(find.text('Подтвердить'), findsOneWidget);
      expect(find.byIcon(Icons.content_paste_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'LoginScreen allows resending code without Null check operator crash',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      // Enter valid email and request code
      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.pump();
      await tester.tap(find.text('Получить код'));
      await tester.pumpAndSettle();

      // Fast-forward countdown past 60s
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();

      // Tap "Отправить код повторно"
      expect(find.text('Отправить код повторно'), findsOneWidget);
      await tester.tap(find.text('Отправить код повторно'));
      await tester.pump();

      // Should succeed and show snackbar, without null check error
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );
}
