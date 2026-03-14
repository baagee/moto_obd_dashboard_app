# Phase 2: Widget Migration - Research

**Researched:** 2026-03-15
**Domain:** Flutter Widget Theme Integration with Provider
**Confidence:** HIGH

## Summary

Phase 2 requires refactoring all widgets to use dynamic theme colors from ThemeProvider instead of hardcoded static colors from AppTheme. Phase 1 completed the theme infrastructure (ThemeProvider, ThemeColors model, 4 themes). Now these must be integrated into widgets. The main challenge is that many widgets use AppTheme static constants (e.g., AppTheme.primary, AppTheme.accentCyan, AppTheme.backgroundDark30) which must be replaced with Consumer<ThemeProvider> to access dynamic colors.

**Primary recommendation:** Wrap widgets with Consumer<ThemeProvider> to access themeProvider.currentColors, then pass ThemeColors to custom painters and use colors directly in widget build methods. Migrate in order: screens first, then common components.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| THME-15 | All widgets use dynamic colors (non-hardcoded) | Pattern: Consumer<ThemeProvider> to get currentColors |
| THME-16 | DashboardScreen applies theme colors | DashboardScreen uses Container with hardcoded Color(0xFF0A1114) |
| THME-17 | LogsScreen applies theme colors | Needs migration |
| THME-18 | BluetoothScanScreen applies theme colors | Needs migration |
| THME-19 | SettingsScreen applies theme colors | SettingsScreen doesn't exist yet (Phase 3) |
| THME-20 | Common components apply theme colors | cyber_button, side_stats_panel, combined_gauge_card, etc. |

## User Constraints (from CONTEXT.md)

This phase has no CONTEXT.md file. User constraints come from REQUIREMENTS.md and previous phase decisions.

### Key Constraints
- Must use Provider pattern (existing codebase constraint from CLAUDE.md)
- ThemeProvider already implemented in Phase 1
- No custom solutions - use existing ThemeProvider infrastructure
- Consumer<ThemeProvider> is the standard way to access theme in widgets

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| provider | ^6.1.1 | State management | Already in project, follows CLAUDE.md guidelines |
| ThemeColors | (Phase 1) | Color model | Already implemented |
| ThemeProvider | (Phase 1) | Theme state | Already implemented |

### Migration Pattern
| Pattern | Purpose | When to Use |
|---------|---------|-------------|
| Consumer<ThemeProvider> | Access theme in widget | All widgets needing dynamic colors |
| ThemeColors parameter | Pass colors to painters | CustomPainter subclasses |

## Architecture Patterns

### Pattern 1: Consumer Wrapper for StatelessWidget
**What:** Wrap widget with Consumer<ThemeProvider> to access theme colors
**When to use:** Simple widgets with single color usage
**Example:**
```dart
// BEFORE: Hardcoded colors
class SideStatsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.surfaceBorder(),
      // ...
    );
  }
}

// AFTER: Dynamic colors via Consumer
class SideStatsPanel extends StatelessWidget {
  const SideStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;
        return Container(
          decoration: AppTheme.surfaceBorderWithColors(
            colors,
            borderColor: colors.primary,
          ),
          // ...
        );
      },
    );
  }
}
```

### Pattern 2: CustomPainter with ThemeColors Parameter
**What:** Pass ThemeColors to CustomPainter constructor
**When to use:** Complex painters that need theme colors (CombinedGaugePainter)
**Example:**
```dart
// BEFORE: AppTheme static colors in painter
class CombinedGaugePainter extends CustomPainter {
  void _drawRPMProgress(Canvas canvas, Offset center, double radius) {
    Color color = AppTheme.primary; // Hardcoded
    // ...
  }
}

// AFTER: ThemeColors passed to painter
class CombinedGaugePainter extends CustomPainter {
  final ThemeColors colors; // Add this

  CombinedGaugePainter({
    required this.rpm,
    required this.speed,
    required this.gear,
    required this.colors, // Add this
  });

  void _drawRPMProgress(Canvas canvas, Offset center, double radius) {
    Color color = colors.primary; // Dynamic
    // ...
  }
}

// Widget passes colors to painter
class CombinedGaugeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;
        return Consumer<OBDDataProvider>(
          builder: (context, obdProvider, child) {
            return CustomPaint(
              painter: CombinedGaugePainter(
                rpm: obdProvider.data.rpm,
                speed: obdProvider.data.speed,
                gear: obdProvider.data.gear,
                colors: colors, // Pass colors
              ),
            );
          },
        );
      },
    );
  }
}
```

