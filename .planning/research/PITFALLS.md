# Domain Pitfalls: Multi-Theme System

**Domain:** Flutter multi-theme architecture for OBD Dashboard
**Researched:** 2026-03-14

## Critical Pitfalls

### Pitfall 1: Hardcoded Colors Throughout Widgets

**What goes wrong:** The codebase has extensive hardcoded `Color(0xFF...)` values scattered across 10+ widget files. Theme switching will have no effect on these elements.

**Why it happens:**
- Initial development used direct `Color()` literals for convenience
- Custom `AppTheme` class exists but is not used consistently
- Widgets like `side_stats_panel.dart`, `combined_gauge_card.dart`, `dashboard_screen.dart`, `logs_screen.dart` contain direct color references

**Consequences:**
- Theme switching appears broken - most UI remains in original cyberpunk dark colors
- Wasted implementation effort on theme system
- Inconsistent user experience across screens

**Prevention:**
1. **Before implementing themes**, run this grep to identify all hardcoded colors:
   ```bash
   grep -rn "Color(0xFF" lib/widgets lib/screens
   ```
2. Replace all hardcoded colors with theme-aware alternatives:
   - Use `Theme.of(context).colorScheme.primary` for Material components
   - Create theme extension: `AppTheme.of(context).primary` for custom widgets
   - Pass theme colors as parameters to StatelessWidgets

3. **Pattern for migration:**
   ```dart
   // Before (hardcoded)
   color: Color(0xFF0A1114),

   // After (theme-aware via extension)
   color: AppTheme.of(context).backgroundDark,
   // OR
   color: Theme.of(context).scaffoldBackgroundColor,
   ```

**Detection:**
- Run: `grep -rn "Color(0xFF" lib/ | grep -v "app_theme.dart"`
- Build each theme and visually verify every screen
- Automated test: switch themes programmatically and screenshot diff

**Phase mapping:** This is a **Phase 1 (Widget Migration)** issue - must be addressed before theme system implementation

---

### Pitfall 2: CustomPaint Gauges Ignore Theme Changes

**What goes wrong:** Gauge widgets (`combined_gauge_card.dart`, `speed_gauge_card.dart`, `rpm_gauge_card.dart`) use `CustomPaint` with hardcoded color values. These gauges are the core UI - if they don't change, the theme system feels broken.

**Evidence from codebase:**
```dart
// combined_gauge_card.dart lines 121-134, 168, 212, 250, 314
const Color(0xFF0A1114),  // background
const Color(0xFF1E293B),  // secondary
const Color(0xFFF44336),  // red warning
const Color(0xFFFF9800),  // orange
```

**Why it happens:** `CustomPaint.paint()` cannot access `BuildContext`, so `Theme.of(context)` doesn't work inside paint methods.

**Consequences:**
- Core OBD data display (speed, RPM) remains static
- User trust in theme switching erodes
- Most visible part of the app doesn't reflect theme

**Prevention:**
1. Pass colors as parameters to gauge widgets:
   ```dart
   class SpeedGaugeCard extends StatelessWidget {
     final Color primaryColor;
     final Color backgroundColor;
     final Color warningColor;
     // ...
   }
   ```
2. Use `ValueListenableBuilder` or `Consumer<ThemeProvider>` to rebuild gauges when theme changes:
   ```dart
   Consumer<ThemeProvider>(
     builder: (context, theme, _) => SpeedGaugeCard(
       primaryColor: theme.currentTheme.primary,
       backgroundColor: theme.currentTheme.background,
     ),
   )
   ```
3. Store theme colors in provider, pass to all gauge widgets

**Detection:**
- Manual: Switch to each theme, verify speed gauge, RPM gauge, all gauge cards
- Code review: Check all `CustomPaint` usages have color parameters

**Phase mapping:** **Phase 1 (Gauge Implementation)** - gauges need theme-aware refactor before general widget migration

---

### Pitfall 3: ThemeData Not Using Custom AppTheme Colors

