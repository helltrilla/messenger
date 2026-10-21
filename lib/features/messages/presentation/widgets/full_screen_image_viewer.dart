import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final String? senderName;
  final DateTime? createdAt;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.senderName,
    this.createdAt,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  bool _showOverlays = true;
  double _dragOffsetY = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_animationController.isAnimating) return;

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = currentScale > 1.2 ? 1.0 : 2.5;

    final targetMatrix = Matrix4.identity();
    if (targetScale > 1.0) {
      final position = details.localPosition;
      targetMatrix
        ..translateByDouble(
          -position.dx * (targetScale - 1),
          -position.dy * (targetScale - 1),
          0.0,
          1.0,
        )
        ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);
    }

    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: targetMatrix,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward(from: 0.0);
    _zoomAnimation!.addListener(() {
      _transformationController.value = _zoomAnimation!.value;
    });
  }

  void _toggleOverlays() {
    setState(() {
      _showOverlays = !_showOverlays;
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = widget.createdAt != null
        ? DateFormat(
            'd MMMM y, HH:mm',
            'ru',
          ).format(widget.createdAt!.toLocal())
        : null;

    final dragProgress = (_dragOffsetY.abs() / 250).clamp(0.0, 1.0);
    final backgroundOpacity = (1.0 - dragProgress).clamp(0.2, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: backgroundOpacity),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Zoomable & draggable image area
          GestureDetector(
            onTap: _toggleOverlays,
            onDoubleTapDown: _handleDoubleTap,
            onDoubleTap: () {},
            onVerticalDragStart: (_) {
              final scale = _transformationController.value.getMaxScaleOnAxis();
              if (scale <= 1.05) {
                _isDragging = true;
              }
            },
            onVerticalDragUpdate: (details) {
              if (_isDragging) {
                setState(() {
                  _dragOffsetY += details.delta.dy;
                });
              }
            },
            onVerticalDragEnd: (details) {
              if (_isDragging) {
                if (_dragOffsetY.abs() > 120 ||
                    details.primaryVelocity!.abs() > 600) {
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _dragOffsetY = 0.0;
                    _isDragging = false;
                  });
                }
              }
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffsetY),
              child: Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 4.5,
                  clipBehavior: Clip.none,
                  child: Hero(
                    tag: widget.heroTag,
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Не удалось загрузить фото',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top Header Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showOverlays ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Назад',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.senderName != null)
                              Text(
                                widget.senderName!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (formattedTime != null)
                              Text(
                                formattedTime,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
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
        ],
      ),
    );
  }
}
