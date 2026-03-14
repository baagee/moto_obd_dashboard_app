# Project Research Summary

**Project:** CYBER-CYCLE OBD Dashboard (Multi-Theme System)
**Domain:** Flutter multi-theme architecture with Provider state management
**Researched:** 2026-03-14
**Confidence:** MEDIUM

## Executive Summary

This research addresses implementing a multi-theme system in an existing Flutter OBD dashboard. The current codebase has 40+ files referencing hardcoded `AppTheme` color constants, requiring systematic refactoring. The recommended approach extends the existing Provider pattern to support 4 themes (Cyber Blue, Red, Orange, Light) with optional sunrise/sunset auto-switching. The primary risk is that gauges and widgets with hardcoded colors will silently ignore theme changes, making the feature appear broken. Mitigation requires passing theme colors as parameters to all CustomPaint widgets and grepping for `Color(0xFF` literals before testing.

**Key recommendation:** Start with infrastructure (ThemeProvider + persistence) before touching any widgets. The 40+ widget files requiring theme-aware refactoring represent 60-70% of implementation effort—treat this as a separate phase with explicit scope.

## Key Findings

### Recommended Stack

**Core technologies:**
- **Provider (^6.1.1)** — Theme state management — Already in use, no new dependencies needed
- **shared_preferences (^2.2.0)** — Theme persistence — Standard Flutter key-value storage
- **geolocator (^11.0.0)** — Location access — Required for sunrise/sunset calculation
- **solar_calculator or sun_position** — Sunrise/sunset times — Lightweight calculation (no API needed)

**Why not alternatives:**
- Riverpod: Requires rewiring all existing Providers
- Isar/Hive: Overkill for simple theme preference storage
- Bloc: Over-engineered for 4-theme toggle
- dynamic_theme: Deprecated, not maintained

### Expected Features

**Must have (table stakes):**
- **Theme State Provider** — Centralized theme state management using existing Provider pattern
- **Theme Data Model** — Structured theme definition with all color tokens (ThemeColors class)
- **Theme-Aware Widget Refactor** — All 40+ widget files must consume dynamic theme colors (HIGH effort)
- **Manual Theme Switcher UI** — Settings page for user to select theme
- **Theme Persistence** — Save user preference across app restarts

**Should have (competitive):**
- **Auto Sunrise/Sunset Theme Switching** — Automatically switch between dark/light based on time of day (requires location permission)
- **Per-Theme Gauge Colors** — Each theme has optimized accent colors for gauge readability

**Defer (v2+):**
- Smooth Theme Transition — Animated color transitions (explicitly out of scope per PROJECT.md)
- Theme Preview Thumbnails — Visual preview when selecting themes in settings
- User-Created Custom Themes — Not in requirements

### Architecture Approach

The architecture follows the existing Provider pattern with a `ThemeProvider` (ChangeNotifier) managing theme state. Components include: `ThemeColors` data model holding all color tokens, `ThemeDefinitions` static constants for the 4 themes, `ThemeStorageService` for persistence via shared_preferences, and `SunriseSunsetService` for auto-switching. Widgets access colors via either `AppTheme.primary(context)` static method or direct `context.watch<ThemeProvider>().themeColors` access.

**Major components:**
1. **ThemeProvider** — State management with setTheme(), toggleAutoMode(); manages currentThemeType and themeColors
2. **ThemeColors** — Data model encapsulating all color tokens per theme (primary, background, surface, accentCyan, etc.)
3. **ThemeStorageService** — Persistence layer using shared_preferences for theme and auto-mode keys

### Critical Pitfalls

1. **Hardcoded Colors Throughout Widgets** — 40+ files have `Color(0xFF...)` literals that ignore theme changes. Prevention: grep for hardcoded colors before testing, replace with theme-aware accessors.

2. **CustomPaint Gauges Ignore Theme Changes** — Gauge widgets use CustomPaint which cannot access BuildContext. Prevention: pass colors as parameters, wrap in Consumer<ThemeProvider>.

