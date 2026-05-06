import 'package:flutter/material.dart';

class AppColors {
  static bool isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  // ── Surfaces ──
  static Color background(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  static Color cardBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  static Color surfaceContainer(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  static Color surfaceContainerHigh(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
  static Color surfaceContainerHighest(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF111111) : const Color(0xFFEEEEEE);
  static Color cardElevated(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);

  // ── Text ──
  static Color textPrimary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFE8E8E8) : const Color(0xFF111111);
  static Color textSecondary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF888888) : const Color(0xFF666666);
  static Color textTertiary(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF6A6A6A) : const Color(0xFFAAAAAA);

  // ── Borders / Dividers ──
  static Color border(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0);
  static Color divider(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0);

  // ── Inputs ──
  static Color inputFill(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF0A0A0A) : const Color(0xFFF8F8F8);
  static Color hintText(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF333333) : const Color(0xFFBBBBBB);

  // ── Nav ──
  static Color bottomBarBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  // ── Accent (soft white dark / soft black light) ──
  static Color accent(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFE8E8E8) : const Color(0xFF111111);
  static Color accentContainer(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFE8E8E8) : const Color(0xFF111111);
  static Color accentMuted(BuildContext ctx) =>
      isDark(ctx) ? const Color(0x22E8E8E8) : const Color(0x22111111);

  // ── Primary button ──
  static Color primaryBtnBg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFFE8E8E8) : const Color(0xFF111111);
  static Color primaryBtnFg(BuildContext ctx) =>
      isDark(ctx) ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  // ── Legacy constants ──
  static const Color gold = Color(0xFFE8E8E8);
  static const Color goldDark = Color(0xFF888888);
}
