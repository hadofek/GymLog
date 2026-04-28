import 'package:flutter/material.dart';

// Kinetic Obsidian palette
class AppColors {
  static bool isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  // ── Surfaces ──
  static Color background(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF11131B) : const Color(0xFFF5F5F5);

  static Color cardBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF16161E) : Colors.white;

  static Color surfaceContainer(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1D1F27) : const Color(0xFFF9F9F9);

  static Color surfaceContainerHigh(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF282A32) : const Color(0xFFF0F0F0);

  static Color surfaceContainerHighest(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF33343D) : const Color(0xFFE8E8E8);

  static Color cardElevated(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1D1F27) : const Color(0xFFF9F9F9);

  // ── Text ──
  static Color textPrimary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFE1E2ED) : const Color(0xFF111111);

  static Color textSecondary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFC3C6D7) : const Color(0xFF666666);

  static Color textTertiary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF8D90A0) : const Color(0xFFAAAAAA);

  // ── Borders ──
  static Color border(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF434654) : const Color(0xFFEEEEEE);

  static Color divider(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF282A32) : const Color(0xFFF5F5F5);

  // ── Inputs ──
  static Color inputFill(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1D1F27) : Colors.white;

  static Color hintText(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF434654) : const Color(0xFFCCCCCC);

  // ── Nav ──
  static Color bottomBarBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF16161E) : Colors.white;

  // ── Primary (warm amber-orange) ──
  static Color accent(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFE07B3E) : const Color(0xFFB83C08);

  static Color accentContainer(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFCB601A) : const Color(0xFFA03208);

  static Color accentMuted(BuildContext ctx) =>
      isDark(ctx) ? const Color(0x26E07B3E) : const Color(0x1AB83C08);

  // ── Primary button ──
  static Color primaryBtnBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFCB601A) : const Color(0xFF111111);

  static Color primaryBtnFg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF150400) : Colors.white;

  // ── Legacy constants ──
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFF8B7500);
}
