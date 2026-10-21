import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/message_entity.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String text, {String? replyToId}) onSendText;
  final Function(int durationSec, {String? replyToId}) onSendVoice;
  final Function(Uint8List bytes, String fileName, {String? replyToId})
  onSendImage;
  final Function(
    Uint8List bytes,
    String fileName, {
    int? durationSec,
    String? replyToId,
  })?
  onSendVideo;
  final MessageEntity? editingMessage;
  final VoidCallback? onCancelEdit;
  final Function(String newText)? onConfirmEdit;
  final MessageEntity? replyingMessage;
  final VoidCallback? onCancelReply;
  final Function(bool isTyping)? onTypingChanged;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendVoice,
    required this.onSendImage,
    this.onSendVideo,
    this.editingMessage,
    this.onCancelEdit,
    this.onConfirmEdit,
    this.replyingMessage,
    this.onCancelReply,
    this.onTypingChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  bool _hasText = false;
  Timer? _typingTimer;

  // Voice and Video mode state
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _voiceTimer;
  bool _isVideoMode = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);

    if (widget.editingMessage != null) {
      _controller.text = widget.editingMessage!.content ?? '';
    }
  }

  void _onTextChanged() {
    final hasTextNow = _controller.text.trim().isNotEmpty;
    if (hasTextNow != _hasText) {
      setState(() => _hasText = hasTextNow);
    }

    if (hasTextNow) {
      widget.onTypingChanged?.call(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        widget.onTypingChanged?.call(false);
      });
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
    _typingTimer?.cancel();
    _voiceTimer?.cancel();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _typingTimer?.cancel();
    widget.onTypingChanged?.call(false);

    if (widget.editingMessage != null) {
      widget.onConfirmEdit?.call(text);
    } else {
      widget.onSendText(text, replyToId: widget.replyingMessage?.id);
      widget.onCancelReply?.call();
    }
    _controller.clear();
  }

  void _startVoiceRecording() {
    setState(() {
      _isRecordingVoice = true;
      _recordingSeconds = 0;
    });

    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
      });
    });
  }

  void _stopVoiceRecording({bool shouldSend = true}) {
    _voiceTimer?.cancel();
    final duration = _recordingSeconds;

    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });

    if (shouldSend && duration >= 1) {
      widget.onSendVoice(duration, replyToId: widget.replyingMessage?.id);
      widget.onCancelReply?.call();
    }
  }

  void _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      widget.onSendImage(
        bytes,
        picked.name,
        replyToId: widget.replyingMessage?.id,
      );
      widget.onCancelReply?.call();
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        widget.onSendVideo?.call(
          bytes,
          picked.name,
          replyToId: widget.replyingMessage?.id,
        );
        widget.onCancelReply?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка записи видео: $e')));
      }
    }
  }

  String _formatVoiceDuration(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingMessage != null;
    final isReplying = widget.replyingMessage != null;

    return Container(
      color: AppColors.darkSurface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Edit message banner
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

          // 2. Reply message banner
          if (isReplying && !isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white12, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.reply_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.replyingMessage!.isMine
                              ? 'В ответ себе'
                              : 'Ответ на сообщение',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          widget.replyingMessage!.type == 'image'
                              ? '📷 Фотография'
                              : widget.replyingMessage!.type == 'voice'
                              ? '🎤 Голосовое сообщение'
                              : (widget.replyingMessage!.content ?? ''),
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
                    onPressed: widget.onCancelReply,
                  ),
                ],
              ),
            ),

          // 3. Main input row or voice recording active row
          if (_isRecordingVoice)
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 8,
                top: 10,
                bottom: MediaQuery.of(context).padding.bottom + 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatVoiceDuration(_recordingSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Запись аудио...',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _stopVoiceRecording(shouldSend: false),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                    onPressed: () => _stopVoiceRecording(shouldSend: true),
                  ),
                ],
              ),
            )
          else
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: isEditing
                              ? 'Редактировать сообщение'
                              : (isReplying ? 'Ваш ответ...' : 'Сообщение'),
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

                  if (isEditing || _hasText)
                    IconButton(
                      icon: Icon(
                        isEditing ? Icons.check_rounded : Icons.send_rounded,
                        color: AppColors.primary,
                      ),
                      onPressed: _submit,
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isVideoMode = !_isVideoMode;
                        });
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isVideoMode
                                  ? 'Режим видеосообщения (кружочек). Удерживайте для съёмки.'
                                  : 'Режим аудио. Удерживайте для записи голосового.',
                            ),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onLongPress: () {
                        if (_isVideoMode) {
                          _pickVideo(ImageSource.camera);
                        } else {
                          _startVoiceRecording();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            _isVideoMode
                                ? Icons.videocam_rounded
                                : Icons.mic_rounded,
                            key: ValueKey<bool>(_isVideoMode),
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
