import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/message_entity.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String text) onSendText;
  final Function(Uint8List bytes, String fileName) onSendImage;
  final MessageEntity? editingMessage;
  final VoidCallback? onCancelEdit;
  final Function(String newText)? onConfirmEdit;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    this.editingMessage,
    this.onCancelEdit,
    this.onConfirmEdit,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasTextNow = _controller.text.trim().isNotEmpty;
      if (hasTextNow != _hasText) {
        setState(() => _hasText = hasTextNow);
      }
    });

    if (widget.editingMessage != null) {
      _controller.text = widget.editingMessage!.content ?? '';
    }
  }

  @override
  void didUpdateWidget(ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != null &&
        widget.editingMessage != oldWidget.editingMessage) {
      _controller.text = widget.editingMessage!.content ?? '';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    } else if (widget.editingMessage == null &&
        oldWidget.editingMessage != null) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (widget.editingMessage != null) {
      widget.onConfirmEdit?.call(text);
    } else {
      widget.onSendText(text);
    }
    _controller.clear();
  }

  void _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      widget.onSendImage(bytes, picked.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingMessage != null;

    return Container(
      color: AppColors.darkSurface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit message banner
          if (isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white12, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Редактирование',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          widget.editingMessage!.content ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      widget.onCancelEdit?.call();
                      _controller.clear();
                    },
                  ),
                ],
              ),
            ),

          // Main input row
          Padding(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 6,
              bottom: MediaQuery.of(context).padding.bottom + 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment Button (hidden when editing)
                if (!isEditing)
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file,
                      color: AppColors.textSecondaryDark,
                    ),
                    onPressed: _pickImage,
                  )
                else
                  const SizedBox(width: 6),

                // Text Field
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.darkBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: isEditing
                            ? 'Редактировать сообщение'
                            : 'Сообщение',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondaryDark,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Send / Confirm / Mic Button
                IconButton(
                  icon: Icon(
                    isEditing
                        ? Icons.check_rounded
                        : (_hasText ? Icons.send_rounded : Icons.mic_rounded),
                    color: AppColors.primary,
                  ),
                  onPressed: (isEditing || _hasText)
                      ? _submit
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Удерживайте для записи голосового сообщения',
                              ),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
