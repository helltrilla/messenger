import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../chats/presentation/controllers/chat_list_controller.dart';
import '../../../chats/presentation/controllers/chat_providers.dart';
import '../../data/models/message_model.dart';
import '../../domain/entities/message_entity.dart';
import 'message_providers.dart';

final chatMessagesControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChatMessagesController, List<MessageEntity>, String>(
      (arg) => ChatMessagesController(arg),
    );

class ChatMessagesController extends AsyncNotifier<List<MessageEntity>> {
  final String chatId;
  RealtimeChannel? _messagesChannel;
  final _uuid = const Uuid();

  ChatMessagesController(this.chatId);

  @override
  FutureOr<List<MessageEntity>> build() async {
    final client = ref.watch(supabaseClientProvider);

    _messagesChannel = client
        .channel('chat_messages:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            final activeUid = ref
                .read(supabaseClientProvider)
                .auth
                .currentUser
                ?.id;
            if (activeUid == null) return;

            final incomingMessage = MessageModel.fromMap(newRow, activeUid);

            if (!incomingMessage.isMine) {
              final currentList = state.value ?? [];
              if (!currentList.any((m) => m.id == incomingMessage.id)) {
                state = AsyncValue.data([incomingMessage, ...currentList]);
                unawaited(
                  ref.read(markChatAsReadUseCaseProvider)(
                    chatId: chatId,
                    messageId: incomingMessage.id,
                  ),
                );
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            final updatedRow = payload.newRecord;
            final updatedId = updatedRow['id'];
            if (updatedId == null) return;

            final isRead = updatedRow['is_read'] == true;
            final newContent = updatedRow['content'] as String?;
            final isEdited = updatedRow['is_edited'] == true;

            final currentList = state.value ?? [];
            final newList = currentList.map((m) {
              if (m.id == updatedId) {
                final status = (m.isMine && isRead)
                    ? MessageStatus.read
                    : m.status;
                return m.copyWith(
                  content: newContent ?? m.content,
                  isEdited: isEdited,
                  status: status,
                );
              }
              return m;
            }).toList();
            state = AsyncValue.data(newList);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final deletedId = payload.oldRecord['id'];
            if (deletedId != null) {
              final currentList = state.value ?? [];
              state = AsyncValue.data(
                currentList.where((m) => m.id != deletedId).toList(),
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final memberUserId = record['user_id'];
            final currentUid = ref
                .read(supabaseClientProvider)
                .auth
                .currentUser
                ?.id;

            if (memberUserId != null && memberUserId != currentUid) {
              final unread = record['unread_count'] as int? ?? 0;
              if (unread == 0) {
                final currentList = state.value ?? [];
                final hasUnreadOutgoing = currentList.any(
                  (m) => m.isMine && m.status != MessageStatus.read,
                );
                if (hasUnreadOutgoing) {
                  final newList = currentList.map((m) {
                    if (m.isMine && m.status != MessageStatus.read) {
                      return m.copyWith(status: MessageStatus.read);
                    }
                    return m;
                  }).toList();
                  state = AsyncValue.data(newList);
                }
              }
            }
          },
        )
        .subscribe();

    ref.onDispose(() {
      _messagesChannel?.unsubscribe();
    });

    final getMessages = ref.watch(getMessagesUseCaseProvider);
    final result = await getMessages(chatId: chatId);

    return result.when(
      success: (messages) {
        if (messages.isNotEmpty) {
          unawaited(
            ref.read(markChatAsReadUseCaseProvider)(
              chatId: chatId,
              messageId: messages.first.id,
            ),
          );
        }
        return messages;
      },
      error: (failure) => throw failure,
    );
  }

  // --- OPTIMISTIC UI SENDING ---
  Future<void> sendTextMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final tempId = _uuid.v4();
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id ?? '';

    // 1. Instantly display in UI with 'pending' status
    final optimisticMessage = MessageEntity(
      id: tempId,
      chatId: chatId,
      senderId: uid,
      content: trimmed,
      type: 'text',
      createdAt: DateTime.now(),
      isMine: true,
      status: MessageStatus.pending,
    );

    final currentMessages = state.value ?? [];
    state = AsyncValue.data([optimisticMessage, ...currentMessages]);

    // 2. Send via UseCase
    final sendUseCase = ref.read(sendMessageUseCaseProvider);
    final result = await sendUseCase(
      chatId: chatId,
      content: trimmed,
      type: 'text',
    );

    result.when(
      success: (serverMessage) {
        final updatedList = (state.value ?? []).map((m) {
          if (m.id == tempId) {
            return serverMessage.copyWith(status: MessageStatus.sent);
          }
          return m;
        }).toList();
        state = AsyncValue.data(updatedList);
      },
      error: (failure) {
        final failedList = (state.value ?? []).map((m) {
          if (m.id == tempId) {
            return m.copyWith(status: MessageStatus.failed);
          }
          return m;
        }).toList();
        state = AsyncValue.data(failedList);
      },
    );
  }

  // --- SEND IMAGE WITH BLURHASH ---
  Future<void> sendImage({
    required Uint8List bytes,
    required String fileName,
    String? blurhash,
  }) async {
    final tempId = _uuid.v4();
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id ?? '';

    final optimisticMessage = MessageEntity(
      id: tempId,
      chatId: chatId,
      senderId: uid,
      type: 'image',
      blurhash: blurhash,
      createdAt: DateTime.now(),
      isMine: true,
      status: MessageStatus.pending,
    );

    state = AsyncValue.data([optimisticMessage, ...(state.value ?? [])]);

    final uploadUseCase = ref.read(uploadMediaUseCaseProvider);
    final sendUseCase = ref.read(sendMessageUseCaseProvider);

    final uploadResult = await uploadUseCase(bytes: bytes, fileName: fileName);

    await uploadResult.when(
      success: (publicUrl) async {
        final sendResult = await sendUseCase(
          chatId: chatId,
          type: 'image',
          mediaUrl: publicUrl,
          blurhash: blurhash,
        );

        sendResult.when(
          success: (serverMessage) {
            final updatedList = (state.value ?? []).map((m) {
              if (m.id == tempId) {
                return serverMessage.copyWith(status: MessageStatus.sent);
              }
              return m;
            }).toList();
            state = AsyncValue.data(updatedList);
          },
          error: (failure) {
            final failedList = (state.value ?? []).map((m) {
              if (m.id == tempId) {
                return m.copyWith(status: MessageStatus.failed);
              }
              return m;
            }).toList();
            state = AsyncValue.data(failedList);
          },
        );
      },
      error: (failure) async {
        final failedList = (state.value ?? []).map((m) {
          if (m.id == tempId) {
            return m.copyWith(status: MessageStatus.failed);
          }
          return m;
        }).toList();
        state = AsyncValue.data(failedList);
      },
    );
  }

  // --- EDIT MESSAGE ---
  Future<void> editMessage(String messageId, String newText) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    final currentMessages = state.value ?? [];
    final originalIndex = currentMessages.indexWhere((m) => m.id == messageId);
    if (originalIndex == -1) return;
    final originalMessage = currentMessages[originalIndex];

    // Optimistic update
    final updatedList = currentMessages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(content: trimmed, isEdited: true);
      }
      return m;
    }).toList();
    state = AsyncValue.data(updatedList);

    final editUseCase = ref.read(editMessageUseCaseProvider);
    final result = await editUseCase(
      messageId: messageId,
      chatId: chatId,
      newContent: trimmed,
    );

    result.when(
      success: (_) {
        unawaited(ref.read(chatListControllerProvider.notifier).loadChats());
      },
      error: (failure) {
        // Rollback on failure
        final rolledBack = (state.value ?? []).map((m) {
          if (m.id == messageId) {
            return originalMessage;
          }
          return m;
        }).toList();
        state = AsyncValue.data(rolledBack);
      },
    );
  }

  // --- DELETE MESSAGE ---
  Future<void> deleteMessage(String messageId, {String? mediaUrl}) async {
    final currentMessages = state.value ?? [];
    final originalIndex = currentMessages.indexWhere((m) => m.id == messageId);
    if (originalIndex == -1) return;
    final messageToDelete = currentMessages[originalIndex];

    // Optimistic deletion
    final filteredList = currentMessages
        .where((m) => m.id != messageId)
        .toList();
    state = AsyncValue.data(filteredList);

    final deleteUseCase = ref.read(deleteMessageUseCaseProvider);
    final result = await deleteUseCase(
      messageId: messageId,
      chatId: chatId,
      mediaUrl: mediaUrl,
    );

    result.when(
      success: (_) {
        unawaited(ref.read(chatListControllerProvider.notifier).loadChats());
      },
      error: (failure) {
        // Revert on failure
        state = AsyncValue.data([messageToDelete, ...filteredList]);
      },
    );
  }
}
