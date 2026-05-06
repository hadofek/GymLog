import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/main.dart';
import 'package:gymlog/screens/exercise_library_screen.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _themeMode = GymLogApp.currentThemeMode;

  Future<void> _setTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme_mode',
      mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
              ? 'light'
              : 'system',
    );
    GymLogApp.setThemeMode(mode);
    if (mounted) setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final border = AppColors.border(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Expanded(
              child: Text(
                'GYMLOG',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 3,
                  color: AppColors.accentContainer(context),
                ),
              ),
            ),
            Text('SETTINGS',
                style: KiStyles.label(color: textSecondary)),
          ],
        ),
      ),
      body: ListView(
        children: [
          Divider(height: 1, thickness: 0.5, color: border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('DATA', style: KiStyles.label(color: textSecondary)),
          ),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ExerciseLibraryScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Exercise Library',
                          style: KiStyles.body(color: textPrimary)),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: textSecondary, size: 18),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text('APPEARANCE', style: KiStyles.label(color: textSecondary)),
          ),
          _ThemeOption(
            label: 'System default',
            subtitle: 'Follows your phone theme',
            icon: Icons.brightness_auto_outlined,
            selected: _themeMode == ThemeMode.system,
            onTap: () => _setTheme(ThemeMode.system),
            border: border,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, thickness: 0.5, color: border),
          _ThemeOption(
            label: 'Light',
            subtitle: 'Always use light mode',
            icon: Icons.light_mode_outlined,
            selected: _themeMode == ThemeMode.light,
            onTap: () => _setTheme(ThemeMode.light),
            border: border,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, thickness: 0.5, color: border),
          _ThemeOption(
            label: 'Dark',
            subtitle: 'Always use dark mode',
            icon: Icons.dark_mode_outlined,
            selected: _themeMode == ThemeMode.dark,
            onTap: () => _setTheme(ThemeMode.dark),
            border: border,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, thickness: 0.5, color: border),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const _ThemeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.accentContainer(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? ac : textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: KiStyles.body(color: textPrimary)),
              ),
              if (selected)
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: ac, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 12, color: Color(0xFF000000)),
                )
              else
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: border, width: 1.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
