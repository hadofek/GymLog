import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kinetic Obsidian typography helpers.
/// Call these with an optional [color] override; they return a [TextStyle].
class KiStyles {
  // Lexend 56px w900 — key metric numbers
  static TextStyle monument({Color? color}) => GoogleFonts.lexend(
        fontSize: 56,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        height: 0.94,
        color: color,
      );

  // Lexend 30px w500 — screen titles
  static TextStyle headlineXl({Color? color}) => GoogleFonts.lexend(
        fontSize: 30,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        height: 1.25,
        color: color,
      );

  // Lexend 22px w600 — card headers
  static TextStyle headlineLg({Color? color}) => GoogleFonts.lexend(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.33,
        color: color,
      );

  // Lexend 18px w500 — sub-headers
  static TextStyle headlineMd({Color? color}) => GoogleFonts.lexend(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
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

  // Lexend 16px w500 — emphasis body
  static TextStyle bodySemibold({Color? color}) => GoogleFonts.lexend(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
      );

  // Space Grotesk 11px w500 — labels (less shouting)
  static TextStyle label({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.33,
        color: color,
      );

  // Space Grotesk 11px w400 — small labels
  static TextStyle labelSm({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        height: 1.6,
        color: color,
      );
}
