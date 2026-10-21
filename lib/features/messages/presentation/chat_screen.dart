import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../chats/domain/entities/chat_entity.dart';
import '../../chats/presentation/controllers/chat_list_controller.dart';
import '../../chats/presentation/controllers/chat_providers.dart';
import '../../chats/presentation/widgets/user_avatar.dart';
import '../domain/entities/message_entity.dart';
import 'controllers/chat_messages_controller.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final ChatEntity chat;

  const ChatScreen({super.key, required this.chat});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  MessageEntity? _editingMessage;
  MessageEntity? _replyingMessage;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _highlightedMessageId;
  late final ActiveChatIdNotifier _activeChatNotifier;

  @override
  void initState() {
    super.initState();
    _activeChatNotifier = ref.read(activeChatIdProvider.notifier);
    Future(() {
      _activeChatNotifier.setActive(widget.chat.id);
      ref
          .read(chatListControllerProvider.notifier)
          .markChatLocallyRead(widget.chat.id);
    });
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      Future(() {
        _activeChatNotifier.setActive(widget.chat.id);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    Future(() {
      _activeChatNotifier.setActive(null);
    });
    super.dispose();
  }

  void _showMessageOptions(
    BuildContext context,
    MessageEntity message,
    ChatMessagesController controller,
    ChatEntity activeChat,
  ) {
    final isPinnedMessage = activeChat.pinnedMessageId == message.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Quick emoji reaction bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['👍', '❤️', '🔥', '😂', '😮', '😢'].map((emoji) {
                      final hasReacted = message.reactions.any(
                        (r) => r.emoji == emoji && r.hasReacted,
                      );
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          controller.toggleReaction(message.id, emoji);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: hasReacted
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : AppColors.darkBackground,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasReacted
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(color: AppColors.darkDivider, height: 16),

                // Reply
                ListTile(
                  leading: const Icon(
                    Icons.reply_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Ответить',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _replyingMessage = message;
                    });
                  },
                ),

                // Save to Favorites ("В Избранное")
                if (activeChat.type != 'saved')
                  ListTile(
                    leading: const Icon(
                      Icons.bookmark_add_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'В Избранное',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        final saveUseCase = ref.read(
                          saveToFavoritesUseCaseProvider,
                        );
                        final result = await saveUseCase(message);
                        result.when(
                          success: (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.darkSurface,
                                  content: const Row(
                                    children: [
                                      Icon(
                                        Icons.bookmark_added_rounded,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Сохранено в Избранное',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  action: SnackBarAction(
                                    label: 'Перейти',
                                    textColor: AppColors.primary,
                                    onPressed: () async {
                                      final res = await ref.read(
                                        getSavedChatUseCaseProvider,
                                      )();
                                      res.when(
                                        success: (savedChat) {
                                          if (context.mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ChatScreen(chat: savedChat),
                                              ),
                                            );
                                          }
                                        },
                                        error: (_) {},
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          error: (f) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Ошибка: ${f.message}')),
                              );
                            }
                          },
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                        }
                      }
                    },
                  ),

                // Pin / Unpin message
                ListTile(
                  leading: Icon(
                    isPinnedMessage
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    isPinnedMessage
                        ? 'Открепить сообщение'
                        : 'Закрепить сообщение',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller.pinMessage(isPinnedMessage ? null : message.id);
                  },
                ),

                // Copy text
                if (message.content != null && message.content!.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Копировать текст',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: message.content!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Текст скопирован'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),

                // Edit
                if (message.isMine && message.type == 'text')
                  ListTile(
                    leading: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Редактировать',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _editingMessage = message;
                      });
                    },
                  ),

                // Delete
                if (message.isMine)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      'Удалить для всех',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context, message, controller);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    MessageEntity message,
    ChatMessagesController controller,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text(
          'Удалить сообщение?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Это сообщение будет удалено для всех участников беседы.',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (_editingMessage?.id == message.id) {
                setState(() => _editingMessage = null);
              }
              controller.deleteMessage(message.id, mediaUrl: message.mediaUrl);
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(
      chatMessagesControllerProvider(widget.chat.id),
    );
    final controller = ref.read(
      chatMessagesControllerProvider(widget.chat.id).notifier,
    );
    final isPartnerTyping = ref.watch(partnerTypingProvider(widget.chat.id));

    final chats = ref.watch(chatListControllerProvider).value;
    final activeChat =
        chats?.where((c) => c.id == widget.chat.id).firstOrNull ?? widget.chat;

    final messages = messagesState.value ?? [];
    final pinnedMsg = activeChat.pinnedMessageId != null
        ? messages.where((m) => m.id == activeChat.pinnedMessageId).firstOrNull
        : null;

    final displayMessages = _searchQuery.isEmpty
        ? messages
        : messages.where((m) {
            final content = m.content?.toLowerCase() ?? '';
            return content.contains(_searchQuery.toLowerCase());
          }).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Поиск сообщений...',
                  hintStyle: TextStyle(color: AppColors.textSecondaryDark),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              )
            : Row(
                children: [
                  UserAvatar(
                    name: activeChat.title,
                    imageUrl: activeChat.avatarUrl,
                    radius: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeChat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          isPartnerTyping
                              ? 'печатает...'
                              : (activeChat.type == 'saved'
                                    ? 'сохраненные сообщения'
                                    : (activeChat.type == 'group'
                                          ? 'группа'
                                          : 'в сети')),
                          style: TextStyle(
                            fontSize: 12,
                            color: isPartnerTyping
                                ? AppColors.primary
                                : (activeChat.type == 'group' ||
                                          activeChat.type == 'saved'
                                      ? AppColors.textSecondaryDark
                                      : AppColors.primary),
                            fontWeight: isPartnerTyping
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _isSearching = true),
            ),
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
          ],
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF0F141C)),
        child: Column(
          children: [
            // Pinned message banner
            if (activeChat.pinnedMessageId != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                color: AppColors.darkSurface,
                child: Row(
                  children: [
                    const Icon(
                      Icons.push_pin_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (pinnedMsg != null) {
                            setState(() {
                              _highlightedMessageId = pinnedMsg.id;
                            });
                            Timer(const Duration(seconds: 2), () {
                              if (mounted) {
                                setState(() => _highlightedMessageId = null);
                              }
                            });
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Закреплённое сообщение',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              pinnedMsg?.content ??
                                  (pinnedMsg?.type == 'image'
                                      ? '📷 Фотография'
                                      : pinnedMsg?.type == 'voice'
                                      ? '🎤 Голосовое сообщение'
                                      : 'Сообщение'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white60,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => controller.pinMessage(null),
                    ),
                  ],
                ),
              ),

            // Messages List
            Expanded(
              child: messagesState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 40,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ошибка: $err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(
                            chatMessagesControllerProvider(widget.chat.id),
                          ),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (_) {
                  if (displayMessages.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Сообщений не найдено'
                              : 'Начните общение первым 👋',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: displayMessages.length,
                    itemBuilder: (context, index) {
                      final message = displayMessages[index];
                      return MessageBubble(
                        message: message,
                        showSenderName: activeChat.type == 'group',
                        isHighlighted:
                            _highlightedMessageId == message.id ||
                            (_searchQuery.isNotEmpty &&
                                (message.content?.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ) ??
                                    false)),
                        onToggleReaction: (emoji) =>
                            controller.toggleReaction(message.id, emoji),
                        onReplyTap: () {
                          if (message.replyToId != null) {
                            setState(() {
                              _highlightedMessageId = message.replyToId;
                            });
                            Timer(const Duration(seconds: 2), () {
                              if (mounted) {
                                setState(() => _highlightedMessageId = null);
                              }
                            });
                          }
                        },
                        onLongPress: () => _showMessageOptions(
                          context,
                          message,
                          controller,
                          activeChat,
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Input Bar
            ChatInputBar(
              editingMessage: _editingMessage,
              replyingMessage: _replyingMessage,
              onCancelEdit: () => setState(() => _editingMessage = null),
              onCancelReply: () => setState(() => _replyingMessage = null),
              onTypingChanged: (isTyping) => controller.setTyping(isTyping),
              onConfirmEdit: (newText) {
                if (_editingMessage != null) {
                  controller.editMessage(_editingMessage!.id, newText);
                  setState(() => _editingMessage = null);
                }
              },
              onSendText: (text, {replyToId}) {
                controller.sendTextMessage(
                  text,
                  replyToId: replyToId,
                  replyToContent: _replyingMessage?.content,
                  replyToSenderName: _replyingMessage?.senderName,
                );
                setState(() => _replyingMessage = null);
              },
              onSendVoice: (durationSec, {replyToId}) {
                controller.sendVoiceMessage(
                  durationSec,
                  replyToId: replyToId,
                  replyToContent: _replyingMessage?.content,
                  replyToSenderName: _replyingMessage?.senderName,
                );
                setState(() => _replyingMessage = null);
              },
              onSendImage: (bytes, fileName, {replyToId}) {
                const demoBlurhash = 'L6PZfSi_.AyE_3t7t7R**0o#DgR4';
                controller.sendImage(
                  bytes: bytes,
                  fileName: fileName,
                  blurhash: demoBlurhash,
                  replyToId: replyToId,
                );
                setState(() => _replyingMessage = null);
              },
              onSendVideo: (bytes, fileName, {durationSec, replyToId}) {
                controller.sendVideo(
                  bytes: bytes,
                  fileName: fileName,
                  durationSec: durationSec,
                  replyToId: replyToId,
                );
                setState(() => _replyingMessage = null);
              },
            ),
          ],
        ),
      ),
    );
  }
}
