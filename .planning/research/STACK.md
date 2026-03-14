# Technology Stack - Multi-Theme System

**Project:** CYBER-CYCLE OBD Dashboard
**Researched:** 2026-03-14
**Confidence:** MEDIUM (based on Flutter best practices, not verified with current docs)

## Recommended Stack

### Core Theme Management

| Technology | Version | Purpose | Why |
|-----------|---------|---------|-----|
| Provider | ^6.1.1 | Theme state management | Already in use, no need to add new state management |
| shared_preferences | ^2.2.0 | Theme persistence | Standard Flutter package, already in PROJECT.md hints |

### Theme Data Structure

| Component | Implementation | Why |
|-----------|---------------|-----|
| ThemeProvider | ChangeNotifier-based | Matches existing Provider pattern |
| ThemeData | Multiple instances | Flutter's built-in theme system |
| ColorScheme | Dynamic generation | Works with ThemeData |

### Sunrise/Sunset Auto-Switch

| Technology | Version | Purpose | Why |
|-----------|---------|---------|-----|
| geolocator | ^11.0.0 | Location access | Required for sunrise/sunset calculation |
| solar_calculator | ^1.0.0 | Sunrise/sunset times | Lightweight, no API needed |

## Implementation Approach

### Architecture Pattern: ThemeProvider + ThemeData

```dart
// 1. Define theme modes
enum AppThemeMode {
  cyberBlue,   // Current dark blue theme
  red,         // Red accent variant
  orange,      // Orange accent variant
  light,       // Light mode
  auto,        // Auto-switch based on sunrise/sunset
}

// 2. ThemeProvider (extends ChangeNotifier)
class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.cyberBlue;
  ThemeData get currentTheme => _getThemeData(_themeMode);
}

// 3. ThemeData factory methods
class AppTheme {
  static ThemeData cyberBlue() => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: Color(0xFF0DA6F2),
      // ...
    ),
  );

  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: Color(0xFF0DA6F2),
      // ...
    ),
  );
}
```

### Refactoring Current AppTheme

**Current:** Static Color/TextStyle constants
**Target:** ThemeData factory methods + ColorScheme

Key changes needed:
1. Convert static colors to ThemeData factories
2. Extract accent colors (primary, cyan, red, orange) as theme parameters
3. Update all widgets to use `Theme.of(context).colorScheme` instead of `AppTheme.*`

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| State Management | Provider (existing) | flutter_bloc | Adds unnecessary complexity; Provider already in use |
| Persistence | shared_preferences | hive | Overkill for simple key-value storage |
| Theme Library | Built-in ThemeData | flutter_theme | Not maintained, use native Flutter theming |
| Location | geolocator | permission_handler alone | Need actual coordinates |

## Why Not These Options

| Option | Why Not |
|--------|---------|
| Riverpod | Requires rewiring all existing Providers |
| Isar/Hive | Too heavy for theme preference storage |
| bloc | Over-engineered for 4-theme toggle |
| dynamic_theme | Deprecated, not maintained |

## Installation

```bash
# Core dependencies
flutter pub add provider shared_preferences geolocator

# Note: solar_calculator might not exist - use manual calculation or:
flutter pub add sun_position # Alternative for sunrise/sunset
```

## Sources

- Flutter official theming docs (https://docs.flutter.dev/ui/appearance/theming)
- Provider package documentation
- Existing codebase patterns in CLAUDE.md

## Notes

- All recommendations assume Provider remains the state management (as per CLAUDE.md)
- sunrise/sunset calculation can also be done manually with simple date math (no external package needed for approximate times)
- ThemeProvider should integrate with existing BluetoothProvider, LogProvider structure
