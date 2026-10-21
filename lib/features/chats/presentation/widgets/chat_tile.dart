import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/chat_entity.dart';
import 'user_avatar.dart';

class ChatTile extends StatelessWidget {
  final ChatEntity chat;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = chat.unreadCount > 0;
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isMineLastMessage =
        chat.lastMessageSenderId != null &&
        chat.lastMessageSenderId == currentUid;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(
                  name: chat.title,
                  imageUrl: chat.avatarUrl,
                  radius: 27,
                ),
                if (chat.type == 'group')
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.group_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (chat.isPinned) ...[
                              const Icon(
                                Icons.push_pin_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                chat.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isMineLastMessage) ...[
                            Icon(
                              chat.isLastMessageRead
                                  ? Icons.done_all_rounded
                                  : Icons.check_rounded,
                              size: 15,
                              color: chat.isLastMessageRead
                                  ? AppColors.primary
                                  : AppColors.textSecondaryDark,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            ChatDateFormatter.formatChatListTime(
                              chat.lastMessageAt,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread
                                  ? AppColors.primary
                                  : AppColors.textSecondaryDark,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: hasUnread
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : AppColors.textSecondaryDark,
                            ),
                            children: [
                              if (isMineLastMessage) ...[
                                const TextSpan(
                                  text: 'Вы: ',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              TextSpan(
                                text: chat.lastMessageText ?? 'Нет сообщений',
                                style: chat.lastMessageText == null
                                    ? TextStyle(
                                        color: AppColors.textSecondaryDark
                                            .withValues(alpha: 0.5),
                                        fontStyle: FontStyle.italic,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (chat.isPinned && !hasUnread) ...[
                            const Icon(
                              Icons.push_pin_rounded,
                              size: 16,
                              color: Colors.white38,
                            ),
                          ],
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.unreadBadge,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.unreadBadge.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  chat.unreadCount > 99
                                      ? '99+'
                                      : '${chat.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
