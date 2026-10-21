import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/chat_remote_data_source.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/create_direct_chat_usecase.dart';
import '../../domain/usecases/create_group_chat_usecase.dart';
import '../../domain/usecases/get_chats_usecase.dart';
import '../../domain/usecases/get_saved_chat_usecase.dart';
import '../../domain/usecases/mark_chat_as_read_usecase.dart';
import '../../domain/usecases/pin_message_usecase.dart';
import '../../domain/usecases/save_to_favorites_usecase.dart';
import '../../domain/usecases/search_users_usecase.dart';
import '../../domain/usecases/toggle_pin_chat_usecase.dart';

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ChatRemoteDataSourceImpl(client);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dataSource = ref.watch(chatRemoteDataSourceProvider);
  return ChatRepositoryImpl(dataSource);
});

final getChatsUseCaseProvider = Provider<GetChatsUseCase>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return GetChatsUseCase(repo);
});

final createDirectChatUseCaseProvider = Provider<CreateDirectChatUseCase>((
  ref,
) {
  final repo = ref.watch(chatRepositoryProvider);
  return CreateDirectChatUseCase(repo);
});

final createGroupChatUseCaseProvider = Provider<CreateGroupChatUseCase>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return CreateGroupChatUseCase(repo);
});

final searchUsersUseCaseProvider = Provider<SearchUsersUseCase>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return SearchUsersUseCase(repo);
});

final markChatAsReadUseCaseProvider = Provider<MarkChatAsReadUseCase>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return MarkChatAsReadUseCase(repo);
});

final togglePinChatUseCaseProvider = Provider<TogglePinChatUseCase>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return TogglePinChatUseCase(repo);
});

final pinMessageUseCaseProvider = Provider<PinMessageUseCase>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return PinMessageUseCase(repo);
});

final getSavedChatUseCaseProvider = Provider<GetSavedChatUseCase>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return GetSavedChatUseCase(repo);
});

final saveToFavoritesUseCaseProvider = Provider<SaveToFavoritesUseCase>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return SaveToFavoritesUseCase(repo);
});

class ActiveChatIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setActive(String? chatId) => state = chatId;
}

final activeChatIdProvider = NotifierProvider<ActiveChatIdNotifier, String?>(
  ActiveChatIdNotifier.new,
);
