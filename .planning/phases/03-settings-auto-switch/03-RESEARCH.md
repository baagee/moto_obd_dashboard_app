# Phase 3: Settings & Auto-Switch - Research

**Researched:** 2026-03-15
**Domain:** Flutter theme settings, location-based sunrise/sunset, system UI styling
**Confidence:** MEDIUM - Based on Flutter training knowledge, recommend verification during implementation

## Summary

Phase 3 implements the user-facing settings UI for theme selection and automatic theme switching based on sunrise/sunset times. This phase builds on the theme infrastructure from Phase 1 (ThemeProvider, ThemeColors, 4 themes) and widget migrations from Phase 2.

**Primary recommendation:** Create a SettingsScreen with theme selector, add geolocator for location-based sunrise/sunset calculation, and integrate SystemChrome.setSystemUIOverlayStyle for status bar sync.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| THME-09 | Settings page provides theme selector UI | Section: Settings Screen Pattern |
| THME-10 | User can choose from 4 themes | Section: Theme Selection Implementation |
| THME-11 | Theme switch takes effect immediately (no restart) | Section: Immediate Theme Switch |
| THME-12 | Auto-switch based on sunrise/sunset | Section: Sunrise/Sunset Auto-Switch |
| THME-13 | Use location to calculate sunrise/sunset time | Section: Location Services |
| THME-14 | After sunrise -> light theme, after sunset -> dark theme | Section: Auto-Switch Logic |
| THME-21 | Sync status bar brightness on theme switch | Section: Status Bar Integration |
| THME-22 | Light theme = dark status bar, dark theme = light status bar | Section: Status Bar Integration |

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Using Provider for theme state management (matches existing codebase)
- shared_preferences for persistence (per Phase 1 research)
- 4 themes: Cyber Blue, Red, Orange, Light

### Claude's Discretion
- Sunrise/sunset calculation library choice
- Settings screen UI design
- Status bar integration approach

### Deferred Ideas (OUT OF SCOPE)
- Dynamic theme (based on ambient light sensor)
- Theme gradient animation transitions
- User custom themes
- Multi-device theme sync

---

## Standard Stack

### Core Dependencies
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| geolocator | ^12.0.0 | Get device location for sunrise/sunset | Standard Flutter location package |
| sunrise_sunset_calc | ^1.0.0 | Calculate sunrise/sunset times | Lightweight calculation library |

### Existing Dependencies (Already in pubspec.yaml)
| Library | Purpose |
|---------|---------|
| provider | Theme state management (existing) |
| shared_preferences | Theme preference persistence (existing) |
| permission_handler | Location permission requests (existing) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| sunrise_sunset_calc | Manual calculation with solar formulas | sunrise_sunset_calc is simpler and well-tested |
| geolocator | location or flutter_location | geolocator is most popular and maintained |

**Installation:**
```bash
flutter pub add geolocator sunrise_sunset_calc
```

