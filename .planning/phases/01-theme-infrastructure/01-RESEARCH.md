# Phase 1: Theme Infrastructure - Research

**Researched:** 2026-03-14
**Domain:** Flutter Theme System with Provider State Management
**Confidence:** HIGH

## Summary

Phase 1 requires building a theme infrastructure foundation with ThemeProvider, ThemeColors model, 4 theme definitions, and persistence layer using shared_preferences. The current codebase has a static theme (AppTheme class with hardcoded colors) that needs to be converted to a dynamic theming system.

**Primary recommendation:** Create ThemeColors data model with copyWith, define 4 themes (Cyber Blue, Red, Orange, Light), implement ThemeProvider extending ChangeNotifier following existing Provider patterns, and use shared_preferences for persistence with theme key.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| THME-01 | Create ThemeColors data class | Model pattern follows existing OBDData model - data class with copyWith |
| THME-02 | Define 4 themes: Cyber Blue, Red, Orange, Light | Colors specified in REQUIREMENTS.md |
| THME-03 | Implement ThemeProvider (extends ChangeNotifier) | Follow existing Provider pattern from LogProvider |
| THME-04 | Use shared_preferences for persistence | Need to add dependency to pubspec.yaml |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| provider | ^6.1.1 | State management | Already in project, follows CLAUDE.md guidelines |
| shared_preferences | ^2.2.0 | Theme persistence | Standard Flutter preference storage |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter | SDK | ThemeData, ColorScheme | Core theming infrastructure |

**Installation:**
```bash
flutter pub add shared_preferences
```

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── models/
│   └── theme_colors.dart          # ThemeColors data class (NEW)
├── providers/
│   └── theme_provider.dart       # ThemeProvider (NEW)
├── theme/
│   ├── app_theme.dart            # Existing - modify to use dynamic colors
│   └── theme_definitions.dart    # 4 theme definitions (NEW)
└── main.dart                     # Modify to use ThemeProvider
```

### Pattern 1: ThemeColors Data Model
**What:** Immutable data class containing all color tokens for a theme
**When to use:** Required for THME-01, defines all colors that can change per theme
**Example:**
```dart
// Following project conventions from CLAUDE.md - data class with copyWith
class ThemeColors {
  final Color primary;
  final Color backgroundDark;
  final Color surface;
  final Color accentCyan;
  final Color accentRed;
  final Color accentOrange;
  final Color accentGreen;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Primary accent - changes per theme
  final Color accent;

  const ThemeColors({
    required this.primary,
    required this.backgroundDark,
    required this.surface,
    required this.accentCyan,
    required this.accentRed,
    required this.accentOrange,
    required this.accentGreen,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
  });

  ThemeColors copyWith({
    Color? primary,
    Color? backgroundDark,
    Color? surface,
    Color? accentCyan,
    Color? accentRed,
    Color? accentOrange,
    Color? accentGreen,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
  }) {
    return ThemeColors(
      primary: primary ?? this.primary,
      backgroundDark: backgroundDark ?? this.backgroundDark,
      surface: surface ?? this.surface,
      accentCyan: accentCyan ?? this.accentCyan,
      accentRed: accentRed ?? this.accentRed,
      accentOrange: accentOrange ?? this.accentOrange,
      accentGreen: accentGreen ?? this.accentGreen,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
    );
  }
}
```

### Pattern 2: ThemeProvider (ChangeNotifier)
**What:** State management for current theme, follows existing Provider pattern
**When to use:** Required for THME-03, manages theme state and persistence
**Example:**
```dart
// Follows pattern from LogProvider in existing codebase
enum AppThemeType {
  cyberBlue,
  red,
  orange,
  light,
}

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  AppThemeType _currentTheme = AppThemeType.cyberBlue;
  bool _isInitialized = false;

  AppThemeType get currentTheme => _currentTheme;
  bool get isInitialized => _isInitialized;

  ThemeColors get currentColors => _getThemeColors(_currentTheme);
  bool get isDarkMode => _currentTheme != AppThemeType.light;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    if (themeName != null) {
      _currentTheme = AppThemeType.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => AppThemeType.cyberBlue,
      );
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setTheme(AppThemeType theme) async {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme.name);
      notifyListeners();
    }
  }

  ThemeColors _getThemeColors(AppThemeType type) {
    switch (type) {
      case AppThemeType.cyberBlue:
        return ThemeColors.cyberBlue;
      case AppThemeType.red:
        return ThemeColors.red;
      case AppThemeType.orange:
        return ThemeColors.orange;
      case AppThemeType.light:
        return ThemeColors.light;
    }
  }
}
```

### Pattern 3: Theme Definitions
**What:** Static ThemeColors instances for each theme type
**When to use:** Required for THME-05 through THME-08
**Example:**
```dart
// In theme_definitions.dart
class ThemeColors {
  // ... (data class as shown above)

