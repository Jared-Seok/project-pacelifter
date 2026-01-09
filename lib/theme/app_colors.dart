import 'package:flutter/material.dart';

/// PaceLifter Premium Dark Theme Colors
class AppColors {
  // Neutral / Background
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2C2C2C);
  
  // Brand / Accents
  static const Color neonGreen = Color(0xFFD4E157); // Hybrid / General UI
  static const Color strongOrange = Color(0xFFFF9100); // Strength Specific
  static const Color tealBlue = Color(0xFF00BFA5); // Endurance Specific
  
  // Logical Aliases (Central Management)
  static const Color primary = neonGreen;
  static const Color secondary = strongOrange;
  static const Color tertiary = tealBlue;
  
  // Status / Alerts
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFFCC00);
  static const Color success = Color(0xFF4CD964);
  
  // Text
  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFFBDBDBD);
  static const Color textDisabled = Color(0xFF757575);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [neonGreen, Color(0xFFAFB42B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
