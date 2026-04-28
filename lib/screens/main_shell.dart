import 'package:flutter/material.dart';
import 'package:gymlog/screens/home_screen.dart';
import 'package:gymlog/screens/stats_screen.dart';
import 'package:gymlog/screens/exercise_library_screen.dart';
import 'package:gymlog/screens/settings_screen.dart';
import 'package:gymlog/utils/app_colors.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final _visited = <int>{0};

  Key _statsKey = const ValueKey('stats_initial');

  void _onTabSelected(int i) {
    setState(() {
      if (i == 1) _statsKey = UniqueKey();
      _visited.add(i);
      _selectedIndex = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final navBg = AppColors.bottomBarBg(context);
    final unselected = AppColors.textTertiary(context);
    final selected = AppColors.accent(context);
    final indicatorColor = isDark
        ? const Color(0xFFCB601A).withValues(alpha: 0.18)
        : const Color(0xFFB83C08).withValues(alpha: 0.10);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const HomeScreen(),
          _visited.contains(1)
              ? StatsScreen(key: _statsKey)
              : const SizedBox(),
          _visited.contains(2)
              ? const ExerciseLibraryScreen()
              : const SizedBox(),
          _visited.contains(3) ? const SettingsScreen() : const SizedBox(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? const Color(0xFF434654).withValues(alpha: 0.5)
                  : const Color(0xFFEEEEEE),
              width: 0.5,
            ),
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ]
              : null,
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          indicatorColor: indicatorColor,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: unselected),
              selectedIcon: Icon(Icons.home_rounded, color: selected),
              label: 'HOME',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: unselected),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: selected),
              label: 'STATS',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined, color: unselected),
              selectedIcon: Icon(Icons.fitness_center_rounded, color: selected),
              label: 'LIBRARY',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: unselected),
              selectedIcon: Icon(Icons.settings_rounded, color: selected),
              label: 'SETTINGS',
            ),
          ],
        ),
      ),
    );
  }
}

// Override the NavigationDestination label style globally via a Theme wrapper
// if needed; for now the labelBehavior + custom indicator covers the KO look.
