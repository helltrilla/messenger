import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class VoicePlayerWidget extends StatefulWidget {
  final int durationSec;
  final bool isMine;

  const VoicePlayerWidget({
    super.key,
    required this.durationSec,
    required this.isMine,
  });

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget> {
  bool _isPlaying = false;
  double _progress = 0.0;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      final totalMs = (widget.durationSec * 1000) / _playbackSpeed;
      const intervalMs = 50;
      final step = intervalMs / totalMs;

      _playbackTimer = Timer.periodic(
        const Duration(milliseconds: intervalMs),
        (timer) {
          setState(() {
            _progress += step;
            if (_progress >= 1.0) {
              _progress = 0.0;
              _isPlaying = false;
              timer.cancel();
            }
          });
        },
      );
    }
  }

  void _toggleSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });

    if (_isPlaying) {
      _togglePlay();
      _togglePlay();
    }
  }

  String _formatTime(double progress) {
    final currentSec = (widget.durationSec * progress).floor();
    final remainingSec = widget.durationSec - currentSec;
    final mins = (remainingSec ~/ 60).toString().padLeft(2, '0');
    final secs = (remainingSec % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isMine ? AppColors.primary : Colors.white;
    final inactiveColor = Colors.white30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause Circle Button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isMine
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Waveform bars
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 28,
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      progress: _progress,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                    size: const Size(double.infinity, 28),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(_progress),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${_playbackSpeed.toStringAsFixed(_playbackSpeed == 1.5 ? 1 : 0)}X',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  static const List<double> _barHeights = [
    0.3,
    0.5,
    0.8,
    0.6,
    0.9,
    0.4,
    0.7,
    1.0,
    0.5,
    0.3,
    0.6,
    0.8,
    0.4,
    0.9,
    0.7,
    0.5,
    0.3,
    0.8,
    0.6,
    1.0,
    0.4,
    0.7,
    0.5,
    0.3,
  ];

  const _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _barHeights.length;
    final totalSpacing = size.width / barCount;
    final barWidth = totalSpacing * 0.55;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (int i = 0; i < barCount; i++) {
      final x = i * totalSpacing + barWidth / 2;
      final barHeight = size.height * _barHeights[i];
      final yTop = (size.height - barHeight) / 2;
      final yBottom = yTop + barHeight;

      final isBarActive = (i / barCount) <= progress;
      canvas.drawLine(
        Offset(x, yTop),
        Offset(x, yBottom),
        isBarActive ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor;
  }
}
