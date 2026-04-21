import 'package:flutter/material.dart';
import 'package:gymlog/screens/splash_screen.dart';

void main() {
  runApp(const GymLogApp());
}

class GymLogApp extends StatelessWidget {
  const GymLogApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const SplashRouter(),
    );
  }
}
