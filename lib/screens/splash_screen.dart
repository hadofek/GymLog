import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/screens/main_shell.dart';
import 'package:gymlog/screens/profile_setup_screen.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});
  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    if (!mounted) return;
    if (name.isEmpty) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GymlogWordmark(),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              color: AppColors.accent(context),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