### Pattern 3: Multi-Provider Nesting
**What:** Nest multiple Consumer widgets for providers that need colors
**When to use:** Widgets that need both ThemeProvider and another provider (e.g., OBDDataProvider)
**Example:**
```dart
class TelemetryChartCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;
        return Consumer<OBDDataProvider>(
          builder: (context, obdProvider, child) {
            // Use both colors and obdProvider.data
            return Container(
              decoration: AppTheme.surfaceBorderWithColors(
                colors,
                borderColor: colors.primary,
              ),
              // ...
            );
          },
        );
      },
    );
  }
}
```

### Pattern 4: Wrap Existing Widget with Consumer
**What:** Add Consumer wrapper without changing widget's internal structure
**When to use:** Quick migration of widgets with clear color usage
**Example:**
```dart
// DashboardScreen - wrap with Consumer to get colors
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;
        return Container(
          decoration: BoxDecoration(
            color: colors.backgroundDark, // Use dynamic color
          ),
          child: const Padding(
            // ... existing content
          ),
        );
      },
    );
  }
}
```

### Anti-Patterns to Avoid

- **Not wrapping with Consumer:** Widget won't rebuild on theme change
- **Using AppTheme constants:** These are static, don't change with theme
- **Creating new Consumer per small change:** More efficient to use single Consumer and extract colors once
- **Passing context to CustomPainter:** Bad practice - painters don't have BuildContext

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Theme access | Manual theme lookup | Consumer<ThemeProvider> | Built-in, efficient |
| Painter colors | Static AppTheme | ThemeColors parameter | Enables dynamic theming |
| Color opacity variants | Runtime withOpacity | Precomputed in ThemeColors | Performance |

**Key insight:** The ThemeColors model from Phase 1 doesn't include opacity variants (e.g., primary30, primary60). Either add these to ThemeColors, or use withOpacity() at runtime. For performance, precompute in ThemeColors is better.

## Common Pitfalls

### Pitfall 1: Nested Provider Performance
**What goes wrong:** Multiple nested Consumer widgets cause excessive rebuilds
**Why it happens:** Each Consumer rebuilds its child on notifyListeners()
**How to avoid:** Use single Consumer, extract colors once, pass to children
**Warning signs:** Slow theme switching, janky animations

### Pitfall 2: CustomPainter Not Rebuilding
**What goes wrong:** Painter doesn't update when theme changes
**Why it happens:** painter is created once, doesn't have access to theme
**How to avoid:** Pass ThemeColors to painter constructor, trigger repaint on theme change
**Warning signs:** Colors stuck on old theme in gauge/chart widgets

### Pitfall 3: Using Static AppTheme in Build Method
**What goes wrong:** Widget shows old colors after theme switch
**Why it happens:** AppTheme.primary is static const, never changes
**How to avoid:** Always use colors from Consumer<ThemeProvider>
**Warning signs:** Mixed old/new colors in UI after theme switch

### Pitfall 4: Missing Colors in ThemeColors Model
**What goes wrong:** Need a color that doesn't exist in ThemeColors
**Why it happens:** ThemeColors has basic tokens but not all AppTheme variants
**How to avoid:** Add missing colors to ThemeColors or compute with opacity

## Code Examples

