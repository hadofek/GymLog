# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Dependencies
flutter pub get

# Run the app
flutter run                         # debug on connected device/emulator
flutter run --release               # release mode

# Build
flutter build apk                   # Android APK
flutter build appbundle             # Android App Bundle

# Lint / analyze
flutter analyze

# Tests
flutter test                        # all tests
flutter test test/widget_test.dart  # single test file

# Clean
flutter clean
```

## Architecture

GymLog is a Flutter app for logging gym workouts. The codebase is split across multiple files under `lib/`. There is no state management library — screens use `StatefulWidget` with `setState`.

**Entry point:** `lib/main.dart` — initializes `GymLogApp`, handles theme mode (light/dark/system via `SharedPreferences`), and mounts `SplashScreen`.

**Screens (`lib/screens/`):**
- `splash_screen.dart` — checks SharedPreferences for an existing user profile and routes to either `ProfileSetupScreen` or `HomeScreen`
- `home_screen.dart` — main dashboard showing a monthly calendar heat-map of workout days
- `month_workouts_screen.dart` — list of workouts for a selected month
- `log_workout_screen.dart` — active workout logging (exercises, sets, reps, weight, rest timer)
- `workout_detail_screen.dart` — view or delete a past workout
- `add_exercise_screen.dart` — add a new exercise to the local library
- `exercise_library_screen.dart` — browse and manage the full exercise library
- `exercise_history_screen.dart` — history and progress for a specific exercise
- `profile_setup_screen.dart` — onboarding and profile editing (name + photo)
- `settings_screen.dart` — app settings (theme mode, etc.)
- `stats_screen.dart` — workout statistics and progress charts
- `templates_screen.dart` — browse and manage workout templates
- `template_edit_screen.dart` — create or edit a workout template
- `body_measurements_screen.dart` — log and view body measurements (weight, height, body fat)
- `cardio_log_screen.dart` — log cardio sessions
- `flexibility_log_screen.dart` — log flexibility/stretching sessions

**Utilities (`lib/utils/`):**
- `app_colors.dart` — `AppColors` helper class with dark/light theme-aware color getters
- `workout_types.dart` — `WorkoutTypes` constants (`weighted`, `cardio`, `bodyweight`, `flexibility`) and their associated colors/icons

**Widgets (`lib/widgets/`):**
- `workout_share_card.dart` — shareable workout summary card widget

**Data layer (`lib/db/db_helper.dart`):**  
`DBHelper` class. SQLite via `sqflite`, database version 7. Six tables:
- `exercises` — user's exercise library (name unique, is_bodyweight, muscle_group)
- `workouts` — workout sessions (date, duration_seconds, type, distance_km, notes, photo_path)
- `sets` — individual sets per workout (exercise_name, set_number, weight, reps, superset_group)
- `templates` — saved workout templates (name, type)
- `template_exercises` — exercises within a template (template_id, exercise_name, sort_order)
- `measurements` — body measurements log (date, weight_kg, height_cm, notes)

User preferences (profile name, photo path, theme mode) are stored in `SharedPreferences`.

## Key Details

- **Android package:** `com.Yonatanzvi.gymlog`
- **Release signing:** requires `android/app/key.properties` (not committed)
- **Dart SDK:** `>=3.9.2`
- **Linting:** `flutter_lints` via `analysis_options.yaml`
- The test in `test/widget_test.dart` is the Flutter template placeholder and does not cover app logic