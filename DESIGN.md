---
name: GymLog
description: A precision workout tracker for athletes who measure every rep.
colors:
  surface-void: "#0B0E1A"
  surface-card: "#111827"
  surface-raised: "#141928"
  surface-high: "#1C2235"
  text-primary: "#E8E8E8"
  text-secondary: "#8896B0"
  text-tertiary: "#5A6880"
  amber: "#F59E0B"
  amber-deep: "#D97706"
  live-green: "#4ADE80"
  error-soft: "#FFB4AB"
  destructive: "#FF6B6B"
  light-bg: "#F9F8F7"
  light-card: "#FFFFFF"
  light-text: "#111111"
typography:
  display:
    fontFamily: "Lexend, sans-serif"
    fontSize: "56sp"
    fontWeight: 900
    lineHeight: 0.94
    letterSpacing: "-1.5sp"
  headline:
    fontFamily: "Lexend, sans-serif"
    fontSize: "30sp"
    fontWeight: 500
    lineHeight: 1.25
    letterSpacing: "-0.3sp"
  title:
    fontFamily: "Lexend, sans-serif"
    fontSize: "22sp"
    fontWeight: 600
    lineHeight: 1.33
    letterSpacing: "-0.2sp"
  subtitle:
    fontFamily: "Lexend, sans-serif"
    fontSize: "18sp"
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: "-0.2sp"
  body:
    fontFamily: "Lexend, sans-serif"
    fontSize: "16sp"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Space Grotesk, sans-serif"
    fontSize: "11sp"
    fontWeight: 500
    lineHeight: 1.33
    letterSpacing: "0.5sp"
rounded:
  xs: "2px"
  sm: "8px"
  md: "12px"
  lg: "14px"
  xl: "16px"
  xxl: "20px"
  sheet: "24px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.amber}"
    textColor: "{colors.surface-void}"
    rounded: "{rounded.xxl}"
    padding: "14px 24px"
  button-primary-hover:
    backgroundColor: "{colors.amber-deep}"
    textColor: "{colors.surface-void}"
    rounded: "{rounded.xxl}"
    padding: "14px 24px"
  card-default:
    backgroundColor: "{colors.surface-card}"
    rounded: "{rounded.xl}"
    padding: "16px"
  card-elevated:
    backgroundColor: "{colors.surface-raised}"
    rounded: "{rounded.xl}"
    padding: "16px"
  input-default:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.md}"
    padding: "14px 16px"
  chip-accent:
    backgroundColor: "{colors.surface-high}"
    textColor: "{colors.amber}"
    rounded: "{rounded.lg}"
    padding: "6px 12px"
---

# Design System: GymLog

## 1. Overview

**Creative North Star: "The Instrument Panel"**

GymLog is a high-precision instrument for athletes who track their training with the same rigor they bring to the gym. The visual system is built around a single constraint: legibility in any gym condition — bright overhead fluorescents, dim locker room, one-handed between sets. The answer is obsidian surfaces, amber signal, and typography that reads in a glance.

The system rejects decoration on principle. Every visual element either carries information or supports something that does. The deep navy-black backgrounds (`#0B0E1A`) are not dark mode for aesthetics — they reduce glare under fluorescents and make the amber accent impossible to miss. That amber (`#F59E0B`) is used with surgical precision: primary action, live session indicator, the logotype wordmark. Nothing else. Depth comes from tonal layering across four surface values, not from shadows or blur. Shadows appear only where an element truly floats.

Typography is Lexend for display through body text, paired with Space Grotesk for all label and metadata roles. Lexend's wide apertures are optimized for reading speed at small sizes; Space Grotesk's character widths make numeric labels align cleanly without extra CSS. The pairing is functional, not decorative.

This system explicitly rejects: bright consumer fitness aesthetics (no saturated teals, pinks, or motivational gradient fills), generic SaaS dashboard layouts (no metric card grids with small-label/big-number heroes), anatomy-textbook muscle maps with rainbow region fills and callout lines, and anything that reads as "AI-generated fitness app from a stock template."