3. **ThemeData Not Using AppTheme Constants** — main.dart duplicates AppTheme values instead of referencing them. Prevention: use AppTheme.* constants in ThemeData, create ThemeExtension.

4. **System UI Brightness Desync** — Status bar doesn't match theme brightness. Prevention: use AnnotatedRegion or update SystemChrome on theme change.

5. **Auto Theme Flash on App Start** — App shows default theme for 1-2 frames before saved preference loads. Prevention: use splash screen or cached synchronous load.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Theme Infrastructure
**Rationale:** Foundation must be built before any widget changes—everything depends on ThemeProvider and persistence working correctly.
**Delivers:** ThemeProvider, ThemeColors model, ThemeDefinitions, ThemeStorageService, updated main.dart with proper ThemeData
**Avoids:** Pitfall #3 (ThemeData not using AppTheme), Pitfall #5 (theme flash on startup)
**Research flag:** LOW — Standard Flutter theming patterns, well-documented

### Phase 2: Widget & Gauge Migration
**Rationale:** 40+ files require systematic refactoring—this is the bulk of work and must be isolated from infrastructure changes
**Delivers:** All widgets converted to theme-aware accessors, CustomPaint gauges accepting color parameters
**Avoids:** Pitfall #1 (hardcoded colors), Pitfall #2 (CustomPaint ignoring themes)
**Research flag:** MEDIUM — Needs grep verification to catch missed hardcoded colors

### Phase 3: Settings Integration
**Rationale:** User-facing theme selection UI; ties together infrastructure and widget changes
**Delivers:** Settings screen with theme selector, system UI brightness sync
**Avoids:** Pitfall #4 (system UI brightness desync)
**Research flag:** LOW — Standard settings page patterns

### Phase 4: Auto-Switch Features
**Rationale:** Differentiator features requiring location permission handling—build after core is stable
**Delivers:** Sunrise/sunset auto-switch, graceful permission handling
**Avoids:** Pitfall #6 (location permission for auto-switch)
**Research flag:** MEDIUM — Location permission flow needs careful implementation

### Phase Ordering Rationale

- Infrastructure first because all subsequent phases depend on ThemeProvider
- Widget migration is isolated as a single phase because it affects 40+ files and must be thoroughly tested
- Settings integration comes after widgets are theme-aware (can select and see results)
- Auto-switch is deferrable—only a differentiator, not table stakes

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Widget Migration):** Needs grep verification and visual testing strategy for 40+ files
- **Phase 4 (Auto-Switch):** Location permission handling and fallback logic need careful UX design

Phases with standard patterns (skip research-phase):
- **Phase 1:** Well-documented Flutter theming, Provider patterns already in codebase
- **Phase 3:** Standard settings page patterns

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Standard Flutter packages, existing Provider pattern |
| Features | HIGH | Clear scope from PROJECT.md, standard theming features |
| Architecture | HIGH | Follows existing codebase patterns, well-structured |
| Pitfalls | MEDIUM | Based on codebase analysis, actual issues may vary |

**Overall confidence:** MEDIUM

### Gaps to Address

- **Light theme glow effects:** Dark theme relies heavily on glow effects that may not translate to light mode—need design validation during Phase 1
- **Widget grep verification:** Research identified ~16 widget files but actual count needs verification before Phase 2 planning
- **Performance impact:** OBD data rendering at 5Hz + theme changes needs testing during Phase 3 integration

## Sources

### Primary (HIGH confidence)
- Current codebase analysis (40+ files referencing AppTheme.*)
- Flutter official theming documentation
- Existing Provider patterns in codebase (bluetooth_provider.dart reference)

### Secondary (MEDIUM confidence)
- PROJECT.md requirements specification
- shared_preferences package documentation
- geolocator package documentation

### Tertiary (LOW confidence)
- solar_calculator package alternatives (may need manual calculation instead)

---
*Research completed: 2026-03-14*
*Ready for roadmap: yes*
