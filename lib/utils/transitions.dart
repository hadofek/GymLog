import 'package:flutter/material.dart';

/// A subtle fade + upward slide transition to replace MaterialPageRoute.
Route<T> fadeSlideRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 270),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );