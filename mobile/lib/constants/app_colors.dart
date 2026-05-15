import 'package:flutter/material.dart';

/// Palette ServiDom — identité visuelle pour le marché togolais.
abstract final class AppColors {
  static const Color primary = Color(0xFF1A6B3C);
  static const Color secondary = Color(0xFFF5A623);

  /// Fond des AppBar (orange identité).
  static const Color appBarBackground = secondary;

  /// Texte et icônes sur fond orange (contraste WCAG suffisant).
  static const Color onAppBar = Color(0xFFFFFFFF);
  static const Color onAppBarMuted = Color(0xE6FFFFFF);

  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color onPrimary = Colors.white;
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color error = Color(0xFFB3261E);
}
