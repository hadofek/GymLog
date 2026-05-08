import 'package:shared_preferences/shared_preferences.dart';

/// Handles display and conversion of weight values throughout the app.
/// Storage is always in kg. Call [load] in each screen's initState.
class WeightFormat {
  static String _unit = 'kg';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _unit = prefs.getString('weight_unit') ?? 'kg';
  }

  static Future<void> save(String unit) async {
    _unit = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weight_unit', unit);
  }

  static String get unit => _unit;
  static bool get isLbs => _unit == 'lbs';

  /// Convert a stored kg value to display units.
  static double toDisplay(double kg) => isLbs ? kg * 2.20462 : kg;

  /// Convert a user-entered display value back to kg for storage.
  static double fromDisplay(double display) =>
      isLbs ? display / 2.20462 : display;

  /// Format a stored kg value as a display string including unit suffix.
  static String format(double kg) {
    if (kg == 0) return 'Bodyweight';
    final v = toDisplay(kg);
    final s = v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);
    return '$s$_unit';
  }

  /// Format without the unit suffix (for use inside compound strings).
  static String value(double kg) {
    if (kg == 0) return 'Bodyweight';
    final v = toDisplay(kg);
    return v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);
  }

  /// Label for weight input fields, e.g. "Weight (kg)" or "Weight (lbs)".
  static String get inputLabel => 'Weight ($_unit)';

  /// Typical increment steps for ± buttons.
  static List<double> get increments =>
      isLbs ? [-10.0, -5.0, 5.0, 10.0] : [-5.0, -2.5, 2.5, 5.0];

  /// Label for a single increment value (e.g. "+5" or "+2.5").
  static String incrementLabel(double delta) {
    final abs = delta.abs();
    final str = abs % 1 == 0 ? abs.toInt().toString() : abs.toStringAsFixed(1);
    return delta > 0 ? '+$str' : '-$str';
  }

  /// Suggested progressive overload step for display ("+2.5kg" or "+5lbs").
  static String get overloadStep => isLbs ? '+5lbs' : '+2.5kg';

  /// Convert a stored kg 1RM value to a formatted string.
  static String formatRm(double kg) {
    final v = toDisplay(kg);
    final s = v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);
    return '$s$_unit';
  }
}
