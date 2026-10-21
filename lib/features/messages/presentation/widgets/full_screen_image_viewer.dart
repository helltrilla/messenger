import 'dart:ui';
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

  /// Static helper to open the viewer with semi-transparent Telegram-style route
  static void open(
    BuildContext context, {
    required String imageUrl,
    required String heroTag,
    String? senderName,
    DateTime? createdAt,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(
            imageUrl: imageUrl,
            heroTag: heroTag,
            senderName: senderName,
            createdAt: createdAt,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  bool _showOverlays = true;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.05) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    if (_animationController.isAnimating) return;

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

  void _animateToScale(double targetScale) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final targetMatrix = Matrix4.identity();
    if (targetScale > 1.0) {
      final dx = cx * (1 - targetScale);
      final dy = cy * (1 - targetScale);
      targetMatrix
        ..translateByDouble(dx, dy, 0.0, 1.0)
        ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);
    }

    _animateToMatrix(targetMatrix);
  }

  void _handleDoubleTap(TapDownDetails details) {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = scale > 1.2 ? 1.0 : 2.5;

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

    _animateToMatrix(targetMatrix);
  }

  void _zoomIn() {
    final nextScale = (_currentScale + 0.5).clamp(1.0, 5.0);
    _animateToScale(nextScale);
  }

  void _zoomOut() {
    final nextScale = (_currentScale - 0.5).clamp(1.0, 5.0);
    _animateToScale(nextScale);
  }

  void _resetZoom() {
    _animateToScale(1.0);
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

    final scalePercent = (_currentScale * 100).round();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Semi-transparent frosted glass backdrop (like in Telegram)
          GestureDetector(
            onTap: _toggleOverlays,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withValues(alpha: 0.78)),
            ),
          ),

          // 2. Interactive Zoomable & Pannable Image
          GestureDetector(
            onTap: _toggleOverlays,
            onDoubleTapDown: _handleDoubleTap,
            onDoubleTap: () {},
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 5.0,
              panEnabled: true,
              scaleEnabled: true,
              // Reasonable boundary margin: tight at 1.0x, comfortable when zoomed
              boundaryMargin: _currentScale > 1.05
                  ? const EdgeInsets.all(40)
                  : const EdgeInsets.symmetric(horizontal: 0, vertical: 100),
              clipBehavior: Clip.none,
              onInteractionEnd: (details) {
                // If user dragged down or gave a quick flick at 1.0x scale, dismiss immediately
                final matrix = _transformationController.value;
                final scale = matrix.getMaxScaleOnAxis();
                final translationY = matrix.getTranslation().y;
                final velocityY = details.velocity.pixelsPerSecond.dy;

                if (scale <= 1.08) {
                  if (translationY > 45 ||
                      velocityY > 220 ||
                      translationY < -80 ||
                      velocityY < -300) {
                    Navigator.of(context).pop();
                    return;
                  }
                  if (translationY.abs() > 10) {
                    _resetZoom();
                  }
                }
              },
              child: Center(
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

          // 3. Top Header Bar
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
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Закрыть',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Floating Zoom Controls at the bottom
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showOverlays ? 32 : -100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24, width: 0.8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom Out Button
                    IconButton(
                      icon: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _currentScale > 1.05 ? _zoomOut : null,
                      disabledColor: Colors.white24,
                      tooltip: 'Уменьшить',
                    ),

                    // Scale Percentage & Reset Button
                    GestureDetector(
                      onTap: _resetZoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _currentScale > 1.05
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$scalePercent%',
                          style: TextStyle(
                            color: _currentScale > 1.05
                                ? AppColors.primary
                                : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    // Zoom In Button
                    IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _currentScale < 4.95 ? _zoomIn : null,
                      disabledColor: Colors.white24,
                      tooltip: 'Приблизить',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
