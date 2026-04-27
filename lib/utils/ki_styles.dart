import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kinetic Obsidian typography helpers.
/// Call these with an optional [color] override; they return a [TextStyle].
class KiStyles {
  // Lexend 64px w800 — key metric numbers
  static TextStyle monument({Color? color}) => GoogleFonts.lexend(
        fontSize: 64,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.56,
        height: 0.94,
        color: color,
      );

  // Lexend 32px w700 — screen titles
  static TextStyle headlineXl({Color? color}) => GoogleFonts.lexend(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.64,
        height: 1.25,
        color: color,
      );

  // Lexend 24px w700 — card headers
  static TextStyle headlineLg({Color? color}) => GoogleFonts.lexend(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.33,
        color: color,
      );

  // Lexend 20px w700 — sub-headers
  static TextStyle headlineMd({Color? color}) => GoogleFonts.lexend(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.3,
        color: color,
      );

  // Lexend 16px w400 — body text
  static TextStyle body({Color? color}) => GoogleFonts.lexend(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  // Lexend 15px w600 — emphasis body
  static TextStyle bodySemibold({Color? color}) => GoogleFonts.lexend(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Space Grotesk 12px w600 UPPERCASE — labels
  static TextStyle label({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        height: 1.33,
        color: color,
      );

  // Space Grotesk 10px w600 UPPERCASE — small labels
  static TextStyle labelSm({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        height: 1.6,
        color: color,
      );
}