  // Cyber Blue theme - THME-05
  static const ThemeColors cyberBlue = ThemeColors(
    primary: Color(0xFF0DA6F2),
    backgroundDark: Color(0xFF0A1114),
    surface: Color(0xFF162229),
    accentCyan: Color(0xFF00F2FF),
    accentRed: Color(0xFFFF4D4D),
    accentOrange: Color(0xFFFFAB40),
    accentGreen: Color(0xFF00E676),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),
    accent: Color(0xFF0DA6F2),  // Primary accent for this theme
  );

  // Red theme - THME-06
  static const ThemeColors red = ThemeColors(
    primary: Color(0xFFFF4D4D),
    backgroundDark: Color(0xFF0A1114),
    surface: Color(0xFF162229),
    accentCyan: Color(0xFF00F2FF),
    accentRed: Color(0xFFFF4D4D),
    accentOrange: Color(0xFFFFAB40),
    accentGreen: Color(0xFF00E676),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),
    accent: Color(0xFFFF4D4D),  // Red accent
  );

  // Orange theme - THME-07
  static const ThemeColors orange = ThemeColors(
    primary: Color(0xFFFFAB40),
    backgroundDark: Color(0xFF0A1114),
    surface: Color(0xFF162229),
    accentCyan: Color(0xFF00F2FF),
    accentRed: Color(0xFFFF4D4D),
    accentOrange: Color(0xFFFFAB40),
    accentGreen: Color(0xFF00E676),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),
    accent: Color(0xFFFFAB40),  // Orange accent
  );

  // Light theme - THME-08
  static const ThemeColors light = ThemeColors(
    primary: Color(0xFF0DA6F2),
    backgroundDark: Color(0xFFFFFFFF),
    surface: Color(0xFFF3F4F6),
    accentCyan: Color(0xFF00A0CC),
    accentRed: Color(0xFFDC2626),
    accentOrange: Color(0xFFF59E0B),
    accentGreen: Color(0xFF10B981),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF9CA3AF),
    accent: Color(0xFF0DA6F2),  // Blue accent
  );
}
```

### Pattern 4: AppTheme Integration
**What:** Modify existing AppTheme to use dynamic colors from ThemeProvider
**When to use:** Integration with existing theme system
**Example:**
```dart
// Modified app_theme.dart - uses colors from ThemeProvider
class AppTheme {
  // Static methods that accept ThemeColors parameter
  static BoxDecoration surfaceBorder(ThemeColors colors, {
    Color? borderColor,
    double opacity = 0.2,
  }) {
    return BoxDecoration(
      color: colors.surface.withOpacity(0.5),
      border: Border.all(
        color: (borderColor ?? colors.primary).withOpacity(opacity),
        width: 1,
      ),
      borderRadius: BorderRadius.circular(12),
    );
  }

  static List<BoxShadow> glowShadow(ThemeColors colors, Color color, {
    double blur = 15,
    double opacity = 0.2,
  }) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: blur,
        spreadRadius: 0,
      ),
    ];
  }
}
```

### Anti-Patterns to Avoid

- **Hardcoding colors in widgets:** All widgets should consume colors from ThemeProvider via Consumer<ThemeProvider>
- **Using AppTheme static constants directly:** After migration, all colors should come from ThemeColors
- **Blocking UI on theme load:** ThemeProvider.initialize() should be non-blocking or handled gracefully

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Theme persistence | Custom file-based storage | shared_preferences | Standard Flutter solution, already used in many apps |
| Theme state management | Custom singleton pattern | Provider (ChangeNotifier) | Matches existing codebase patterns |
| Color theming | Manual ThemeData rebuilding | Flutter's built-in Theme system | Efficient, well-tested |

**Key insight:** Flutter's ThemeData and ColorScheme provide efficient theming. Provider handles state. shared_preferences handles persistence. No custom solutions needed.

## Common Pitfalls

### Pitfall 1: Not Notifying on Theme Change
**What goes wrong:** Theme changes but UI doesn't update
**Why it happens:** Forgetting to call notifyListeners() after changing theme
**How to avoid:** Always call notifyListeners() in setTheme() method
**Warning signs:** UI stuck on old theme after user selection

### Pitfall 2: SharedPreferences Not Initialized
**What goes wrong:** Theme fails to load on app start
**Why it happens:** Accessing SharedPreferences before Flutter bindings initialized
**How to avoid:** Call ThemeProvider.initialize() after WidgetsFlutterBinding.ensureInitialized()
**Warning signs:** Exception on first app launch

### Pitfall 3: ThemeColors Not Updating in Build Context
**What goes wrong:** Widgets rebuild but show old colors
**Why it happens:** Not using Consumer<ThemeProvider> or context.watch<ThemeProvider>()
**How to avoid:** Always use Consumer or context.watch to access theme in widgets
**Warning signs:** Inconsistent colors across widgets after theme switch

## Code Examples

### Registering ThemeProvider in main.dart
```dart
// Source: Based on existing MultiProvider setup in main.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ... existing orientation and UI setup

  runApp(
    MultiProvider(
      providers: [
        // ... existing providers
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: const OBDDashboardApp(),
    ),
  );
}
```

### Dynamic ThemeData in MaterialApp
```dart
// Source: Based on existing MaterialApp in main.dart
class OBDDashboardApp extends StatelessWidget {
  const OBDDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final colors = themeProvider.currentColors;
        final isDark = themeProvider.isDarkMode;

