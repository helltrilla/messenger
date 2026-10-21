import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_entity.dart';
import 'auth_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserEntity?>(() {
      return AuthController();
    });

class AuthController extends AsyncNotifier<UserEntity?> {
  @override
  FutureOr<UserEntity?> build() {
    final repo = ref.watch(authRepositoryProvider);
    return repo.currentUser;
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    final useCase = ref.read(signInUseCaseProvider);
    final result = await useCase(email: email, password: password);

    return result.when(
      success: (user) {
        state = AsyncValue.data(user);
        return true;
      },
      error: (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    final useCase = ref.read(signUpUseCaseProvider);
    final result = await useCase(
      email: email,
      password: password,
      username: username,
      displayName: displayName,
    );

    return result.when(
      success: (user) {
        state = AsyncValue.data(user);
        return true;
      },
      error: (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> sendOtp({
    required String email,
    String? username,
    String? displayName,
  }) async {
    state = const AsyncValue.loading();
    final useCase = ref.read(sendOtpUseCaseProvider);
    final result = await useCase(
      email: email,
      username: username,
      displayName: displayName,
    );

    return result.when(
      success: (_) {
        state = const AsyncValue.data(null);
        return true;
      },
      error: (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> verifyOtp({required String email, required String token}) async {
    state = const AsyncValue.loading();
    final useCase = ref.read(verifyOtpUseCaseProvider);
    final result = await useCase(email: email, token: token);

    return result.when(
      success: (user) {
        state = AsyncValue.data(user);
        return true;
      },
      error: (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<void> signOut() async {
    final useCase = ref.read(signOutUseCaseProvider);
    await useCase();
    state = const AsyncValue.data(null);
  }
}
