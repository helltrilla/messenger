import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/message_entity.dart';

class VideoCircleWidget extends StatefulWidget {
  final MessageEntity message;
  final bool isMine;
  final VoidCallback? onLongPress;
  final Widget? statusIndicator;

  const VideoCircleWidget({
    super.key,
    required this.message,
    required this.isMine,
    this.onLongPress,
    this.statusIndicator,
  });

  @override
  State<VideoCircleWidget> createState() => _VideoCircleWidgetState();
}

class _VideoCircleWidgetState extends State<VideoCircleWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(VideoCircleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.mediaUrl != oldWidget.message.mediaUrl) {
      _controller?.removeListener(_onControllerUpdate);
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _hasError = false;
      _isPlaying = false;
      _setupController();
    }
  }

  void _setupController() {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;

    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          controller.setLooping(true);
          controller.addListener(_onControllerUpdate);
          setState(() {
            _isInitialized = true;
            _duration = controller.value.duration;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() {
            _hasError = true;
          });
        });
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null) return;
    final val = _controller!.value;
    final playing = val.isPlaying;
    final pos = val.position;
    final dur = val.duration;

    if (playing != _isPlaying || pos != _position || dur != _duration) {
      setState(() {
        _isPlaying = playing;
        _position = pos;
        _duration = dur;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final mins = (totalSeconds ~/ 60).toString();
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    const double size = 220;
    final isMine = widget.isMine;
    final url = widget.message.mediaUrl;

    double progress = 0.0;
    if (_duration.inMilliseconds > 0) {
      progress = (_position.inMilliseconds / _duration.inMilliseconds).clamp(
        0.0,
        1.0,
      );
    }

    final displayDurationText = _isInitialized
        ? _formatDuration(_position.inSeconds > 0 ? _position : _duration)
        : (widget.message.durationSec != null
              ? _formatDuration(Duration(seconds: widget.message.durationSec!))
              : '0:00');

    return GestureDetector(
      onTap: _togglePlayPause,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.only(
          top: 4,
          bottom: widget.message.reactions.isEmpty ? 4 : 2,
          left: isMine ? 48 : 10,
          right: isMine ? 10 : 48,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circular Video / Placeholder
            ClipOval(
              child: Container(
                width: size,
                height: size,
                color: const Color(0xFF1C242F),
                child: _buildVideoContent(size, url),
              ),
            ),

            // Telegram-style Animated Circular Progress Ring
            if (_isInitialized)
              CustomPaint(
                size: const Size(size, size),
                painter: _CircleRingPainter(
                  progress: progress,
                  accentColor: AppColors.primary,
                  trackColor: Colors.white24,
                  strokeWidth: 3.5,
                ),
              ),

            // Play / Pause center overlay
            if (_isInitialized && !_isPlaying)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),

            // Bottom glass pill with Duration & Timestamp
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayDurationText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ChatDateFormatter.formatMessageTime(
                        widget.message.createdAt,
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    if (isMine && widget.statusIndicator != null) ...[
                      const SizedBox(width: 4),
                      widget.statusIndicator!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent(double size, String? url) {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 36,
            ),
            SizedBox(height: 6),
            Text(
              'Ошибка видео',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (url == null || url.isEmpty || !_isInitialized || _controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    final videoSize = _controller!.value.size;
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: videoSize.width > 0 ? videoSize.width : size,
          height: videoSize.height > 0 ? videoSize.height : size,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}

class _CircleRingPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final Color trackColor;
  final double strokeWidth;

  _CircleRingPainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircleRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
