import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF4F46E5);
  static const secondary = Color(0xFF7C3AED);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const background = Color(0xFFF7F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF2563EB);

  static const primaryGradient = LinearGradient(
    colors: [secondary, primary, Color(0xFF3157EA)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
