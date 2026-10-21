import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/chat_entity.dart';
import 'chat_providers.dart';

final chatListControllerProvider =
    AsyncNotifierProvider<ChatListController, List<ChatEntity>>(() {
      return ChatListController();
    });

class ChatListController extends AsyncNotifier<List<ChatEntity>> {
  RealtimeChannel? _subscription;

  @override
  FutureOr<List<ChatEntity>> build() async {
    final client = ref.watch(supabaseClientProvider);
    final currentUid = client.auth.currentUser?.id;

    // Initialize device notifications
    unawaited(ref.read(notificationServiceProvider).initialize());

    _subscription = client.channel('public:chats_and_messages_realtime');

    _subscription!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (payload) {
            ref.invalidateSelf();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_members',
          callback: (payload) {
            final record = payload.newRecord;
            if (record['user_id'] == currentUid) {
              ref.invalidateSelf();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newRow = payload.newRecord;
            final senderId = newRow['sender_id'] as String?;

            if (currentUid != null && senderId != currentUid) {
              ref.invalidateSelf();

              final content = newRow['content'] as String? ?? 'Новое сообщение';
              final chatId = newRow['chat_id'] as String? ?? '';
              final type = newRow['type'] as String? ?? 'text';
              final bodyText = type == 'image'
                  ? '📷 Фотография'
                  : type == 'voice'
                  ? '🎤 Голосовое сообщение'
                  : type == 'file'
                  ? '📎 Файл'
                  : content;

              final existingList = state.value ?? [];
              final matchChat = existingList
                  .where((c) => c.id == chatId)
                  .firstOrNull;
              final senderTitle = matchChat?.title ?? 'Новое сообщение';

              ref
                  .read(notificationServiceProvider)
                  .showMessageNotification(
                    id: chatId.hashCode,
                    senderName: senderTitle,
                    messageText: bodyText,
                    chatId: chatId,
                  );
            }
          },
        )
        .subscribe();

    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    final user = client.auth.currentUser;
    if (user != null) {
      final name =
          user.userMetadata?['display_name'] ??
          (user.email != null && user.email!.contains('@')
              ? user.email!.split('@').first
              : 'Пользователь');
      final username =
          user.userMetadata?['username'] ??
          (user.email != null && user.email!.contains('@')
              ? user.email!.split('@').first
              : 'user_${user.id.substring(0, 8)}');
      unawaited(
        client
            .from('profiles')
            .upsert({'id': user.id, 'display_name': name, 'username': username})
            .catchError((_) {}),
      );
    }

    final getChats = ref.watch(getChatsUseCaseProvider);
    final result = await getChats();

    return result.when(
      success: (chats) => chats,
      error: (failure) => throw failure,
    );
  }

  void markChatLocallyRead(String chatId) {
    final currentChats = state.value;
    if (currentChats == null) return;

    final updated = currentChats.map((chat) {
      if (chat.id == chatId) {
        return chat.copyWith(unreadCount: 0);
      }
      return chat;
    }).toList();

    state = AsyncValue.data(updated);
  }

  Future<void> loadChats() async {
    ref.invalidateSelf();
    await future;
  }

  Future<String> createDirectChat(String targetUserId) async {
    final createUseCase = ref.read(createDirectChatUseCaseProvider);
    final result = await createUseCase(targetUserId);

    return result.when(
      success: (chatId) {
        ref.invalidateSelf();
        return chatId;
      },
      error: (failure) => throw failure,
    );
  }
}
