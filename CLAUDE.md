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

GymLog is a Flutter app for logging gym workouts. All UI and business logic lives in a **single file: `lib/main.dart`** (~1,550 lines). There is no state management library — screens use `StatefulWidget` with `setState`.

**Screen flow:**
- `SplashRouter` — checks SharedPreferences for an existing user profile and routes to either `ProfileSetupScreen` or `HomeScreen`
- `HomeScreen` — main dashboard showing a monthly calendar heat-map of workout days
- `MonthWorkoutsScreen` — list of workouts for a selected month
- `LogWorkoutScreen` — active workout logging (exercises, sets, reps, weight, rest timer)
- `WorkoutDetailScreen` — view or delete a past workout
- `AddExerciseScreen` — add a new exercise to the local library
- `ProfileSetupScreen` — onboarding and profile editing (name + photo)

**Data layer (`DBHelper` class in `lib/main.dart`):**  
SQLite via `sqflite`. Three tables:
- `exercises` — user's exercise library (name unique)
- `workouts` — workout sessions (date)
- `sets` — individual sets per workout (exercise_name, set_number, weight, reps)

User preferences (profile name, photo path) are stored in `SharedPreferences`.

## Key Details

- **Android package:** `com.Yonatanzvi.gymlog`
- **Release signing:** requires `android/app/key.properties` (not committed)
- **Dart SDK:** `>=3.9.2`
- **Linting:** `flutter_lints` via `analysis_options.yaml`
- The test in `test/widget_test.dart` is the Flutter template placeholder and does not cover app logic
