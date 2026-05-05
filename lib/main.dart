import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/screens/splash_screen.dart';

void main() {
  runApp(const GymLogApp());
}

class GymLogApp extends StatefulWidget {
  const GymLogApp({super.key});

  static _GymLogAppState? _state;

  static void setThemeMode(ThemeMode mode) => _state?.setThemeMode(mode);
  static ThemeMode get currentThemeMode =>
      _state?._themeMode ?? ThemeMode.system;

  @override
  State<GymLogApp> createState() => _GymLogAppState();
}

class _GymLogAppState extends State<GymLogApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    GymLogApp._state = this;
    _loadThemeMode();
  }

  @override
  void dispose() {
    if (GymLogApp._state == this) GymLogApp._state = null;
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode') ?? 'system';
    if (!mounted) return;
    setState(() {
      _themeMode = saved == 'dark'
          ? ThemeMode.dark
          : saved == 'light'
              ? ThemeMode.light
              : ThemeMode.system;
    });
  }

  void setThemeMode(ThemeMode mode) => setState(() => _themeMode = mode);

  static ThemeData get _darkTheme => ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8E8E8),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF000000),
          onSurface: const Color(0xFFE8E8E8),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        cardColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Color(0xFFE8E8E8),
        ),
        useMaterial3: true,
      );

  static ThemeData get _lightTheme => ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF111111),
          brightness: Brightness.light,
        ).copyWith(
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF111111),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        cardColor: const Color(0xFFFFFFFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Color(0xFF111111),
        ),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymLog',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      home: const SplashRouter(),
    );
  }
}