**Key Characteristics:**
- Obsidian surface stack: four tonal layers from `#0B0E1A` to `#1C2235`, depth through luminance not shadow
- Amber as the single accent — used on ≤10% of any screen
- Lexend + Space Grotesk type system; negative letter-spacing on all headlines and display text
- Precision-ground corners: 12–16px on content containers, 20px on primary actions
- Flat app bars — elevation 0, scroll-under elevation 0 — always
- No borders used as decorative stripes; borders only define surface boundaries

## 2. Colors: The Obsidian Instrument Palette

Dark mode is the primary experience. Light mode is supported but the design intent is dark. Every decision begins from the obsidian surface stack.

### Primary
- **Amber Signal** (`#F59E0B`): The sole accent. Used on primary buttons, the GYMLOG logotype, active nav states, live session indicators, and PR highlights. Never used decoratively or as fill color on large surfaces.
- **Amber Deep** (`#D97706`): Hover and pressed state for amber elements only.

### Neutral (Surface Stack — Dark)
- **Surface Void** (`#0B0E1A`): The deepest layer. Scaffold background, app bar, bottom navigation bar. The floor everything else sits on.
- **Surface Card** (`#111827`): Standard card background. One tonal step above the floor.
- **Surface Raised** (`#141928`): Elevated cards, input fill, secondary containers within a card. Two steps up.
- **Surface High** (`#1C2235`): Borders, dividers, drag handles, chips at rest. The ceiling of the tonal stack; also the boundary color between surfaces.

### Neutral (Text — Dark)
- **Text Primary** (`#E8E8E8`): Main text, value labels, screen titles. Legible on all dark surfaces.
- **Text Secondary** (`#8896B0`): Supporting labels, metadata, secondary content.
- **Text Tertiary** (`#5A6880`): Hint text, placeholders, timestamps, deeply de-emphasized content.

### Neutral (Light Mode)
- **Light Canvas** (`#F9F8F7`): Scaffold background in light mode. Marginally warm — not pure white.
- **Light Card** (`#FFFFFF`): Card background in light mode.
- **Light Text** (`#111111`): Primary text in light mode. Also the light-mode stand-in for the amber accent on non-logotype elements.

### Semantic
- **Live Green** (`#4ADE80`): Active workout state, live session indicator. Always rendered on dark surfaces; never appears in light mode contexts.
- **Error Soft** (`#FFB4AB`): Inline error messages and validation. Rose-tinted, readable at 11sp label size.
- **Destructive** (`#FF6B6B`): Delete icons and danger actions. More saturated than Error Soft — use when immediate attention is required.

### Named Rules
**The One Amber Rule.** Amber (`#F59E0B`) appears on ≤10% of any screen. Its scarcity is the signal — it draws the eye to the one thing that matters. If amber appears in more than one distinct role on a screen, one of those uses is wrong.

**The Light Mode Inversion Rule.** In light mode, amber is replaced by `#111111` as the general accent for interactive elements. The GYMLOG logotype remains amber in both modes — it is the only element that keeps amber in light mode.

## 3. Typography

**Display / Headline / Body Font:** Lexend (Google Fonts), sans-serif
**Label / Metadata Font:** Space Grotesk (Google Fonts), sans-serif

**Character:** Lexend's wide apertures were engineered for reading speed — exactly the constraint of reading reps and weights in a gym environment. Space Grotesk's consistent character widths make numerical labels align cleanly. The pairing was chosen for function; it reads as precise and modern as a side effect.

