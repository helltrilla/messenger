import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../chats/domain/entities/chat_entity.dart';
import '../../chats/presentation/controllers/chat_list_controller.dart';
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

  void _showMessageOptions(
    BuildContext context,
    MessageEntity message,
    ChatMessagesController controller,
  ) {
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

    final chats = ref.watch(chatListControllerProvider).value;
    final activeChat =
        chats?.where((c) => c.id == widget.chat.id).firstOrNull ?? widget.chat;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatListControllerProvider.notifier)
          .markChatLocallyRead(widget.chat.id);
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
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
                  const Text(
                    'в сети',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Container(
        // Subtle Telegram-style wallpaper background
        decoration: const BoxDecoration(color: Color(0xFF0F141C)),
        child: Column(
          children: [
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
                data: (messages) {
                  if (messages.isEmpty) {
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
                        child: const Text(
                          'Начните общение первым 👋',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true, // Newest messages at the bottom
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return MessageBubble(
                        message: message,
                        onLongPress: () =>
                            _showMessageOptions(context, message, controller),
                      );
                    },
                  );
                },
              ),
            ),

            // Input Bar
            ChatInputBar(
              editingMessage: _editingMessage,
              onCancelEdit: () => setState(() => _editingMessage = null),
              onConfirmEdit: (newText) {
                if (_editingMessage != null) {
                  controller.editMessage(_editingMessage!.id, newText);
                  setState(() => _editingMessage = null);
                }
              },
              onSendText: (text) => controller.sendTextMessage(text),
              onSendImage: (bytes, fileName) {
                const demoBlurhash = 'L6PZfSi_.AyE_3t7t7R**0o#DgR4';
                controller.sendImage(
                  bytes: bytes,
                  fileName: fileName,
                  blurhash: demoBlurhash,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
