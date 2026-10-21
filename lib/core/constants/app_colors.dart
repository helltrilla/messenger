import 'package:flutter/material.dart';

class AppColors {
  // Telegram Brand & Accents
  static const Color primary = Color(0xFF2AABEE); // Telegram Blue
  static const Color primaryDark = Color(0xFF229ED9);
  static const Color accent = Color(0xFF50B5FF);

  // Dark Theme (Telegram Dark Theme Palette)
  static const Color darkBackground = Color(
    0xFF0E1621,
  ); // Main chat list / screen bg
  static const Color darkSurface = Color(
    0xFF17212B,
  ); // App bars, search, dialogs
  static const Color darkCard = Color(0xFF242F3D); // Highlighted cards
  static const Color darkDivider = Color(0xFF101921);

  // Message Bubbles (Dark)
  static const Color darkOutgoingBubble = Color(
    0xFF2B5278,
  ); // Telegram deep blue bubble
  static const Color darkIncomingBubble = Color(
    0xFF182533,
  ); // Telegram dark grey bubble

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF707579);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFF7E8B99);

  // Ticks & Badges
  static const Color readTick = Color(0xFF4FA0E8);
  static const Color unreadBadge = Color(0xFF2AABEE);
  static const Color onlineGreen = Color(0xFF4DBC58);
}
