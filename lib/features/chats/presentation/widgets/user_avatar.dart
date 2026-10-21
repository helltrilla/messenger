import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final bool isOnline;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 24,
    this.isOnline = false,
  });

  // Generate consistent Telegram-like gradient based on name hash
  List<Color> _getGradient(String text) {
    final colors = [
      [const Color(0xFFFF885E), const Color(0xFFFF5151)], // Red/Orange
      [const Color(0xFF67B26F), const Color(0xFF4ca2cd)], // Green/Cyan
      [const Color(0xFF2AABEE), const Color(0xFF229ED9)], // Telegram Blue
      [const Color(0xFFB372CE), const Color(0xFF7B2CBF)], // Purple
      [const Color(0xFFF39060), const Color(0xFFF3637E)], // Coral
      [const Color(0xFF3CA55C), const Color(0xFFB5AC49)], // Lime
    ];
    final hash = text.codeUnits.fold(0, (acc, item) => acc + item);
    return colors[hash % colors.length];
  }

  String _getInitials(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _getGradient(name);

    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: Colors.transparent,
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _getInitials(name),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: radius * 0.75,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _getInitials(name),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: radius * 0.75,
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: radius * 2,
                    height: radius * 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getInitials(name),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: radius * 0.75,
                      ),
                    ),
                  ),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: const Color(0xFF4DBC58),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0E1621), width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
