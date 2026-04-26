import 'package:flutter/material.dart';

class AppColors {
  static bool isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  static Color background(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF0C0C10) : const Color(0xFFF5F5F5);

  static Color cardBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF16161E) : Colors.white;

  static Color cardElevated(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1E1E28) : const Color(0xFFF9F9F9);

  static Color textPrimary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFEDEDF0) : const Color(0xFF111111);

  static Color textSecondary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF72728A) : const Color(0xFF888888);

  static Color textTertiary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF45455A) : const Color(0xFF666666);

  static Color border(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF242432) : const Color(0xFFEEEEEE);

  static Color divider(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1A1A24) : const Color(0xFFF5F5F5);

  static Color inputFill(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1A1A24) : Colors.white;

  static Color hintText(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF45455A) : const Color(0xFFCCCCCC);

  static Color bottomBarBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF0C0C10) : Colors.white;

  // Primary button — blue in dark, near-black in light
  static Color primaryBtnBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF4477FF) : const Color(0xFF111111);

  static Color primaryBtnFg(BuildContext ctx) => Colors.white;

  // Electric blue accent
  static Color accent(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF4D7FFF) : const Color(0xFF2D5BE3);

  static Color accentDark(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF6699FF) : const Color(0xFF1A45BE);

  static Color accentMuted(BuildContext ctx) =>
      isDark(ctx) ? const Color(0x204D7FFF) : const Color(0x1A2D5BE3);

  // Legacy constants (kept for backward compat in other screens)
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFF8B7500);
}
