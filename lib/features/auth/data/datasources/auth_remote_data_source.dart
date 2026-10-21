import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  UserModel? get currentUser;
  Future<UserModel> signIn({required String email, required String password});
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  });
  Future<void> sendOtp({
    required String email,
    String? username,
    String? displayName,
  });
  Future<UserModel> verifyOtp({required String email, required String token});
  Future<void> signOut();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSourceImpl(this._client);

  @override
  UserModel? get currentUser {
    final user = _client.auth.currentUser;
    return user != null ? UserModel.fromSupabaseUser(user) : null;
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) throw const AuthException('User is null after sign in');
    return UserModel.fromSupabaseUser(user);
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'display_name': displayName},
    );
    final user = response.user;
    if (user == null) throw const AuthException('User is null after sign up');
    return UserModel.fromSupabaseUser(user);
  }

  @override
  Future<void> sendOtp({
    required String email,
    String? username,
    String? displayName,
  }) async {
    final data = <String, dynamic>{};
    if (username != null && username.isNotEmpty) {
      data['username'] = username;
    }
    if (displayName != null && displayName.isNotEmpty) {
      data['display_name'] = displayName;
    }
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
      data: data.isNotEmpty ? data : null,
    );
  }

  @override
  Future<UserModel> verifyOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('User is null after OTP verification');
      }
      return UserModel.fromSupabaseUser(user);
    } on AuthException {
      try {
        final response = await _client.auth.verifyOTP(
          email: email,
          token: token,
          type: OtpType.signup,
        );
        final user = response.user;
        if (user != null) {
          return UserModel.fromSupabaseUser(user);
        }
      } catch (_) {
        // Fallback failed, rethrow original error
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