        return MaterialApp(
          title: 'CYBER-CYCLE OBD',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: isDark ? Brightness.dark : Brightness.light,
            fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
            colorScheme: ColorScheme.dark(
              primary: colors.primary,
              surface: colors.surface,
              error: colors.accentRed,
            ),
            scaffoldBackgroundColor: colors.backgroundDark,
          ),
          home: const MainContainer(),
        );
      },
    );
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Static AppTheme class | Dynamic ThemeProvider + ThemeColors | Phase 1 | Enables runtime theme switching |
| Hardcoded colors in widgets | Consumer<ThemeProvider> pattern | Phase 2 | Enables theme consistency |
| No persistence | shared_preferences persistence | Phase 1 | Remembers user theme preference |

**Deprecated/outdated:**
- Static color constants in AppTheme (being replaced by ThemeColors model)

## Open Questions

1. **Should ThemeProvider be initialized in parallel with other providers?**
   - What we know: Current providers use lazy initialization in MultiProvider
   - What's unclear: Performance impact of sequential vs parallel initialization
   - Recommendation: Use lazy initialization (current pattern), initialize ThemeProvider early in app startup

2. **How to handle theme transition animation?**
   - What we know: REQUIREMENTS.md explicitly excludes theme gradient animation
   - What's unclear: N/A - out of scope per project decisions
   - Recommendation: No animation, immediate theme switch

3. **Should opacity variants be in ThemeColors?**
   - What we know: Current AppTheme has primary60, primary30, etc.
   - What's unclear: Should these be computed or stored?
   - Recommendation: Keep in ThemeColors for efficiency, compute once on theme change

## Validation Architecture

> Skip this section entirely if workflow.nyquist_validation is explicitly set to false in .planning/config.json. If the key is absent, treat as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none — Flutter default |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --reporter expanded` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THME-01 | ThemeColors data class with copyWith | unit | `flutter test test/models/theme_colors_test.dart` | No - Wave 0 |
| THME-02 | 4 theme definitions exist | unit | `flutter test test/theme/theme_definitions_test.dart` | No - Wave 0 |
| THME-03 | ThemeProvider manages state | unit | `flutter test test/providers/theme_provider_test.dart` | No - Wave 0 |
| THME-04 | Theme persists across app restart | integration | `flutter test test/providers/theme_provider_persistence_test.dart` | No - Wave 0 |
| THME-05 | Cyber Blue theme colors correct | unit | `flutter test test/theme/theme_definitions_test.dart` | No - Wave 0 |
| THME-06 | Red theme colors correct | unit | `flutter test test/theme/theme_definitions_test.dart` | No - Wave 0 |
| THME-07 | Orange theme colors correct | unit | `flutter test test/theme/theme_definitions_test.dart` | No - Wave 0 |
| THME-08 | Light theme colors correct | unit | `flutter test test/theme/theme_definitions_test.dart` | No - Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test` (quick)
- **Per wave merge:** `flutter test --reporter expanded` (full)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/models/theme_colors_test.dart` — covers THME-01
- [ ] `test/theme/theme_definitions_test.dart` — covers THME-02, THME-05-08
- [ ] `test/providers/theme_provider_test.dart` — covers THME-03
- [ ] `test/providers/theme_provider_persistence_test.dart` — covers THME-04

## Sources

### Primary (HIGH confidence)
- Flutter official docs - ThemeData and ColorScheme
- Existing codebase - Provider patterns from LogProvider, OBDDataProvider
- Existing codebase - AppTheme class structure

### Secondary (MEDIUM confidence)
- Flutter Provider package documentation
- shared_preferences package documentation

### Tertiary (LOW confidence)
- N/A

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH - Using established Flutter/Provider patterns already in codebase
- Architecture: HIGH - Follows exact patterns from existing providers
- Pitfalls: MEDIUM - Based on common Flutter theming issues

**Research date:** 2026-03-14
**Valid until:** 30 days (stable Flutter theming APIs)