---

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── screens/
│   └── settings_screen.dart      # NEW - Settings page with theme selector
├── services/
│   └── sunrise_sunset_service.dart # NEW - Location + sunrise/sunset calculation
├── providers/
│   └── theme_provider.dart       # MODIFY - Add auto-switch methods
└── main.dart                     # MODIFY - Add status bar sync
```

### Pattern 1: Settings Screen with Theme Selector
**What:** A settings page that displays theme options and allows user selection
**When to use:** When user needs to manually select theme or configure auto-switch
**Example:**
```dart
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          backgroundColor: themeProvider.currentColors.backgroundDark,
          body: ListView(
            children: [
              // Theme selection section
              _ThemeSelector(
                currentTheme: themeProvider.currentTheme,
                onThemeSelected: (theme) => themeProvider.setTheme(theme),
                colors: themeProvider.currentColors,
              ),
              // Auto-switch toggle
              SwitchListTile(
                title: Text('Auto Theme Switch'),
                value: themeProvider.isAutoSwitchEnabled,
                onChanged: (value) => themeProvider.setAutoSwitch(value),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

### Pattern 2: Sunrise/Sunset Service
**What:** Service that gets location and calculates sunrise/sunset times
**When to use:** When implementing automatic theme switching based on time of day
**Example:**
```dart
class SunriseSunsetService {
  final Geolocator _geolocator = Geolocator();

  Future<SunriseSunsetTimes?> getSunriseSunsetTimes() async {
    // Get current location
    final position = await _geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );

    // Calculate sunrise/sunset
    final sunriseSunset = SunriseSunset.calculate(
      latitude: position.latitude,
      longitude: position.longitude,
      date: DateTime.now(),
    );

    return sunriseSunset;
  }
}
```

### Pattern 3: Status Bar Sync
**What:** Sync status bar brightness with theme
**When to use:** On app startup and when theme changes
**Example:**
```dart
// In main.dart or app root
void _updateStatusBar(ThemeProvider themeProvider) {
  final isDark = themeProvider.isDarkMode;
  SystemChrome.setSystemUIOverlayStyle(
    isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
  );
}
```

### Anti-Patterns to Avoid
- **Hardcoding status bar style**: Should dynamically change based on theme
- **Blocking UI for location**: Use low-accuracy location with timeout
- **Frequent location updates**: Cache sunrise/sunset times, update every few hours

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sunrise/sunset calculation | Custom solar formulas | sunrise_sunset_calc | Well-tested, handles edge cases |
| Location access | Raw platform channels | geolocator | Handles permissions, battery optimization |
| Status bar styling | Platform-specific code | SystemChrome.setSystemUIOverlayStyle | Flutter-native, works on both platforms |

**Key insight:** Location and sunrise/sunset calculations have many edge cases (timezone, latitude extremes, daylight saving time) that are already handled by dedicated libraries.

---

## Common Pitfalls

### Pitfall 1: Location Permission Denied
**What goes wrong:** Auto-switch fails silently when location permission is denied
**Why it happens:** User denies location permission, app doesn't handle gracefully
**How to avoid:** Check permission status before enabling auto-switch, show explanation dialog
**Warning signs:** Auto-switch toggle appears but theme never changes automatically

### Pitfall 2: Status Bar Not Updating
**What goes wrong:** Status bar stays in previous theme's style after manual switch
**Why it happens:** SystemChrome.setSystemUIOverlayStyle called only on app startup
**How to avoid:** Call status bar update in ThemeProvider.setTheme() method
**Warning signs:** White status bar on dark theme or vice versa

### Pitfall 3: Auto-Switch Causes Frequent Theme Changes
**What goes wrong:** Theme changes multiple times around sunrise/sunset boundary
**Why it happens:** No hysteresis or debounce on time check
**How to avoid:** Check time against sunrise/sunset with a buffer (e.g., 30 minutes)
**Warning signs:** Theme flickers at dawn/dusk

### Pitfall 4: Light Theme Missing for Auto-Switch
**What goes wrong:** Auto-switch only cycles through dark themes, never reaches light
**Why it happens:** Logic incorrectly maps light theme to "dark" or vice versa
**How to avoid:** Explicitly check: isDarkMode = currentTheme != AppThemeType.light
**Warning signs:** Light theme only selectable manually

---

## Code Examples

### ThemeProvider Extended with Auto-Switch
```dart
// Source: Based on existing ThemeProvider pattern from lib/providers/theme_provider.dart
class ThemeProvider extends ChangeNotifier {
  static const String _autoSwitchKey = 'auto_theme_switch';

  bool _isAutoSwitchEnabled = false;
  bool get isAutoSwitchEnabled => _isAutoSwitchEnabled;

  // Auto-switch setter
  Future<void> setAutoSwitch(bool enabled) async {
    _isAutoSwitchEnabled = enabled;
    await _prefs?.setBool(_autoSwitchKey, enabled);
    notifyListeners();
  }

  // Check and apply auto-switch
  Future<void> checkAutoSwitch() async {
    if (!_isAutoSwitchEnabled) return;

    final now = DateTime.now();
    final times = await _sunriseSunsetService.getSunriseSunsetTimes();
    if (times == null) return;

    // Apply theme based on time
    final isDaytime = now.isAfter(times.sunrise) && now.isBefore(times.sunset);
    final targetTheme = isDaytime ? AppThemeType.light : AppThemeType.cyberBlue;

    if (_currentTheme != targetTheme) {
      await setTheme(targetTheme);
    }
  }
}
```

### Status Bar Integration in main.dart
```dart
// Source: Standard Flutter pattern
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // ... other providers
      ],
      child: const OBDDashboardApp(),
    ),
  );
}

class OBDDashboardApp extends StatefulWidget {
  const OBDDashboardApp({super.key});

  @override
  State<OBDDashboardApp> createState() => _OBDDashboardAppState();
}

class _OBDDashboardAppState extends State<OBDDashboardApp> {
  @override
  void initState() {
    super.initState();
    // Initialize theme and status bar
    _initializeTheme();
  }

  Future<void> _initializeTheme() async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.initialize();
    _updateStatusBar(themeProvider);
  }

  void _updateStatusBar(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? const SystemUiOverlayStyle(
              statusBarBrightness: Brightness.dark,
              statusBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarBrightness: Brightness.light,
              statusBarIconBrightness: Brightness.dark,
            ),
    );
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded theme colors | ThemeProvider + ThemeColors | Phase 1 | Dynamic theme switching now possible |
| Static theme in main.dart | Dynamic ThemeData in main.dart | Phase 1 | Theme can change at runtime |
| Manual theme in each widget | Consumer<ThemeProvider> pattern | Phase 2 | All widgets respond to theme changes |
| No settings UI | SettingsScreen with selector | Phase 3 (this phase) | User can select theme manually |
| No auto-switch | Sunrise/sunset based auto-switch | Phase 3 (this phase) | Theme follows day/night cycle |
| No status bar sync | SystemChrome.setSystemUIOverlayStyle | Phase 3 (this phase) | Status bar matches theme |

**Deprecated/outdated:**
- Android StatusBarColor (deprecated, replaced by SystemUiOverlayStyle)
- location package (replaced by geolocator)

---

## Open Questions

1. **How to handle location permission denial gracefully?**
   - What we know: permission_handler is already in use for Bluetooth
   - What's unclear: Should auto-switch be hidden or show a "requires permission" state?
   - Recommendation: Show toggle but disable with explanation when permission denied

2. **How often to refresh sunrise/sunset times?**
   - What we know: Times change slightly each day
   - What's unclear: Real-time refresh needed or cached calculation sufficient?
   - Recommendation: Cache daily, refresh on date change or app resume

3. **Which dark theme to use for auto-switch at night?**
   - What we know: 3 dark themes available (cyberBlue, red, orange)
   - What's unclear: User preference or default to cyberBlue?
   - Recommendation: Default to cyberBlue, consider adding preference in v2

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter test (built-in) |
| Config file | none required |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --reporter expanded` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THME-09 | Settings screen shows theme selector | Widget | `flutter test test/settings_test.dart` | Wave 0 - create |
| THME-10 | Selecting theme updates app theme | Unit | `flutter test test/theme_provider_test.dart` | Wave 0 - create |
| THME-11 | Theme change applies immediately | Unit | `flutter test test/theme_provider_test.dart` | Wave 0 - create |
| THME-12 | Auto-switch toggles correctly | Unit | `flutter test test/theme_provider_test.dart` | Wave 0 - create |
| THME-13 | Location service gets coordinates | Unit | `flutter test test/sunrise_sunset_service_test.dart` | Wave 0 - create |
| THME-14 | Auto-switch applies correct theme by time | Unit | `flutter test test/sunrise_sunset_service_test.dart` | Wave 0 - create |
| THME-21 | Status bar updates on theme change | Manual | N/A - requires device | N/A |
| THME-22 | Light/dark status bar matches theme | Manual | N/A - requires device | N/A |

### Sampling Rate
- **Per task commit:** `flutter analyze` (quick syntax check)
- **Per wave merge:** `flutter test` (run all tests)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/settings_test.dart` - covers THME-09, THME-10
- [ ] `test/theme_provider_test.dart` - covers THME-10, THME-11, THME-12, THME-14
- [ ] `test/sunrise_sunset_service_test.dart` - covers THME-13, THME-14

---

## Sources

### Primary (HIGH confidence)
- Flutter SDK documentation - SystemChrome.setSystemUIOverlayStyle
- geolocator package documentation (pub.dev)
- sunrise_sunset_calc package documentation (pub.dev)

### Secondary (MEDIUM confidence)
- Existing ThemeProvider pattern from lib/providers/theme_provider.dart
- Existing Consumer<ThemeProvider> usage from Phase 2

### Tertiary (LOW confidence)
- General Flutter best practices for theme and status bar (recommend verification during implementation)

---

## Metadata

**Confidence breakdown:**
- Standard Stack: MEDIUM - geolocator/sunrise_sunset_calc packages are standard but not verified with Context7
- Architecture: HIGH - Pattern matches existing project conventions (Provider, Consumer)
- Pitfalls: MEDIUM - Based on common Flutter patterns, recommend validation during implementation

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (30 days for stable Flutter patterns)
