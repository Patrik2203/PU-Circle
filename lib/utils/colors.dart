import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF4A90E2); // Main brand color
  static const Color primaryLight = Color(0xFF71B2FF);
  static const Color primaryDark = Color(0xFF3A6CB0);

  // Accent colors for highlights and call-to-action elements
  static const Color accent = Color(0xFFFFA500); // Orange accent
  static const Color accentLight = Color(0xFFFFCA7A);
  static const Color accentDark = Color(0xFFE58E00);

  // Background colors
  static const Color background = Color(0xFF000000);
  static const Color cardBackground = Color(0xFF121212);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF9E9E9E);
  // Text colors
  // static const Color textPrimary = Color(0xFF212121);
  // static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Colors.white;
  static const Color textOnAccent = Colors.white;

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFB300);
  static const Color info = Color(0xFF29B6F6);

  // Social interaction colors
  static const Color like = Color(0xFFE53935); // Like/heart color
  static const Color match = Color(0xFFE91E63); // Match color
  static const Color follow = Color(0xFF4A90E2); // Follow button color

  // Gradients for profiles and backgrounds
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryLight, primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentLight, accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Match UI specific colors (Tinder-like)
  static const Color matchLike =
      Color(0xFF66BB6A); // Green for like (swipe right)
  static const Color matchDislike =
      Color(0xFFE53935); // Red for dislike (swipe left)

  // Admin panel colors
  static const Color adminPrimary = Color(0xFF673AB7);
  static const Color adminSecondary = Color(0xFF9575CD);
}
