import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/screens/splash_screen.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // In release mode, errors are non-fatal — log and continue
  };

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

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0E1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Something went wrong.',
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE8E8E8),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Restart the app to continue. Your workouts are saved.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: const Color(0xFF8896B0),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    };
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
          surface: const Color(0xFF0B0E1A),
          onSurface: const Color(0xFFE8E8E8),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0E1A),
        cardColor: const Color(0xFF0B0E1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0E1A),
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
          surface: const Color(0xFFF9F8F7),
          onSurface: const Color(0xFF111111),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F8F7),
        cardColor: const Color(0xFFF9F8F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9F8F7),
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