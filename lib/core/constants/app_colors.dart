import 'package:flutter/material.dart';

class AppColors {
  // Qatar Insurance Company exact colors from the images
  static const Color primary = Color(0xFF6B73FF);      // Exact QIC purple-blue from image
  static const Color primaryDark = Color(0xFF5A63E8);  // Darker version
  static const Color primaryLight = Color(0xFF8B92FF); // Lighter version
  
  static const Color secondary = Color(0xFF00D4FF);     // Cyan from gradient
  static const Color secondaryDark = Color(0xFF00B8E6); // Dark Cyan
  static const Color secondaryLight = Color(0xFF33DDFF); // Light Cyan
  
  // QIC specific colors from the images
  static const Color qicPurple = Color(0xFF6B73FF);     // Main QIC color
  static const Color qicCyan = Color(0xFF00D4FF);       // Cyan accent
  static const Color qicGradientStart = Color(0xFF6B73FF); // Purple start
  static const Color qicGradientEnd = Color(0xFF00D4FF);   // Cyan end
  
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFEF4444);
  
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  
  static const Color divider = Color(0xFFE2E8F0);
  static const Color border = Color(0xFFCBD5E1);
  
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  
  static const Color cardBackground = Colors.white;
  static const Color cardShadow = Color(0x0F000000);
  
  static const Color accent = Color(0xFF06B6D4);
  
  // Simple clean background - no gradients
  static const Color cleanBackground = Color(0xFFF8FAFC);
  static const Color pureWhite = Colors.white;
}
