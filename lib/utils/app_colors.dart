import 'package:flutter/material.dart';

class AppColors {
  static bool isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  static Color background(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

  static Color cardBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1E1E1E) : Colors.white;

  static Color textPrimary(BuildContext ctx) =>
      isDark(ctx) ? Colors.white : const Color(0xFF111111);

  static Color textSecondary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFAAAAAA) : const Color(0xFF888888);

  static Color textTertiary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF888888) : const Color(0xFF666666);

  static Color border(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF333333) : const Color(0xFFEEEEEE);

  static Color divider(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

  static Color inputFill(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF2A2A2A) : Colors.white;

  static Color hintText(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF666666) : const Color(0xFFCCCCCC);

  static Color bottomBarBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1A1A1A) : Colors.white;

  // Primary button (dark in light mode, white in dark mode)
  static Color primaryBtnBg(BuildContext ctx) =>
      isDark(ctx) ? Colors.white : const Color(0xFF111111);

  static Color primaryBtnFg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF111111) : Colors.white;

  // Gold accent — same across themes
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFF8B7500);
}
