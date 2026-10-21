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

class PartnerTypingNotifier extends Notifier<bool> {
  final String chatId;
  PartnerTypingNotifier(this.chatId);

  @override
  bool build() => false;

  void setTyping(bool value) => state = value;
}

final partnerTypingProvider = NotifierProvider.autoDispose
    .family<PartnerTypingNotifier, bool, String>(
      (chatId) => PartnerTypingNotifier(chatId),
    );

class ChatMessagesController extends AsyncNotifier<List<MessageEntity>> {
  final String chatId;
  RealtimeChannel? _messagesChannel;
  final _uuid = const Uuid();
  Timer? _typingDebounceTimer;

  ChatMessagesController(this.chatId);

  @override
  FutureOr<List<MessageEntity>> build() async {
    final client = ref.watch(supabaseClientProvider);
    final activeUid = client.auth.currentUser?.id;

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
          table: 'typing_indicators',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final typingUid = record['user_id'];
            if (typingUid != null && typingUid != activeUid) {
              final isTyping = record['is_typing'] == true;
              ref
                  .read(partnerTypingProvider(chatId).notifier)
                  .setTyping(isTyping);

              if (isTyping) {
                _typingDebounceTimer?.cancel();
                _typingDebounceTimer = Timer(const Duration(seconds: 4), () {
                  ref
                      .read(partnerTypingProvider(chatId).notifier)
                      .setTyping(false);
                });
              }
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
      _typingDebounceTimer?.cancel();
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

  // --- SEND TEXT MESSAGE ---
  Future<void> sendTextMessage(
    String text, {
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final tempId = _uuid.v4();
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id ?? '';

    final optimisticMessage = MessageEntity(
      id: tempId,
      chatId: chatId,
      senderId: uid,
      content: trimmed,
      type: 'text',
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      createdAt: DateTime.now(),
      isMine: true,
      status: MessageStatus.pending,
    );

    state = AsyncValue.data([optimisticMessage, ...(state.value ?? [])]);

    final sendUseCase = ref.read(sendMessageUseCaseProvider);
    final result = await sendUseCase(
      chatId: chatId,
      content: trimmed,
      type: 'text',
      replyToId: replyToId,
    );

    result.when(
      success: (serverMessage) {
        final updatedList = (state.value ?? []).map((m) {
          if (m.id == tempId) {
            return serverMessage.copyWith(
              status: MessageStatus.sent,
              replyToContent: replyToContent,
              replyToSenderName: replyToSenderName,
            );
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

  // --- SEND VOICE MESSAGE ---
  Future<void> sendVoiceMessage(
    int durationSec, {
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    final tempId = _uuid.v4();
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id ?? '';

    final optimisticMessage = MessageEntity(
      id: tempId,
      chatId: chatId,
      senderId: uid,
      content: 'Голосовое сообщение ($durationSec сек.)',
      type: 'voice',
      durationSec: durationSec,
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      createdAt: DateTime.now(),
      isMine: true,
      status: MessageStatus.pending,
    );

    state = AsyncValue.data([optimisticMessage, ...(state.value ?? [])]);

    final sendUseCase = ref.read(sendMessageUseCaseProvider);
    final result = await sendUseCase(
      chatId: chatId,
      content: 'Голосовое сообщение',
      type: 'voice',
      durationSec: durationSec,
      replyToId: replyToId,
    );

    result.when(
      success: (serverMessage) {
        final updatedList = (state.value ?? []).map((m) {
          if (m.id == tempId) {
            return serverMessage.copyWith(
              status: MessageStatus.sent,
              replyToContent: replyToContent,
              replyToSenderName: replyToSenderName,
            );
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

  // --- SEND IMAGE ---
  Future<void> sendImage({
    required Uint8List bytes,
    required String fileName,
    String? blurhash,
    String? replyToId,
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
      replyToId: replyToId,
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
          replyToId: replyToId,
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

  // --- TOGGLE REACTION ---
  Future<void> toggleReaction(String messageId, String emoji) async {
    final client = ref.read(supabaseClientProvider);
    final currentUid = client.auth.currentUser?.id;
    if (currentUid == null) return;

    final currentMessages = state.value ?? [];
    final updatedList = currentMessages.map((m) {
      if (m.id == messageId) {
        final existingReactions = List<ReactionEntity>.from(m.reactions);
        final reactionIndex = existingReactions.indexWhere(
          (r) => r.emoji == emoji,
        );

        if (reactionIndex != -1) {
          final current = existingReactions[reactionIndex];
          if (current.hasReacted) {
            if (current.count <= 1) {
              existingReactions.removeAt(reactionIndex);
            } else {
              existingReactions[reactionIndex] = current.copyWith(
                count: current.count - 1,
                hasReacted: false,
                userIds: current.userIds.where((u) => u != currentUid).toList(),
              );
            }
          } else {
            existingReactions[reactionIndex] = current.copyWith(
              count: current.count + 1,
              hasReacted: true,
              userIds: [...current.userIds, currentUid],
            );
          }
        } else {
          existingReactions.add(
            ReactionEntity(
              emoji: emoji,
              count: 1,
              hasReacted: true,
              userIds: [currentUid],
            ),
          );
        }
        return m.copyWith(reactions: existingReactions);
      }
      return m;
    }).toList();

    state = AsyncValue.data(updatedList);

    final toggleUseCase = ref.read(toggleReactionUseCaseProvider);
    await toggleUseCase(messageId: messageId, emoji: emoji);
  }

  // --- SET TYPING ---
  Future<void> setTyping(bool isTyping) async {
    final setTypingUseCase = ref.read(setTypingUseCaseProvider);
    await setTypingUseCase(chatId: chatId, isTyping: isTyping);
  }

  // --- EDIT MESSAGE ---
  Future<void> editMessage(String messageId, String newText) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    final currentMessages = state.value ?? [];
    final originalIndex = currentMessages.indexWhere((m) => m.id == messageId);
    if (originalIndex == -1) return;
    final originalMessage = currentMessages[originalIndex];

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
        state = AsyncValue.data([messageToDelete, ...filteredList]);
      },
    );
  }

  // --- PIN MESSAGE ---
  Future<void> pinMessage(String? messageId) async {
    final pinUseCase = ref.read(pinMessageUseCaseProvider);
    await pinUseCase(chatId: chatId, messageId: messageId);
    unawaited(ref.read(chatListControllerProvider.notifier).loadChats());
  }
}
