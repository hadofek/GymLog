---
name: Feature Audit
description: Complete audit of all GymLog features — confirmed bugs, dead ends, feature gaps, and what works
type: project
originSessionId: f9c44b45-f9f1-4198-91c2-171304703b94
---
Last audited: 2026-04-28. Full code read of all screens + db_helper.dart.

## CONFIRMED BUGS (broken behavior)

**B1 — Cardio notes display is raw/ugly**
- cardio_log_screen saves notes as a concatenated string: `"Running\navg_speed:8.5\nExtra notes"`
- workout_detail_screen shows this as a raw `Text()` widget — user sees "avg_speed:8.5" literally
- **Fix:** Parse the notes in workout_detail or store activity/speed as separate DB columns

**B2 — No edit option for cardio/flexibility sessions**
- workout_detail_screen only shows the "Edit sets" menu item `if (_grouped.isNotEmpty)`
- `_grouped` = exercise sets, always empty for cardio/flexibility (they use notes, not sets)
- So cardio/flexibility sessions have no way to correct a typo or fix the distance after saving
- **Fix:** Show an edit form for notes/distance/activity for non-weighted types

**B3 — PR badge in log_workout_screen is dead code**
- log_workout_screen checks `if (e.value['isPR'] == true)` to show a gold PR badge
- But sets are added as `{'weight': w, 'reps': r}` — `isPR` is never set during logging
- The badge never fires. `DBHelper.getLastSets()` exists but is not used for comparison
- **Fix:** On set save, compare against `getLastSets()` max weight and flag isPR if new max

**B4 — Old blue color still in workout_detail_screen (missed in color update)**
- `_SetBadge` uses text color `const Color(0xFFB4C5FF)` (old periwinkle blue) in dark mode
- `_buildSaveTemplateBar()` uses `const Color(0xFF002469)` twice (button fg and label)
- **Fix:** Update to `0xFF150400` (new amber button foreground) and `0xFFCB601A` for the set badge

## FEATURE GAPS (half-implemented)

**G1 — Templates don't pre-fill last session's weights**
- Templates store exercise names only (no default sets/reps/weight)
- `DBHelper.getLastSets(exerciseName)` exists and returns last session data but is NEVER called on template load
- Every time you use a template, you start with 0 sets and re-enter everything from scratch
- **Fix:** When loading from template, call getLastSets() per exercise and pre-populate sets with last session's data as a starting point

**G2 — Cardio/flexibility have no progress photo prompt**
- Only `log_workout_screen.dart` calls `_showProgressPhotoDialog()` after saving
- `cardio_log_screen.dart` and `flexibility_log_screen.dart` save and immediately pop — no photo prompt
- workout_detail_screen DOES show photos if they exist, but they can never be attached to cardio/flexibility
- **Fix:** Add photo prompt to cardio and flexibility save flows

**G3 — No notes input for weighted workouts**
- workouts table has a `notes` column (TEXT)
- log_workout_screen has no notes text field — only cardio/flexibility use notes (indirectly via concatenation)
- Users can't add "felt strong today" type notes to a weighted session
- **Fix:** Add optional notes field to log_workout_screen before saving

**G4 — Cardio distance and stats never shown in Stats screen**
- `distance_km` is properly stored per cardio workout
- `getAllTimeStats()` never aggregates distance — it only returns total_workouts, total_seconds, top_exercises, type_breakdown, longest_streak
- Cardio users have no "total distance run this month/all time" view
- **Fix:** Add distance aggregation to getAllTimeStats and show it in stats screen for cardio users

**G5 — Bodyweight exercise history chart is useless**
- exercise_history_screen shows a "Max Weight" progress chart
- For bodyweight exercises, weight is always 0 — chart shows a flat line at zero
- 1RM estimate (`weight * (1 + reps/30)`) also returns 0 for BW exercises
- **Fix:** For bodyweight exercises, chart max reps per session instead of max weight; compute 1RM from BW estimate

## MINOR ISSUES

**M1 — `body_fat_pct` column is orphaned**
- `_ensureV6Columns` creates `body_fat_pct REAL` in measurements table
- `DBHelper.insertMeasurement()` never writes it, no UI exposes it
- CLAUDE.md mentioned "body fat" tracking but it's dead
- **Fix:** Either add body fat to the measurements UI or drop the column intent

**M2 — Height logged per-measurement creates noise**
- Height is tracked as a per-entry field alongside weight
- Adults don't change height; logging it every entry is meaningless noise
- **Fix:** Make height a one-time profile field (SharedPreferences) rather than a measurement log entry

**M3 — Muscle group tags are never visualized**
- exercise_library_screen lets you tag exercises with a muscle group
- `muscle_group` is stored in the exercises table and returned by `getExercisesWithType()`
- It is NEVER shown in stats, exercise history, or anywhere else — you can tag exercises but the tags do nothing visible
- **Fix:** Show muscle group in exercise_history_screen header, or add a "by muscle" breakdown in stats

## CONFIRMED WORKING

- Progress photo: saved in `progress_photos/` dir, path in workouts.photo_path, displayed in workout_detail ✓
- Templates: exercise names load correctly, all sets/reps fully editable during logging ✓  
- Calendar heatmap with color-coded workout types ✓
- Streak tracking ✓
- Share workout as image to gallery (via Gal package) ✓
- Exercise history chart with 1RM estimate (for weighted) ✓
- Body measurements + weight progress chart ✓
- Superset grouping and visual connectors ✓
- Edit/delete sets in workout_detail (weighted only) ✓
- Exercise library: search, tag muscle group, toggle bodyweight ✓
- Theme settings ✓
