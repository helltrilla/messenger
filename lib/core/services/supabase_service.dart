import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final isSupabaseInitializedProvider = Provider<bool>((ref) {
  try {
    Supabase.instance;
    return true;
  } catch (_) {
    return false;
  }
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final currentAuthUserProvider = Provider<User?>((ref) {
  final isInit = ref.watch(isSupabaseInitializedProvider);
  if (!isInit) return null;
  ref.watch(authStateChangesProvider);
  final client = ref.watch(supabaseClientProvider);
  return client.auth.currentUser;
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final isInit = ref.watch(isSupabaseInitializedProvider);
  if (!isInit) {
    return const Stream<AuthState>.empty();
  }
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});
