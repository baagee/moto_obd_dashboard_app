---
phase: 03-settings-auto-switch
plan: 01
subsystem: theme
tags: [theme, auto-switch, location, sunrise, sunset]
dependency_graph:
  requires:
    - 01-01-PLAN (theme infrastructure)
  provides:
    - SunriseSunsetService
    - ThemeProvider auto-switch methods
  affects:
    - lib/services/sunrise_sunset_service.dart
    - lib/providers/theme_provider.dart
tech_stack:
  added:
    - geolocator: ^12.0.0
    - sunrise_sunset_calc: ^3.0.0
  patterns:
    - Provider pattern for theme state management
    - Service injection for dependency inversion
    - SharedPreferences for persistence
key_files:
  created:
    - lib/services/sunrise_sunset_service.dart
  modified:
    - pubspec.yaml
    - android/app/src/main/AndroidManifest.xml
    - lib/providers/theme_provider.dart
decisions:
  - "Auto-switch defaults to cyberBlue for nighttime (matches existing dark theme preference)"
  - "5-minute timer interval balances responsiveness vs battery"
  - "Location timeout set to 10 seconds with low accuracy for quick response"
metrics:
  duration: "~3 minutes"
  completed: "2026-03-15"
  tasks: 3/3
---

# Phase 03 Plan 01: Sunrise/Sunset Auto Theme Switching Summary

## One-Liner

Added sunrise/sunset-based automatic theme switching infrastructure using geolocator and sunrise_sunset_calc packages.

## Objective

Add dependencies and create core infrastructure for sunrise/sunset-based auto theme switching, enabling automatic theme changes based on user's location.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Add dependencies and Android permissions | a021854 | pubspec.yaml, AndroidManifest.xml |
| 2 | Create SunriseSunsetService | 667717f | lib/services/sunrise_sunset_service.dart |
| 3 | Extend ThemeProvider with auto-switch | 25f94db | lib/providers/theme_provider.dart |

## Key Implementation Details

### SunriseSunsetService
- Uses geolocator to get current position (low accuracy, 10s timeout)
- Uses sunrise_sunset_calc to calculate sunrise/sunset for current date
- Returns `SunriseSunsetTimes` with sunrise and sunset as DateTime
- Handles exceptions gracefully (returns null on failure)

### ThemeProvider Extensions
- `isAutoSwitchEnabled` - getter for auto-switch state
- `setSunriseSunsetService(SunriseSunsetService)` - inject service
- `setAutoSwitch(bool)` - enable/disable auto-switch with persistence
- `checkAutoSwitch()` - evaluate time and apply appropriate theme
- `startAutoSwitchTimer()` - periodic 5-minute checks

### Auto-Switch Logic
- If enabled, checks if current time is after sunrise and before sunset
- Daytime: applies `AppThemeType.light`
- Nighttime: applies `AppThemeType.cyberBlue`
- Only changes theme if different from current (prevents flicker)

### Persistence
- Auto-switch preference saved to SharedPreferences with key `auto_theme_switch`
- Loaded on `initialize()` and restores timer if enabled

## Success Criteria Verification

- [x] geolocator and sunrise_sunset_calc dependencies added
- [x] Android location permissions added (ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION)
- [x] SunriseSunsetService created with getSunriseSunsetTimes()
- [x] ThemeProvider has isAutoSwitchEnabled getter and setAutoSwitch() method
- [x] Auto-switch logic: sunrise -> light theme, sunset -> dark theme

## Deviations from Plan

### Fixed: Package Version Issue
- **Found during:** Task 1
- **Issue:** sunrise_sunset_calc ^1.0.0 is not null-safe
- **Fix:** Updated to ^3.0.0 (null-safe version)
- **Files modified:** pubspec.yaml
- **Commit:** a021854

## Requirements Addressed

| ID | Requirement | Status |
|----|-------------|--------|
| THME-12 | Auto-switch based on sunrise/sunset | Implemented |
| THME-13 | Use location to calculate sunrise/sunset time | Implemented |
| THME-14 | After sunrise -> light theme, after sunset -> dark theme | Implemented |

## Self-Check: PASSED

- SunriseSunsetService created: /Users/dangliuhui/Desktop/tttzzz/moto_code/dashboard_test01/lib/services/sunrise_sunset_service.dart
- ThemeProvider modified: /Users/dangliuhui/Desktop/tttzzz/moto_code/dashboard_test01/lib/providers/theme_provider.dart
- All commits verified: a021854, 667717f, 25f94db
