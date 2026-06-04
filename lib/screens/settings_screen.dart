import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/main.dart';
import 'package:gymlog/screens/body_measurements_screen.dart';
import 'package:gymlog/screens/exercise_library_screen.dart';
import 'package:gymlog/screens/profile_setup_screen.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/utils/transitions.dart';
import 'package:gymlog/utils/weight_format.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';
import 'package:gymlog/widgets/tip_overlay.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _themeMode = GymLogApp.currentThemeMode;
  String _userName = '';
  String? _userImage;
  int _weeklyGoal = 3;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _userImage = prefs.getString('user_image');
      _weeklyGoal = prefs.getInt('weekly_goal') ?? 3;
      _weightUnit = prefs.getString('weight_unit') ?? 'kg';
    });
  }

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

  Future<void> _showWeeklyGoalPicker() async {
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    final accentContainer = AppColors.accentContainer(context);
    final currentGoal = _weeklyGoal;

    await showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: borderColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Weekly goal',
                    style: KiStyles.headlineMd(color: textPrimary)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('How many workouts per week?',
                    style: KiStyles.label(color: textTertiary)),
              ),
              const SizedBox(height: 12),
              ...[2, 3, 4, 5, 6, 7].map((n) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('$n days / week',
                    style: KiStyles.body(color: textPrimary)),
                trailing: currentGoal == n
                    ? Icon(Icons.check_rounded,
                        color: accentContainer, size: 20)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('weekly_goal', n);
                  if (mounted) setState(() => _weeklyGoal = n);
                },
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final border = AppColors.border(context);
    final accentContainer = AppColors.accentContainer(context);
    final surfaceHigh = AppColors.surfaceContainerHigh(context);

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
            const Expanded(child: GymlogWordmark()),
            Text('SETTINGS', style: KiStyles.label(color: textSecondary)),
          ],
        ),
      ),
      body: ListView(
        children: [
          // ── Profile card ──
          Divider(height: 1, thickness: 0.5, color: border),
          InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                fadeSlideRoute(const ProfileSetupScreen(isEditing: true)),
              );
              _loadPrefs();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: surfaceHigh,
                    backgroundImage: _userImage != null
                        ? FileImage(File(_userImage!))
                        : null,
                    child: _userImage == null
                        ? Text(
                            _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : '?',
                            style: KiStyles.headlineMd(color: textPrimary),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isNotEmpty ? _userName : 'Set your name',
                          style: _userName.isNotEmpty
                              ? KiStyles.bodySemibold(color: textPrimary)
                              : KiStyles.body(color: textTertiary),
                        ),
                        const SizedBox(height: 2),
                        Text('Edit profile',
                            style: KiStyles.labelSm(color: textTertiary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: textTertiary, size: 18),
                ],
              ),
            ),
          ),

          // ── Training ──
          Divider(height: 1, thickness: 0.5, color: border),
          _SectionHeader(label: 'TRAINING', color: textSecondary),
          _SettingsRow(
            label: 'Weekly goal',
            trailing: Text(
              '$_weeklyGoal days / week',
              style: KiStyles.labelSm(color: textTertiary),
            ),
            onTap: _showWeeklyGoalPicker,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, thickness: 0.5, color: border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: Text('Weight unit',
                        style: KiStyles.body(color: textPrimary)),
                  ),
                  _UnitToggle(
                    value: _weightUnit,
                    onChanged: (unit) async {
                      await WeightFormat.save(unit);
                      if (mounted) setState(() => _weightUnit = unit);
                    },
                    accentContainer: accentContainer,
                    textPrimary: textPrimary,
                    border: border,
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: border),

          // ── Data ──
          _SectionHeader(label: 'DATA', color: textSecondary),
          _SettingsRow(
            label: 'Exercise Library',
            onTap: () => Navigator.push(context,
                fadeSlideRoute(const ExerciseLibraryScreen())),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, thickness: 0.5, color: border),
          _SettingsRow(
            label: 'Body Measurements',
            onTap: () => Navigator.push(context,
                fadeSlideRoute(const BodyMeasurementsScreen())),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, thickness: 0.5, color: border),
          _SettingsRow(
            label: 'Reset feature hints',
            trailing: Icon(Icons.refresh_rounded, color: textSecondary, size: 18),
            onTap: () async {
              await TipOverlay.resetAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Feature hints reset — they\'ll show again on next visit.')),
                );
              }
            },
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, thickness: 0.5, color: border),

          // ── Appearance ──
          _SectionHeader(label: 'APPEARANCE', color: textSecondary),
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

          // ── About ──
          _SectionHeader(label: 'ABOUT', color: textSecondary),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: Text('Version',
                        style: KiStyles.body(color: textPrimary)),
                  ),
                  Text('1.2.5',
                      style: KiStyles.labelSm(color: textTertiary)),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: border),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(label, style: KiStyles.label(color: color)),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  final Color textPrimary;
  final Color textSecondary;

  const _SettingsRow({
    required this.label,
    required this.onTap,
    required this.textPrimary,
    required this.textSecondary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: KiStyles.body(color: textPrimary)),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(Icons.chevron_right_rounded,
                    color: textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final Color accentContainer;
  final Color textPrimary;
  final Color border;

  const _UnitToggle({
    required this.value,
    required this.onChanged,
    required this.accentContainer,
    required this.textPrimary,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['kg', 'lbs'].map((unit) {
          final selected = value == unit;
          return Semantics(
            label: '$unit, ${selected ? 'selected' : 'not selected'}',
            button: true,
            excludeSemantics: true,
            child: GestureDetector(
            onTap: () { if (!selected) onChanged(unit); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? accentContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.background(context)
                      : textPrimary,
                ),
              ),
            ),
          ));
        }).toList(),
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
                  decoration:
                      BoxDecoration(color: ac, shape: BoxShape.circle),
                  child: Icon(Icons.check,
                      size: 12,
                      color: AppColors.background(context)),
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
