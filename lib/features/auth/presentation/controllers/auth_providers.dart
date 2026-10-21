import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRemoteDataSourceImpl(client);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(dataSource);
});

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return SignInUseCase(repo);
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return SignUpUseCase(repo);
});

final sendOtpUseCaseProvider = Provider<SendOtpUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return SendOtpUseCase(repo);
});

final verifyOtpUseCaseProvider = Provider<VerifyOtpUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return VerifyOtpUseCase(repo);
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return SignOutUseCase(repo);
});