**What goes wrong:** The `MaterialApp.theme` in `main.dart` uses basic `ColorScheme` colors, not the custom `AppTheme` colors. This creates two separate theme systems that don't sync.

**Evidence from main.dart (lines 104-114):**
```dart
theme: ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF0DA6F2),  // Duplicates AppTheme.primary
    surface: Color(0xFF162229),  // Duplicates AppTheme.surface
  ),
  scaffoldBackgroundColor: const Color(0xFF0A1114), // Duplicates AppTheme.backgroundDark
),
```

Meanwhile `app_theme.dart` has:
```dart
static const Color primary = Color(0xFF0DA6F2);
static const Color surface = Color(0xFF162229);
static const Color backgroundDark = Color(0xFF0A1114);
```

**Why it happens:** Developer copied values instead of referencing `AppTheme` class.

**Consequences:**
- Inconsistency between ThemeData colors and AppTheme colors
- Maintenance burden: changing primary requires updating 2+ files
- Theme extension cannot access AppTheme values

**Prevention:**
1. Use `AppTheme` constants in `ThemeData`:
   ```dart
   theme: ThemeData(
     colorScheme: ColorScheme.dark(
       primary: AppTheme.primary,
       surface: AppTheme.surface,
     ),
     scaffoldBackgroundColor: AppTheme.backgroundDark,
   ),
   ```
2. Create `ThemeExtension` to bundle custom colors:
   ```dart
   class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
     final Color cyberBlue;
     final Color accentCyan;
     // ...
   }
   ```

**Phase mapping:** **Phase 1 (Theme Data Setup)** - foundational fix before anything else

---

## Moderate Pitfalls

### Pitfall 4: Performance Impact on OBD Data Rendering

**What goes wrong:** ThemeProvider notifies ALL listeners on every change, potentially causing unnecessary widget rebuilds including OBD data widgets that don't need theme info.

**Why it happens:**
- Provider's `notifyListeners()` broadcasts to all consumers
- OBD data widgets may consume ThemeProvider indirectly
- High-frequency OBD updates (5Hz) + theme change = jank

**Consequences:**
- Frame drops during theme switch
- OBD data stuttering visible to user
- Poor riding experience (safety concern)

**Prevention:**
1. **Separate providers:** Keep ThemeProvider completely separate from OBD providers
2. **Use selectors:** For widgets that need both OBD data AND theme:
   ```dart
   // Bad - rebuilds on any provider change
   Consumer2<OBDDataProvider, ThemeProvider>(...)

   // Good - rebuilds only on specific property
   context.select<ThemeProvider, Color>(
     (theme) => theme.currentTheme.primary,
   );
   ```
3. **Isolate theme UI:** Wrap only theme-changing widgets in ThemeConsumer, not entire dashboard

**Phase mapping:** **Phase 3 (Performance Optimization)** - optimize after basic theming works

---

### Pitfall 5: System UI Brightness Desync

**What goes wrong:** System status bar and navigation bar don't match theme brightness, creating visual inconsistency especially on light themes.

**Evidence:** `SystemChrome.setEnabledSystemUIMode()` is called once at startup in `main.dart`, not updated on theme change.

**Why it happens:** Developer set system UI once, forgot to update on theme change.

**Consequences:**
- White status bar on dark theme = painful glare
- Dark status bar on light theme = hard to read
- Breaks immersive experience

**Prevention:**
1. Use `AnnotatedRegion` for dynamic system UI:
   ```dart
   AnnotatedRegion<SystemUiOverlayStyle>(
     value: theme.brightness == Brightness.dark
       ? SystemUiOverlayStyle.light
       : SystemUiOverlayStyle.dark,
     child: MaterialApp(...),
   )
   ```
2. Or update in ThemeProvider when theme changes:
   ```dart
   void setTheme(ThemeMode mode) {
     _themeMode = mode;
     SystemChrome.updateSettings(
       overlayStyle: mode == ThemeMode.dark
         ? SystemUiOverlayStyle.light
         : SystemUiOverlayStyle.dark,
     );
     notifyListeners();
   }
   ```

