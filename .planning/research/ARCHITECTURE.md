# Architecture: Multi-Theme System for Flutter OBD Dashboard

**Domain:** Flutter multi-theme architecture with Provider state management
**Researched:** 2026-03-14
**Overall confidence:** HIGH

## Executive Summary

This document outlines the architecture for implementing a multi-theme system in the existing Flutter OBD dashboard. The system supports 4 themes (Cyber Blue, Red, Orange, Light) with auto-switching based on sunrise/sunset and manual selection. The architecture follows the existing Provider pattern used throughout the codebase.

## Recommended Architecture

### Component Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│                         main.dart                           │
│  ┌─────────────────┐    ┌─────────────────────────────┐   │
│  │ ThemeProvider   │───▶│ MaterialApp (theme: )        │   │
│  │ (ChangeNotifier)│    │ (consumes currentTheme)     │   │
│  └─────────────────┘    └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
           │                              ▲
           ▼                              │
┌─────────────────────────────────────────────────────────────┐
│                    lib/theme/                               │
│  ┌─────────────────┐    ┌─────────────────────────────┐   │
│  │ app_theme.dart  │    │ theme_colors.dart           │   │
│  │ (static const)  │    │ (ThemeColors - color groups)│   │
│  └─────────────────┘    └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                    lib/providers/                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              ThemeProvider                           │   │
│  │  - currentTheme: ThemeMode                          │   │
│  │  - themeColors: ThemeColors                         │   │
│  │  - autoMode: bool (sunrise/sunset)                  │   │
│  │  - setTheme(), toggleAutoMode()                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Action / System Event
         │
         ▼
┌────────────────────────┐
│   ThemeProvider        │  ← Manual selection
│   (setTheme)           │  ← Auto-toggle timer
│                        │  ← App startup (load saved)
         │
         ▼
┌────────────────────────┐
│   notifyListeners()     │
└────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────┐
│  Consumer<ThemeProvider>                               │
│  or context.watch<ThemeProvider>()                     │
└────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────┐
│  Widgets rebuild with new theme                        │
│  (access via Theme.of(context) or provider)            │
└────────────────────────────────────────────────────────┘
```

## Component Design

### 1. ThemeColors (Data Model)

**Location:** `lib/theme/theme_colors.dart`

```dart
/// 主题颜色集合 - 封装每套主题的所有颜色
class ThemeColors {
  final Color primary;
  final Color background;
  final Color surface;
  final Color accentCyan;
  final Color accentRed;
  final Color accentOrange;
  final Color accentGreen;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final bool isDark;

  const ThemeColors({
    required this.primary,
    required this.background,
    required this.surface,
    required this.accentCyan,
    required this.accentRed,
    required this.accentOrange,
    required this.accentGreen,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.isDark,
  });
}
```

### 2. ThemeProvider (State Management)

**Location:** `lib/providers/theme_provider.dart`

```dart
enum AppThemeType {
  cyberBlue,
  red,
  orange,
  light,
}

class ThemeProvider extends ChangeNotifier {
  AppThemeType _currentThemeType = AppThemeType.cyberBlue;
  bool _isAutoMode = true;
  ThemeColors _themeColors;

  // Getter
  AppThemeType get currentThemeType => _currentThemeType;
  bool get isAutoMode => _isAutoMode;
  ThemeColors get themeColors => _themeColors;

  // Constructor
  ThemeProvider() {
    _themeColors = _getThemeColors(_currentThemeType);
    _loadSavedTheme();
  }

  // Methods
  void setTheme(AppThemeType type) {
    _currentThemeType = type;
    _themeColors = _getThemeColors(type);
    _saveTheme(type);
    notifyListeners();
  }

  void toggleAutoMode() {
    _isAutoMode = !_isAutoMode;
    _saveAutoMode(_isAutoMode);
    notifyListeners();
  }

  ThemeColors _getThemeColors(AppThemeType type) { /* ... */ }
  Future<void> _loadSavedTheme() async { /* ... */ }
  Future<void> _saveTheme(AppThemeType type) async { /* ... */ }
}
```

### 3. Theme Definitions (Constants)

**Location:** `lib/theme/theme_definitions.dart`

| Theme | Primary | Background | Surface | Accent | Brightness |
|-------|---------|------------|---------|--------|------------|
| Cyber Blue | #0DA6F2 | #0A1114 | #162229 | #00F2FF | Dark |
| Red | #FF4D4D | #0A0A0A | #1A1A1A | #FF6B6B | Dark |
| Orange | #FFAB40 | #0A0A0A | #1A1510 | #FFD54F | Dark |
| Light | #0DA6F2 | #F5F5F5 | #FFFFFF | #00BCD4 | Light |

### 4. Updated AppTheme (Backward Compatibility)

**Location:** `lib/theme/app_theme.dart` (modified)

```dart
class AppTheme {
  // 动态颜色 - 从 ThemeProvider 获取
  static Color primary(BuildContext context) =>
      context.watch<ThemeProvider>().themeColors.primary;

  // 保留静态颜色供不依赖 Provider 的场景
  static const Color primaryStatic = Color(0xFF0DA6F2);
}
```

### 5. Persistence Service

**Location:** `lib/services/theme_storage_service.dart`

```dart
class ThemeStorageService {
  static const String _themeKey = 'app_theme_type';
  static const String _autoModeKey = 'app_auto_mode';

