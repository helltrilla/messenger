import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_profile_entity.dart';
import 'chat_providers.dart';

final userSearchControllerProvider =
    AsyncNotifierProvider<UserSearchController, List<UserProfileEntity>>(() {
      return UserSearchController();
    });

class UserSearchController extends AsyncNotifier<List<UserProfileEntity>> {
  @override
  FutureOr<List<UserProfileEntity>> build() async {
    final searchUseCase = ref.watch(searchUsersUseCaseProvider);
    final result = await searchUseCase('');
    return result.when(success: (users) => users, error: (_) => []);
  }

  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    final searchUseCase = ref.read(searchUsersUseCaseProvider);
    final result = await searchUseCase(query.trim());

    result.when(
      success: (users) {
        state = AsyncValue.data(users);
      },
      error: (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
      },
    );
  }
}
