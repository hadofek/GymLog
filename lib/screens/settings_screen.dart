import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/main.dart';
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
    final card = AppColors.cardBg(context);
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
        padding: const EdgeInsets.all(16),
        children: [
          Text('APPEARANCE', style: KiStyles.label(color: textSecondary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _ThemeOption(
                  label: 'System default',
                  subtitle: 'Follows your phone theme',
                  icon: Icons.brightness_auto_outlined,
                  selected: _themeMode == ThemeMode.system,
                  onTap: () => _setTheme(ThemeMode.system),
                  border: border,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isFirst: true,
                ),
                Divider(height: 1, color: border, indent: 56),
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
                Divider(height: 1, color: border, indent: 56),
                _ThemeOption(
                  label: 'Dark',
                  subtitle: 'Always use dark mode',
                  icon: Icons.dark_mode_outlined,
                  selected: _themeMode == ThemeMode.dark,
                  onTap: () => _setTheme(ThemeMode.dark),
                  border: border,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isLast: true,
                ),
              ],
            ),
          ),
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
  final bool isFirst;
  final bool isLast;

  const _ThemeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Builder(builder: (context) {
              final ac = AppColors.accentContainer(context);
              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? ac.withValues(alpha: 0.15)
                      : border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? ac : textSecondary,
                ),
              );
            }),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              Builder(builder: (context) {
                final ac = AppColors.accentContainer(context);
                return Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: ac, shape: BoxShape.circle),
                  child: const Icon(Icons.check,
                      size: 14, color: Color(0xFF002469)),
                );
              })
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