**Phase mapping:** **Phase 2 (Settings Page Integration)** - add when building settings page

---

### Pitfall 6: Auto Theme Flash on App Start

**What goes wrong:** App starts with default theme for 1-2 frames before saved preference loads, causing visible "flash" of wrong theme.

**Why it happens:** `shared_preferences` is async, but `MaterialApp` builds synchronously.

**Consequences:**
- Unprofessional visual glitch on every app launch
- User sees wrong theme briefly

**Prevention:**
1. **Option A - Synchronous cache:**
   ```dart
   // In ThemeProvider constructor
   ThemeProvider() : _cachedMode = _loadCachedSync() {
     // Uses getString from cached SharedPreferences if available
   }
   ```
2. **Option B - Splash screen:**
   ```dart
   class App extends StatefulWidget {
     @override
     State<App> createState() => _AppState();
   }

   class _AppState extends State<App> {
     ThemeMode? _initialMode;

     @override
     void initState() {
       super.initState();
       _loadTheme().then((mode) {
         setState(() => _initialMode = mode);
       });
     }

     @override
     Widget build(BuildContext context) {
       if (_initialMode == null) return SplashScreen();
       return MaterialApp(themeMode: _initialMode, ...);
     }
   }
   ```

**Phase mapping:** **Phase 1 (Theme Data Setup)** - implement before release

---

## Minor Pitfalls

### Pitfall 7: Location Permission for Sunrise/Sunset Auto-Switch

**What goes wrong:** Auto theme switching based on sunrise/sunset requires location, which may be denied or restricted.

**Why it happens:** Users granted location for BLE OBD, but may not realize it's needed for theme auto-switch.

**Prevention:**
1. Check location permission before enabling auto mode:
   ```dart
   Future<bool> _canEnableAutoMode() async {
     final status = await Permission.location.status;
     return status.isGranted;
   }
   ```
2. Show explanation dialog before requesting permission for this feature
3. Fallback gracefully: if permission denied, default to manual mode

**Phase mapping:** **Phase 4 (Auto-Switch Feature)** - handle in auto-switch implementation

---

### Pitfall 8: Incomplete Light Theme Palette

**What goes wrong:** Dark theme colors are designed, but light theme may lack equivalent colors for all use cases (e.g., glow effects, shadows).

**Why it happens:** Cyberpunk dark theme relies heavily on glow effects that don't translate to light mode.

**Prevention:**
1. Design full light theme palette before implementation
2. Consider disabling glow effects in light mode
3. Test all custom decorations in both themes

**Phase mapping:** **Phase 1 (Theme Design)** - create complete color palette for all themes

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Theme Infrastructure | ThemeData not using AppTheme constants | Use AppTheme.* in ThemeData, create ThemeExtension |
| Widget Migration | Hardcoded Color(0xFF...) missed | Grep all widget files before testing |
| Gauge Implementation | CustomPaint colors hardcoded | Pass colors as parameters, use Consumer |
| Settings Page | Auto mode without permission check | Verify location permission before enabling |
| System Integration | Status bar brightness wrong | Use AnnotatedRegion or update on theme change |
| App Startup | Theme flash | Use splash screen or cached sync load |

---

## Summary: Critical Path for Multi-Theme

1. **Phase 1: Foundation**
   - Fix main.dart ThemeData to use AppTheme constants
   - Create ThemeExtension for custom colors
   - Implement theme persistence with splash/flash prevention

2. **Phase 2: Widget Migration**
   - Migrate all hardcoded colors in widgets
   - Refactor gauges to accept color parameters
   - Visual testing on all themes

3. **Phase 3: Integration**
   - Add settings page with theme selector
   - Fix system UI brightness
   - Performance optimization with selectors

4. **Phase 4: Auto Features**
   - Implement sunrise/sunset auto-switch
   - Handle location permission gracefully
