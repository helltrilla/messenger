import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../chats/presentation/controllers/chat_list_controller.dart';
import '../../../messages/presentation/controllers/chat_messages_controller.dart';
import '../../data/datasources/account_local_data_source.dart';
import '../../domain/entities/saved_account.dart';

final accountSwitcherControllerProvider =
    AsyncNotifierProvider<AccountSwitcherController, List<SavedAccount>>(() {
      return AccountSwitcherController();
    });

class AccountSwitcherController extends AsyncNotifier<List<SavedAccount>> {
  StreamSubscription<AuthState>? _authSub;

  @override
  FutureOr<List<SavedAccount>> build() async {
    final localSource = ref.watch(accountLocalDataSourceProvider);
    final accounts = await localSource.getSavedAccounts();

    final client = ref.watch(supabaseClientProvider);
    final session = client.auth.currentSession;

    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((data) {
      final s = data.session;
      if (s != null && s.refreshToken != null) {
        unawaited(_syncSessionToLocal(s));
      }
    });

    ref.onDispose(() {
      _authSub?.cancel();
    });

    if (session != null && session.refreshToken != null) {
      await _syncSessionToLocal(session);
      return localSource.getSavedAccounts();
    }

    return accounts;
  }

  Future<void> _syncSessionToLocal(Session session) async {
    final user = session.user;
    final meta = user.userMetadata ?? {};
    final email = user.email ?? '';
    final emailPrefix = email.contains('@')
        ? email.split('@').first
        : 'Пользователь';
    final displayName = meta['display_name'] as String? ?? emailPrefix;
    final username = meta['username'] as String? ?? emailPrefix;
    final avatarUrl = meta['avatar_url'] as String?;

    if (session.refreshToken == null) return;

    final account = SavedAccount(
      userId: user.id,
      email: email,
      displayName: displayName,
      username: username,
      avatarUrl: avatarUrl,
      refreshToken: session.refreshToken!,
    );

    final localSource = ref.read(accountLocalDataSourceProvider);
    await localSource.saveAccount(account);
  }

  Future<bool> switchToAccount(SavedAccount targetAccount) async {
    final client = ref.read(supabaseClientProvider);
    final currentUserId = client.auth.currentUser?.id;

    if (currentUserId == targetAccount.userId) {
      ref.invalidate(currentAuthUserProvider);
      ref.invalidate(chatListControllerProvider);
      ref.invalidate(chatMessagesControllerProvider);
      return true; // Already on this account
    }

    state = const AsyncValue.loading();
    try {
      // 1. Save current account's newest refresh token before switching
      final currentSession = client.auth.currentSession;
      if (currentSession != null && currentSession.refreshToken != null) {
        await _syncSessionToLocal(currentSession);
      }

      // 2. Switch session in Supabase
      final response = await client.auth.setSession(targetAccount.refreshToken);
      final newSession = response.session;
      if (newSession == null) {
        throw Exception(
          'Сессия для ${targetAccount.email} устарела. Пожалуйста, выполните вход повторно.',
        );
      }

      // 3. Update target account if Supabase returned a new refresh token
      if (newSession.refreshToken != null) {
        await _syncSessionToLocal(newSession);
      }

      // 4. Invalidate providers so UI instantly reflects the new user
      ref.invalidate(currentAuthUserProvider);
      ref.invalidate(chatListControllerProvider);
      ref.invalidate(chatMessagesControllerProvider);

      final updatedAccounts = await ref
          .read(accountLocalDataSourceProvider)
          .getSavedAccounts();
      state = AsyncValue.data(updatedAccounts);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      final accounts = await ref
          .read(accountLocalDataSourceProvider)
          .getSavedAccounts();
      state = AsyncValue.data(accounts);
      rethrow;
    }
  }

  Future<void> removeAccount(String userId) async {
    final localSource = ref.read(accountLocalDataSourceProvider);
    await localSource.removeAccount(userId);

    final client = ref.read(supabaseClientProvider);
    final isCurrent = client.auth.currentUser?.id == userId;

    ref.invalidate(chatMessagesControllerProvider);

    final remaining = await localSource.getSavedAccounts();
    state = AsyncValue.data(remaining);

    if (isCurrent) {
      if (remaining.isNotEmpty) {
        await switchToAccount(remaining.first);
      } else {
        await client.auth.signOut();
      }
    }
  }

  Future<void> saveCurrentAccount() async {
    final client = ref.read(supabaseClientProvider);
    final session = client.auth.currentSession;
    if (session != null && session.refreshToken != null) {
      await _syncSessionToLocal(session);
      final list = await ref
          .read(accountLocalDataSourceProvider)
          .getSavedAccounts();
      state = AsyncValue.data(list);
    }
  }
}