### Hierarchy
- **Display** (Lexend, w900, 56sp, line-height 0.94, letter-spacing -1.5sp): Key metric numbers — volume totals, PRs, large rep counts. Set tight; this is a number, not prose. Paired with a Space Grotesk label below.
- **Headline** (Lexend, w500, 30sp, line-height 1.25, letter-spacing -0.3sp): Screen titles. One per screen.
- **Title** (Lexend, w600, 22sp, line-height 1.33, letter-spacing -0.2sp): Card headers, section titles. w600 separates it from body without relying on size alone.
- **Subtitle** (Lexend, w500, 18sp, line-height 1.3, letter-spacing -0.2sp): Sub-headers, exercise names in workout lists, secondary screen sections.
- **Body** (Lexend, w400, 16sp, line-height 1.5): General content, list row text, form labels.
- **Body Semibold** (Lexend, w500, 16sp): Inline emphasis — weight values, PR tags, emphasis without a size increase.
- **Label** (Space Grotesk, w500, 11sp, line-height 1.33, letter-spacing 0.5sp): Navigation labels, metric sub-labels, section headers. Always paired with a larger value; never stands alone.
- **Label Small** (Space Grotesk, w400, 11sp, line-height 1.6, letter-spacing 0.3sp): Timestamps, secondary metadata, data-dense rows.

### Named Rules
**The Negative Tracking Rule.** All Lexend headlines and display text carry negative letter-spacing (-0.2sp minimum, -1.5sp for display numerics). Lexend's default tracking is generous for reading; tightening it at display sizes makes numbers read as a unit.

**The No-Scale-Mixing Rule.** Labels are always Space Grotesk. Headlines, titles, body are always Lexend. Never mix within a single text element.

## 4. Elevation

GymLog uses **tonal layering as its primary depth mechanism.** The four-step surface stack (`#0B0E1A` → `#111827` → `#141928` → `#1C2235`) conveys depth through luminance alone — consistent with Material3's tonal elevation model but stripped of any hue tinting. Surfaces that sit higher in the hierarchy use a lighter tonal step, not a shadow.

Shadows are permitted but reserved for elements that genuinely float above the interface: bottom sheets, modals, context menus. They are never applied to cards or list items at rest.

### Shadow Vocabulary
- **Sheet Float** (`box-shadow: 0 -4px 32px rgba(0,0,0,0.48)`): Bottom sheets only. High opacity compensates for the low contrast between dark shadow and dark background.
- **Ambient Lift** (`box-shadow: 0 2px 12px rgba(0,0,0,0.32)`): Dragging or pressed state on draggable list items. Disappears on release.

### Named Rules
**The Tonal-First Rule.** Reach for a darker or lighter surface value before reaching for a shadow. If depth can be conveyed by layering `surface-raised` over `surface-void`, no box-shadow is needed. Shadows mean "this is floating." Tonal steps mean "this is on top."

## 5. Components

### Buttons
The primary button is the single strongest visual anchor on any screen. Everything else defers to it. No border decorations, no icon-heavy padding.

- **Shape:** 20px radius (precision-ground, not a full pill).
- **Primary:** Amber fill (`#F59E0B`), void text (`#0B0E1A`), 14×24px padding. Lexend w500 body size.
- **Hover / Focus:** Amber Deep (`#D97706`). No scale transform.
- **Ghost / Text:** Bare text in `text-primary` or amber. No background, no border. Used for secondary sheet actions and destructive confirmations.

### Chips / Badges
Muscle group tags, workout type indicators, filter pills.

- **At Rest:** `surface-high` background (`#1C2235`), `text-secondary` text, 14px radius, 6×12px padding. Space Grotesk label 11sp.
- **Active / Selected:** Amber at 13% opacity background (`#F59E0B22`), amber text. 14–20px radius depending on context.

### Cards / Containers
Cards group related data. They are never decorative containers.

- **Corner Style:** 12px (compact data rows), 16px (featured cards, dialogs).
- **Background:** `surface-card` (`#111827`) standard; `surface-raised` (`#141928`) for nested containers within a card.
- **Shadow:** None at rest. Sheet Float only for bottom sheets.
- **Border:** `surface-high` (`#1C2235`) 1px — used only when two same-tonal surfaces need a defined boundary.
- **Internal Padding:** 16px standard, 12px for dense data rows.

