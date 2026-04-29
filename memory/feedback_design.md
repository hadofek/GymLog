---
name: Design Anti-Slop Rules
description: Specific design patterns to avoid and enforce in GymLog — what the user considers AI slop
type: feedback
originSessionId: f9c44b45-f9f1-4198-91c2-171304703b94
---
User explicitly asked for the app to be less "AI slop." Applied impeccable + design-taste-frontend skill principles. The following are hard rules for this project:

**BANNED patterns (never reintroduce):**
1. Hero-metric template: big number + small label + decorative icon on right. Banned. Use compact stat strips, inline header stats, or just omit the dedicated card.
2. Identical card grids: every card same radius/padding/border. Vary border-radius (use 10, 14, 16, 20 contextually).
3. All-caps labels as the only section header style — vary the type hierarchy.
4. Generic time-based greeting: "Good morning/afternoon/evening, [Name]" — removed, don't bring back.
5. Icon-in-tinted-rounded-box for list items (the 36x36 `color.withValues(alpha:0.12)` icon box pattern) — replace with numbered index + color dot approach.
6. `CircularProgressIndicator` as the sole loading state — use skeleton boxes.
7. `gym → dark blue` color reflex — the accent was changed from periwinkle blue (`#608BFF`) to warm amber-orange.

**Enforced accent color (as of April 2026):**
- Dark mode accent: `Color(0xFFE07B3E)` — warm amber-orange
- Dark accentContainer: `Color(0xFFCB601A)` — deeper amber
- Light accent: `Color(0xFFB83C08)` — deep rust
- Button foreground (was `#002469`): now `Color(0xFF150400)` — near-black warm
- The hardcoded `0xFF002469` navy blue appears in home_screen.dart and log_workout_screen.dart — must stay updated.

**What's good (keep):**
- Calendar heatmap on home screen is distinctive, keep it
- Lexend + Space Grotesk type pairing — keep
- Obsidian dark base colors — keep
- The "LIVE" badge in log_workout_screen — keep
- The superset connector widget in log_workout — keep
- The streak 7-bar indicator — keep, just style it right

**How to apply:** Any new UI feature or redesign must pass the "AI slop test" — if someone can immediately identify the category from the palette/pattern alone ("gym app → dark blue + dumbbell icons") it's failed. Always check the banned list before implementing.

**Why:** User used phrase "AI slop" — they want the app to feel crafted, not generated. The impeccable and design-taste-frontend skills were invoked for this task.