### Example 1: Migrating DashboardScreen
```dart
// Source: Based on existing dashboard_screen.dart
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;
        return Container(
          decoration: BoxDecoration(
            color: colors.backgroundDark,  // Changed from Color(0xFF0A1114)
          ),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(flex: 2, child: SideStatsPanel()),
                SizedBox(width: 8),
                Expanded(flex: 4, child: CombinedGaugeCard()),
                SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(flex: 1, child: TelemetryChartCard()),
                      SizedBox(height: 8),
                      Expanded(flex: 2, child: RidingEventsPanel()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

### Example 2: Migrating CyberButton
```dart
// Source: Based on existing cyber_button.dart
class CyberButton extends StatelessWidget {
  // ... existing constructor and properties

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;
        return SizedBox(
          width: width,
          height: height,
          child: GestureDetector(
            onTap: isLoading ? null : onPressed,
            child: _buildButton(colors),
          ),
        );
      },
    );
  }

  Widget _buildButton(ThemeColors colors) {
    switch (type) {
      case CyberButtonType.primary:
        return _buildPrimaryButton(colors);
      // ... other cases
    }
  }

  Widget _buildPrimaryButton(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.primary,  // Changed from AppTheme.primary
        borderRadius: BorderRadius.circular(5),
        boxShadow: AppTheme.glowShadowWithColors(colors, colors.primary, blur: 10),
      ),
      child: _buildContent(colors.textPrimary),
    );
  }
}
```

### Example 3: Migrating CombinedGaugeCard with Painter
```dart
// Source: Based on existing combined_gauge_card.dart
class CombinedGaugeCard extends StatelessWidget {
  const CombinedGaugeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;
        return Consumer<OBDDataProvider>(
          builder: (context, obdProvider, child) {
            final data = obdProvider.data;
            return Container(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: CombinedGaugePainter(
                      rpm: data.rpm,
                      speed: data.speed,
                      gear: data.gear,
                      colors: colors,  // Pass theme colors
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
```

## Widget Migration Order

Based on REQUIREMENTS.md (THME-15 through THME-20):

| Priority | Widgets | Reason |
|----------|---------|--------|
| 1 | DashboardScreen, LogsScreen, BluetoothScanScreen | Screens (THME-16, 17, 18) |
| 2 | SideStatsPanel, TelemetryChartCard, RidingEventsPanel | Dashboard children (THME-20) |
| 3 | CombinedGaugeCard | Complex painter (THME-20) |
| 4 | CyberButton, CyberDialog | Reusable components (THME-20) |
| 5 | DiagnosticLogsPanel, BluetoothDeviceList, ConnectedDeviceCard | Other components |

**Total widgets to migrate:** ~15 files

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Static AppTheme constants | Consumer<ThemeProvider> pattern | Phase 2 | Dynamic theming |
| Hardcoded Color(0xFF...) | ThemeColors from provider | Phase 2 | Consistent themes |
| No theme in painters | ThemeColors parameter | Phase 2 | Gauges support themes |

**Deprecated/outdated:**
- Hardcoded colors in widgets (being replaced)
- Static AppTheme usage in widgets (being migrated)

## Open Questions

1. **Should ThemeColors include opacity variants?**
   - What we know: AppTheme has primary60, primary30, etc. ThemeColors doesn't
   - What's unclear: Performance impact of runtime withOpacity vs precomputed
   - Recommendation: For now, use withOpacity() at runtime; optimize if needed

2. **How to handle CustomPainter rebuilds efficiently?**
   - What we know: Current implementation doesn't handle theme changes in painters
   - What's unclear: Best practice for triggering repaint on theme change
   - Recommendation: Pass ThemeColors to painter, add shouldRepaint for color changes

3. **Should screens wrap with Consumer or individual widgets?**
   - What we know: Both approaches work
   - What's unclear: Performance difference
   - Recommendation: Wrap screen once with Consumer, pass colors to children

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none - Flutter default |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --reporter expanded` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THME-15 | All widgets use dynamic colors | manual | Visual inspection after migration | N/A |
| THME-16 | DashboardScreen applies theme colors | manual | Verify with theme switch | N/A |
| THME-17 | LogsScreen applies theme colors | manual | Verify with theme switch | N/A |
| THME-18 | BluetoothScanScreen applies theme colors | manual | Verify with theme switch | N/A |
| THME-19 | SettingsScreen applies theme colors | manual | Verify with theme switch | N/A - Phase 3 |
| THME-20 | Common components apply theme colors | manual | Verify with theme switch | N/A |

### Sampling Rate
- **Per task commit:** `flutter test` (quick)
- **Per wave merge:** `flutter test --reporter expanded` (full)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
No test gaps - theme migration is primarily a manual refactoring task. The existing test infrastructure from Phase 1 is sufficient.

## Files Needing Migration

### Screens (THME-16, 17, 18)
- lib/screens/dashboard_screen.dart
- lib/screens/logs_screen.dart
- lib/screens/bluetooth_scan_screen.dart

### Widgets (THME-15, 20)
- lib/widgets/cyber_button.dart
- lib/widgets/cyber_dialog.dart
- lib/widgets/side_stats_panel.dart
- lib/widgets/combined_gauge_card.dart
- lib/widgets/telemetry_chart_card.dart
- lib/widgets/riding_events_panel.dart
- lib/widgets/diagnostic_logs_panel.dart
- lib/widgets/bluetooth_device_list.dart
- lib/widgets/connected_device_card.dart
- lib/widgets/bluetooth_status_icon.dart
- lib/widgets/bluetooth_alert_dialog.dart
- lib/widgets/top_navigation_bar.dart

### Total: 15 files

## Sources

### Primary (HIGH confidence)
- Phase 1 research - ThemeProvider implementation patterns
- Existing codebase - Provider usage patterns from LogProvider, OBDDataProvider
- Flutter official docs - Consumer widget documentation

### Secondary (MEDIUM confidence)
- CLAUDE.md - Project-specific widget patterns
- Existing app_theme.dart - Static color definitions being migrated

### Tertiary (LOW confidence)
- N/A

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH - Using established Provider patterns already in codebase
- Architecture: HIGH - Based on Phase 1 implementation and existing patterns
- Pitfalls: MEDIUM - Based on common Flutter theming issues

**Research date:** 2026-03-15
**Valid until:** 30 days (stable Flutter/Provider APIs)
