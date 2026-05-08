import 'package:flutter/material.dart';

class AppColors {
  static bool isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  // ── Surfaces ──
  static Color background(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF0B0E1A) : const Color(0xFFF9F8F7);
  static Color cardBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  static Color surfaceContainer(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF0B0E1A) : const Color(0xFFFFFFFF);
  static Color surfaceContainerHigh(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF141928) : const Color(0xFFF5F5F5);
  static Color surfaceContainerHighest(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1C2235) : const Color(0xFFEEEEEE);
  static Color cardElevated(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF141928) : const Color(0xFFF5F5F5);

  // ── Text ──
  static Color textPrimary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFE8E8E8) : const Color(0xFF111111);
  static Color textSecondary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF8896B0) : const Color(0xFF666666);
  static Color textTertiary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF5A6880) : const Color(0xFFAAAAAA);

  // ── Borders / Dividers ──
  static Color border(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1C2235) : const Color(0xFFE0E0E0);
  static Color divider(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1C2235) : const Color(0xFFE0E0E0);

  // ── Inputs ──
  static Color inputFill(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF141928) : const Color(0xFFF8F8F8);
  static Color hintText(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF4A5568) : const Color(0xFFAAAAAA);

  // ── Semantic states ──
  /// Soft error text / message color (dark: rose, light: deep red).
  static Color error(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFFFB4AB) : const Color(0xFFB91C1C);
  /// Bold destructive action color for delete icons and danger buttons.
  static Color destructive(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFFF6B6B) : const Color(0xFFE53935);

  // ── Nav ──
  static Color bottomBarBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF0B0E1A) : const Color(0xFFFFFFFF);

  // ── Accent (amber dark / near-black light) ──
  static Color accent(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFF59E0B) : const Color(0xFF111111);
  static Color accentContainer(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFF59E0B) : const Color(0xFF111111);
  static Color accentMuted(BuildContext ctx) =>
      isDark(ctx) ? const Color(0x22F59E0B) : const Color(0x22111111);

  // ── Primary button ──
  static Color primaryBtnBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFF59E0B) : const Color(0xFF111111);
  static Color primaryBtnFg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF0B0E1A) : const Color(0xFFFFFFFF);

  // ── Legacy constants ──
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldDark = Color(0xFFD97706);
  /// Live / active indicator green — always shown on dark surfaces.
  static const Color liveGreen = Color(0xFF4ADE80);
  /// Theme-aware live/active indicator: bright green in dark mode, dark green in light mode for contrast.
  static Color liveActivity(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
}
