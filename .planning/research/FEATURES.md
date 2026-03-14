# Feature Landscape: Multi-Theme System

**Domain:** Flutter OBD Dashboard Multi-Theme Support
**Researched:** 2026-03-14

## Overview

This document identifies features required to implement multi-theme support in an existing Flutter OBD dashboard (Cyber-Cycle). The current codebase uses a single dark cyberpunk theme with 40+ files referencing hardcoded `AppTheme` color constants.

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Theme State Provider** | Centralized theme state management | Medium | Using existing Provider pattern; must integrate with current architecture |
| **Theme Data Model** | Structured theme definition with all color tokens | Low | Define 4 themes: Cyber Blue, Red, Orange, Light |
| **Theme-Aware Widget Refactor** | All 40+ widget files must consume dynamic theme colors | High | Most time-consuming feature; requires systematic refactor |
| **Manual Theme Switcher UI** | Settings page for user to select theme | Medium | Part of new settings screen; needs theme preview |
| **Theme Persistence** | Save user preference across app restarts | Low | Use `shared_preferences` as mentioned in PROJECT.md |

### Dependencies

```
Theme State Provider → Theme Data Model
Theme Data Model → Theme-Aware Widget Refactor
Manual Theme Switcher UI → Theme Persistence
```

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Auto Sunrise/Sunset Theme Switching** | Automatically switch between dark/light based on time of day | Medium | Requires location permission; use `solar_calculator` package |
| **Theme Preview Thumbnails** | Visual preview when selecting themes in settings | Medium | Show mini gauge/card previews in each theme |
| **Per-Theme Gauge Colors** | Each theme has optimized accent colors for gauge readability | Low | Red theme uses red accents, orange theme uses orange, etc. |
| **Smooth Theme Transition** | Animated color transition when switching themes | Medium | Low priority per PROJECT.md out-of-scope |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Ambient Light Sensor Theme** | Out of scope per PROJECT.md; adds complexity | Stick to manual + sunrise/sunset |
| **Theme Gradient Animations** | Out of scope per PROJECT.md; performance risk | Instant theme switch |
| **User-Created Custom Themes** | Not in requirements; increases UI complexity | Focus on 4 predefined themes |
| **Cloud Theme Sync** | Over-engineering for local-first app | Local persistence only |

## Implementation Complexity Breakdown

### High Complexity Items

1. **Theme-Aware Widget Refactor**
   - 40+ files reference `AppTheme.*` constants
   - Each widget needs to consume theme from Provider or Theme.of(context)
   - Gauges (speed, RPM, combined) have complex CustomPaint with hardcoded colors
   - **Estimated effort:** 60-70% of total implementation time

2. **Settings Screen with Theme Selection**
   - New screen needs to be created
   - Theme preview thumbnails require additional widget previews
   - Integration with existing navigation

### Medium Complexity Items

1. **Auto Theme Switching (Sunrise/Sunset)**
   - Requires location permission check
   - Sunrise/sunset calculation logic
   - Background/foreground handling

2. **Smooth Theme Transition**
   - AnimatedTheme widget usage
   - Ensure OBD data rendering not affected during transition

### Low Complexity Items

1. **Theme Data Model** - Simple data class with color definitions
2. **Theme Persistence** - Standard shared_preferences usage
3. **Theme State Provider** - Standard Provider with ChangeNotifier

## MVP Recommendation

Prioritize in this order:

1. **Theme Data Model + Provider** - Foundation for all other work
2. **Theme Persistence** - Enables user preference save/load
3. **Theme-Aware Widget Refactor (Core)** - Refactor most-critical widgets first:
   - Gauges (speed, RPM)
   - Dashboard screen
   - Navigation bar
   - Status footer
4. **Manual Theme Switcher** - Settings UI to select themes
5. **Auto Sunrise/Sunset** - Time-based auto switching

Defer:
- **Smooth Theme Transition**: Explicitly out of scope, adds complexity
- **Theme Preview Thumbnails**: Nice-to-have, not MVP

## Files Requiring Theme Refactor

Based on codebase analysis, these files use `AppTheme.*` and need refactoring:

**Widgets (16 files):**
- cyber_button.dart
- combined_gauge_card.dart
- connected_device_card.dart
- bluetooth_device_list.dart
- bluetooth_status_icon.dart
- top_navigation_bar.dart
- side_stats_panel.dart
- telemetry_chart_card.dart
- diagnostic_logs_panel.dart
- riding_events_panel.dart
- speed_gear_card.dart
- cyber_dialog.dart
- bluetooth_alert_dialog.dart
- event_notification_dialog.dart

**Screens (4 files):**
- main_container.dart
- dashboard_screen.dart
- logs_screen.dart
- bluetooth_scan_screen.dart

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Table Stakes | HIGH | Standard Flutter theming patterns, well-documented |
| Differentiators | MEDIUM | Auto-switch feature needs location permission handling |
| Anti-Features | HIGH | Clear scope from PROJECT.md |
| Complexity Estimates | MEDIUM | Based on code analysis; actual effort may vary |

## Sources

- Current codebase analysis (40+ files referencing AppTheme.*)
- PROJECT.md requirements specification
- Flutter ThemeData documentation (standard patterns)
