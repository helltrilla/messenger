import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/message_entity.dart';
import 'full_screen_image_viewer.dart';
import 'voice_player_widget.dart';

class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final VoidCallback? onLongPress;
  final Function(String emoji)? onToggleReaction;
  final VoidCallback? onReplyTap;
  final bool showSenderName;
  final bool isHighlighted;

  const MessageBubble({
    super.key,
    required this.message,
    this.onLongPress,
    this.onToggleReaction,
    this.onReplyTap,
    this.showSenderName = false,
    this.isHighlighted = false,
  });

  Widget _buildStatusIndicator() {
    switch (message.status) {
      case MessageStatus.pending:
        return const Icon(
          Icons.access_time_rounded,
          size: 13,
          color: Colors.white60,
        );
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded, size: 15, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(
          Icons.done_all_rounded,
          size: 16,
          color: AppColors.readTick,
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: Colors.redAccent,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final bubbleColor = isMine
        ? AppColors.darkOutgoingBubble
        : AppColors.darkIncomingBubble;

    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: onLongPress,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.only(
                top: 3,
                bottom: message.reactions.isEmpty ? 3 : 1,
                left: isMine ? 48 : 10,
                right: isMine ? 10 : 48,
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isHighlighted
                    ? Border.all(color: Colors.amberAccent, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isHighlighted
                        ? Colors.amber.withValues(alpha: 0.3)
                        : Colors.black12,
                    offset: const Offset(0, 1),
                    blurRadius: isHighlighted ? 6 : 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Group sender name
                    if (showSenderName && message.senderName != null && !isMine)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          top: 8,
                          right: 12,
                        ),
                        child: Text(
                          message.senderName!,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    // Quoted reply preview block
                    if (message.replyToContent != null)
                      GestureDetector(
                        onTap: onReplyTap,
                        child: Container(
                          margin: const EdgeInsets.only(
                            left: 10,
                            right: 10,
                            top: 8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(6),
                            border: const Border(
                              left: BorderSide(
                                color: AppColors.primary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message.replyToSenderName ?? 'В ответ',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                message.replyToContent!,
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

                    // Media Content (Image)
                    if (message.type == 'image') ...[
                      if (message.mediaUrl != null &&
                          message.mediaUrl!.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FullScreenImageViewer(
                                  imageUrl: message.mediaUrl!,
                                  heroTag: 'msg_img_${message.id}',
                                  senderName:
                                      message.senderName ??
                                      (isMine ? 'Вы' : null),
                                  createdAt: message.createdAt,
                                ),
                              ),
                            );
                          },
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Hero(
                              tag: 'msg_img_${message.id}',
                              child: CachedNetworkImage(
                                imageUrl: message.mediaUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    message.blurhash != null
                                    ? BlurHash(hash: message.blurhash!)
                                    : Container(color: Colors.black26),
                                errorWidget: (context, url, error) =>
                                    const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.white54,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        )
                      else if (message.blurhash != null)
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: BlurHash(hash: message.blurhash!),
                        )
                      else
                        Container(
                          height: 180,
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                    ],

                    // Voice Message
                    if (message.type == 'voice')
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: VoicePlayerWidget(
                          durationSec: message.durationSec ?? 5,
                          isMine: isMine,
                        ),
                      ),

                    // Text Content & Timestamp
                    if (message.type != 'voice')
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (message.content != null &&
                                message.content!.isNotEmpty)
                              Text(
                                message.content!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.25,
                                ),
                              ),
                            // Bottom-right timestamp, edited badge & tick
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.isEdited) ...[
                                  const Text(
                                    'ред. ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                                Text(
                                  ChatDateFormatter.formatMessageTime(
                                    message.createdAt,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                ),
                                if (isMine) ...[
                                  const SizedBox(width: 4),
                                  _buildStatusIndicator(),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Reaction chips
        if (message.reactions.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              left: isMine ? 48 : 10,
              right: isMine ? 10 : 48,
              top: 2,
              bottom: 4,
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: message.reactions.map((r) {
                return GestureDetector(
                  onTap: () => onToggleReaction?.call(r.emoji),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: r.hasReacted
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.darkSurface,
                      border: Border.all(
                        color: r.hasReacted
                            ? AppColors.primary
                            : Colors.white12,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          '${r.count}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: r.hasReacted
                                ? AppColors.primary
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
