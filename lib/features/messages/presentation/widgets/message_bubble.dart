import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/message_entity.dart';

class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final VoidCallback? onLongPress;

  const MessageBubble({super.key, required this.message, this.onLongPress});

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

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: EdgeInsets.only(
            top: 3,
            bottom: 3,
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
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 1),
                blurRadius: 2,
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
                // Media Content (Image with BlurHash)
                if (message.type == 'image') ...[
                  if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: CachedNetworkImage(
                        imageUrl: message.mediaUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => message.blurhash != null
                            ? BlurHash(hash: message.blurhash!)
                            : Container(color: Colors.black26),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white54,
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

                // Text Content & Timestamp
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
    );
  }
}