  static Future<AppThemeType> loadTheme() async { /* ... */ }
  static Future<void> saveTheme(AppThemeType type) async { /* ... */ }
  static Future<bool> loadAutoMode() async { /* ... */ }
  static Future<void> saveAutoMode(bool value) async { /* ... */ }
}
```

### 6. Sunrise/Sunset Auto-Switch Service

**Location:** `lib/services/sunrise_sunset_service.dart`

```dart
class SunriseSunsetService {
  /// 计算指定日期的日出/日落时间
  /// 返回是否应该使用深色主题
  static bool shouldUseDarkTheme() {
    // 获取当前位置（或使用默认位置）
    // 计算当前时间的日出日落
    // 返回: 现在 < 日出 或 现在 > 日落 → 深色主题
  }

  /// 启动定时检查（每小时或每分钟）
  static void startAutoCheck(Function callback) {
    // Timer.periodic 定时检查
    // 回调通知 ThemeProvider
  }
}
```

## Build Order

### Phase 1: Core Infrastructure

1. **theme_colors.dart** - Data model
   - No dependencies, pure data class
   - First to create

2. **theme_definitions.dart** - Static constants
   - Defines all 4 theme color sets
   - Depends on ThemeColors

3. **theme_storage_service.dart** - Persistence
   - Uses shared_preferences
   - No other dependencies

### Phase 2: Provider Implementation

4. **theme_provider.dart** - State management
   - Depends on theme_definitions and storage
   - Follows existing Provider patterns (see bluetooth_provider.dart reference)

### Phase 3: Integration

5. **app_theme.dart** - Update existing
   - Add dynamic color accessors
   - Maintain backward compatibility

6. **main.dart** - Register Provider
   - Add ThemeProvider to MultiProvider
   - Update MaterialApp theme:

```dart
// main.dart - Updated OBDDashboardApp
class OBDDashboardApp extends StatelessWidget {
  const OBDDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          theme: _buildThemeData(themeProvider),
          // ...
        );
      },
    );
  }

  ThemeData _buildThemeData(ThemeProvider provider) {
    final colors = provider.themeColors;
    return ThemeData(
      useMaterial3: true,
      brightness: colors.isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: colors.isDark ? Brightness.dark : Brightness.light,
        primary: colors.primary,
        onPrimary: Colors.white,
        secondary: colors.accentCyan,
        onSecondary: Colors.black,
        error: colors.accentRed,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
      ),
      scaffoldBackgroundColor: colors.background,
      fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
    );
  }
}
```

### Phase 4: Widget Updates

7. **Update existing widgets** to use dynamic colors
   - Replace `AppTheme.primaryStatic` with `AppTheme.primary(context)`
   - Or use `context.watch<ThemeProvider>().themeColors`

## Widget Access Patterns

### Pattern 1: Through AppTheme (Recommended for reusable widgets)

```dart
// In a widget's build method
Container(
  color: AppTheme.primary(context),
  child: Text(
    'Hello',
    style: TextStyle(color: AppTheme.textPrimary(context)),
  ),
)
```

### Pattern 2: Direct Provider Access (For complex components)

```dart
// In a widget's build method
final colors = context.watch<ThemeProvider>().themeColors;
Container(
  color: colors.primary,
  child: Text('Hello', style: TextStyle(color: colors.textPrimary)),
)
```

### Pattern 3: Consumer (For rebuild optimization)

```dart
Consumer<ThemeProvider>(
  builder: (context, themeProvider, _) {
    final colors = themeProvider.themeColors;
    return MyWidget(colors: colors);
  },
)
```

## Anti-Patterns to Avoid

### 1. Hardcoded Colors in Widgets

```dart
// BAD - hardcoded
Container(color: Color(0xFF0DA6F2))

// GOOD - dynamic
Container(color: AppTheme.primary(context))
```

### 2. Creating New ThemeData on Every Build

```dart
// BAD - creates new ThemeData every rebuild
@override
Widget build(BuildContext context) {
  return MaterialApp(
    theme: ThemeData(primaryColor: ...), // New instance each time
  );
}

// GOOD - reuse or use Consumer
@override
Widget build(BuildContext context) {
  return Consumer<ThemeProvider>(
    builder: (context, provider, _) {
      return MaterialApp(
        theme: _cachedThemeData, // Reuse
      );
    },
  );
}
```

### 3. Not Handling Brightness Changes

Always update both `colorScheme` and `scaffoldBackgroundColor` when switching between dark and light themes.

## Scalability Considerations

| Scenario | Approach |
|----------|----------|
| Add new theme | Add entry to theme_definitions.dart |
| Add theme-specific gradient | Extend ThemeColors with gradient colors |
| Add animation | Use AnimatedTheme widget wrapper |
| Multiple auto-rules | Extend SunriseSunsetService with rule engine |

## Sources

- Flutter official theming: [https://docs.flutter.dev/ui/themes](https://docs.flutter.dev/ui/themes) (HIGH confidence - official docs)
- Provider pattern reference: Project's `bluetooth_provider.dart` (HIGH confidence - existing code)
- Theme persistence: shared_preferences package (MEDIUM confidence - standard Flutter practice)
- Sunrise/sunset calculation: solar_calculator or sunrise_sunset_calc packages (MEDIUM confidence - common Flutter packages)
