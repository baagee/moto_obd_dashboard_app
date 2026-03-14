---
phase: 02-widget-migration
plan: 02
type: execute
subsystem: widgets
tags: [flutter, theme, provider, migration]
dependency_graph:
  requires:
    - 02-01 (Screen theme migration)
  provides:
    - Dynamic theme support for all 14 widgets
  affects:
    - All screens using these widgets

tech_stack:
  added:
    - Consumer<ThemeProvider>
    - ThemeColors parameter for CustomPainter
  patterns:
    - Consumer<ThemeProvider> wrapper in widget build methods
    - ThemeColors passed to internal widgets
    - shouldRepaint checks for colors change

key_files:
  created: []
  modified:
    - lib/widgets/combined_gauge_card.dart
    - lib/widgets/speed_gear_card.dart
    - lib/widgets/side_stats_panel.dart
    - lib/widgets/telemetry_chart_card.dart
    - lib/widgets/riding_events_panel.dart
    - lib/widgets/cyber_button.dart
    - lib/widgets/cyber_dialog.dart
    - lib/widgets/diagnostic_logs_panel.dart
    - lib/widgets/bluetooth_device_list.dart
    - lib/widgets/connected_device_card.dart
    - lib/widgets/bluetooth_status_icon.dart
    - lib/widgets/bluetooth_alert_dialog.dart
    - lib/widgets/top_navigation_bar.dart
    - lib/widgets/event_notification_dialog.dart

decisions:
  - Used Consumer<ThemeProvider> pattern for StatelessWidget widgets
  - Passed ThemeColors parameter to CustomPainter constructors
  - Updated shouldRepaint to check for colors change

metrics:
  duration: ~5 min
  completed_date: "2026-03-14"
  tasks_completed: 5
  files_modified: 14
---

# Phase 2 Plan 2: Widget Theme Migration Summary

**One-liner:** Migrated 14 widget files to use dynamic theme colors via Consumer<ThemeProvider> and ThemeColors parameter

## Objective

Migrate all widget files to use dynamic theme colors via Consumer<ThemeProvider> or ThemeColors parameter, enabling theme switching throughout the app.

## Completed Tasks

| Task | Name | Status |
|------|------|--------|
| 1 | Migrate complex painter widgets (CombinedGaugeCard, SpeedGearCard) | Done |
| 2 | Migrate dashboard child widgets (SideStatsPanel, TelemetryChartCard, RidingEventsPanel) | Done |
| 3 | Migrate reusable UI components (CyberButton, CyberDialog, DiagnosticLogsPanel) | Done |
| 4 | Migrate list and device widgets (BluetoothDeviceList, ConnectedDeviceCard, BluetoothStatusIcon) | Done |
| 5 | Migrate remaining widgets (BluetoothAlertDialog, TopNavigationBar, EventNotificationDialog) | Done |

## Changes Made

### Task 1: Complex Painter Widgets
- Added ThemeColors parameter to CombinedGaugePainter, PressureChartPainter, TelemetryChartPainter constructors
- Replaced AppTheme.primary, AppTheme.accentCyan, AppTheme.textMuted with dynamic colors
- Updated shouldRepaint to return true when colors change
- Wrapped CombinedGaugeCard widget with Consumer<ThemeProvider>
- Migrated SpeedGearCard from commented code to active with dynamic colors

### Task 2: Dashboard Child Widgets
- SideStatsPanel: Added Consumer<ThemeProvider>, passed colors to internal widgets (_TempCard, _ProgressBar, _LeanAngleIndicator, _PressureChart, _VoltageDisplay)
- TelemetryChartCard: Added Consumer<ThemeProvider>, passed colors to TelemetryChartPainter
- RidingEventsPanel: Added Consumer<ThemeProvider>, passed colors to _EventItem

### Task 3: Reusable UI Components
- CyberButton: Added Consumer<ThemeProvider>, dynamic colors for all button types (primary, secondary, danger, success)
- CyberDialog: Added Consumer<ThemeProvider>, dynamic surface and accent colors
- DiagnosticLogsPanel: Added Consumer<ThemeProvider>, dynamic colors for log items

### Task 4: List and Device Widgets
- BluetoothDeviceList: Added Consumer<ThemeProvider>, passed colors to _ScanProgressBar, _EmptyState, _DeviceListItem, _SignalStrengthIndicator
- ConnectedDeviceCard: Added Consumer<ThemeProvider>, passed colors to all internal states
- BluetoothStatusIcon: Added Consumer<ThemeProvider>, dynamic colors based on bluetooth state

### Task 5: Remaining Widgets
- BluetoothAlertDialog: Added Consumer<ThemeProvider>, dynamic warning colors
- TopNavigationBar: Added Consumer<ThemeProvider>, dynamic nav colors
- EventNotificationDialog: Added Consumer<ThemeProvider>, dynamic event colors

## Verification

All 14 widget files pass `flutter analyze` with no errors (only info-level warnings about const usage).

## Deviations from Plan

None - plan executed exactly as written.

## Requirements Covered

- THME-15: Widgets respond to theme changes
- THME-20: Custom painters support theme colors

## Self-Check

- [x] All 14 widgets migrated
- [x] CustomPainter widgets pass ThemeColors to constructors
- [x] flutter analyze passes with no errors
- [x] Commit created: cfef39c