### Inputs / Fields
Filled style. No stroke at rest; the fill communicates the field boundary.

- **Style:** `surface-raised` fill (`#141928`), no border, 12px radius.
- **Placeholder:** `text-tertiary` (`#5A6880`).
- **Focus:** 1px amber stroke (`#F59E0B`). No glow.
- **Content Padding:** 14px vertical, 16px horizontal.
- **Error:** Error Soft (`#FFB4AB`) label below the field.

### Navigation (Bottom Nav)
- **Background:** `surface-void` (`#0B0E1A`). No elevation, no separator.
- **Active:** Amber icon + amber Space Grotesk label.
- **Inactive:** `text-tertiary` icon + label.

### Bottom Sheets
The preferred pattern for quick actions, pickers, confirmations — not modals.

- **Top Corners:** 24px radius, top only.
- **Drag Handle:** 36×4px pill, `surface-high` color, 2px radius, centered, 12px above handle, 12px below.
- **Background:** `surface-card` (`#111827`).
- **Shadow:** Sheet Float.
- **Internal Padding:** 20px horizontal, 12px top after handle.

### Logotype (Signature Component)
The GYMLOG wordmark is a text element, not an image. Its spec is fixed.

- Lexend, w900, italic, 20sp, letter-spacing 3sp, amber (`#F59E0B`).
- Always top-left in the app bar row, beside a Space Grotesk screen-context label (e.g., "STATS").
- Amber in both light and dark mode — the only element that keeps amber in light mode.
- Weight, style, and color are never changed.

## 6. Do's and Don'ts

### Do:
- **Do** use `surface-void` (`#0B0E1A`) as the scaffold base in dark mode — never a lighter surface as the bottom layer.
- **Do** convey depth through tonal layering: `surface-void` → `surface-card` → `surface-raised` → `surface-high`. Use shadows only for floating elements.
- **Do** keep amber on ≤10% of any screen. When uncertain where amber belongs, remove one current use rather than adding another.
- **Do** apply negative letter-spacing to all Lexend headlines: -0.2sp minimum, -1.5sp for display-size numerics.
- **Do** use filled inputs with `surface-raised` and no stroke at rest. The fill is the boundary.
- **Do** use Space Grotesk exclusively for labels, nav items, and metadata. Never for body text or headlines.
- **Do** keep the GYMLOG logotype in Lexend w900 italic, amber, letter-spacing 3sp — in both light and dark mode.
- **Do** use the Sheet Float shadow exclusively on bottom sheets and modals. Never on cards at rest.

### Don't:
- **Don't** use bright consumer fitness aesthetics: no saturated teals, neon, pinks, or motivational gradient fills. If it reads like MyFitnessPal or Strava, it has failed.
- **Don't** use the generic SaaS dashboard pattern: big metric number, small label, stat grid, gradient accent card. That is the wrong register entirely.
- **Don't** apply a colored `border-left` or `border-right` stripe to cards, list items, or callouts. Rewrite with background tint or a leading icon instead.
- **Don't** use gradient text (`background-clip: text` + gradient). Amber is a solid color; apply it whole.
- **Don't** use glassmorphism — blurred backgrounds, frosted panels — decoratively. Surfaces are solid obsidian.
- **Don't** render muscle maps with rainbow region fills, anatomy-textbook color coding, or callout label lines. The muscle visualization uses amber glow as its data channel: unlit = no sessions, bright = high frequency.
- **Don't** add shadows to cards or list items at rest. Tonal layering is the depth signal.
- **Don't** use amber in more than one distinct role on a screen without strong justification.
- **Don't** produce a screen that reads as "AI-generated fitness app from a stock template." If the color strategy, layout, and type hierarchy could have come from a generic fitness template, rethink from the surface stack up.
