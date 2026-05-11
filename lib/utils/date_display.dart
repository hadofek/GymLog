import 'package:intl/intl.dart';

class DateDisplay {
  /// Parses a stored date string ("DD/MM/YYYY" or "DD/MM/YYYY  HH:MM")
  /// and returns a locale-aware display string.
  /// Falls back to the raw string if parsing fails.
  static String format(String stored) {
    try {
      final datePart = stored.trim().split(RegExp(r'\s+')).first;
      final parts = datePart.split('/');
      final dt = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      return DateFormat.yMMMd().format(dt); // e.g. "May 11, 2025"
    } catch (_) {
      return stored;
    }
  }

  /// Short form for tight spaces — e.g. "May 11"
  static String formatShort(String stored) {
    try {
      final datePart = stored.trim().split(RegExp(r'\s+')).first;
      final parts = datePart.split('/');
      final dt = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      return DateFormat.MMMd().format(dt); // e.g. "May 11"
    } catch (_) {
      return stored;
    }
  }
}
