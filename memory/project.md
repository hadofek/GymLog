---
name: GymLog Project
description: GymLog Flutter app — architecture, design system, key details
type: project
originSessionId: f9c44b45-f9f1-4198-91c2-171304703b94
---
GymLog is a personal Flutter workout logging app for Android. Package: `com.Yonatanzvi.gymlog`. Dart SDK >=3.9.2.

**Design system: "Kinetic Obsidian"**
- Colors: `lib/utils/app_colors.dart` — `AppColors` class with dark/light getters
- Typography: `lib/utils/ki_styles.dart` — `KiStyles` class using Lexend (display/body) + Space Grotesk (labels). google_fonts package.
- Transitions: `lib/utils/transitions.dart` — `fadeSlideRoute()` helper
- Workout type colors/icons: `lib/utils/workout_types.dart`

**Navigation:** `lib/screens/main_shell.dart` — IndexedStack bottom nav with 4 tabs: Home, Stats, Library, Settings

**Key screens:**
- `home_screen.dart` — calendar heatmap dashboard, recent activity, FAB to start workout
- `log_workout_screen.dart` — active workout logger with live timer, superset support
- `stats_screen.dart` — all-time stats, top exercises podium, training split
- `templates_screen.dart` / `template_edit_screen.dart` — workout templates

**Data:** SQLite via sqflite (`lib/db/db_helper.dart`), SharedPreferences for user profile/theme

**As of April 2026:** The app has a complete Kinetic Obsidian design with periwinkle-blue accent. A major design upgrade was done to remove AI-slop patterns (hero metric cards, generic greeting, icon-box lists, uniform border radius, generic loading states) and change the accent from blue to warm amber-orange.

**Why:** User wants premium non-AI-slop design. The gym→blue color reflex was broken. See feedback memory for specific design rules to maintain.
