# Codebase Structure

**Analysis Date:** 2026-03-13

## Directory Layout

```
lib/
├── main.dart                     # App entry, force landscape, MultiProvider setup
├── models/                       # Data models
├── providers/                   # State management (Provider pattern)
├── services/                    # Business logic & hardware communication
├── screens/                     # Screen widgets
├── widgets/                     # Reusable UI components
├── theme/                       # Design system (colors, styles, decorations)
└── constants/                  # Configuration constants
```

## Directory Purposes

**lib/models/:**
- Purpose: Data model definitions
- Contains: OBDData, BluetoothDeviceModel, RidingEvent, EventVoiceConfig, enums
- Key files: `obd_data.dart`, `bluetooth_device.dart`, `riding_event.dart`

**lib/providers/:**
- Purpose: State management with Provider pattern
- Contains: ChangeNotifier classes for app state
- Key files: `obd_data_provider.dart`, `bluetooth_provider.dart`, `log_provider.dart`, `riding_stats_provider.dart`, `sensor_provider.dart`

**lib/services/:**
- Purpose: Business logic and hardware abstraction
- Contains: Hardware communication, file I/O, audio
- Key files: `obd_service.dart`, `bluetooth_service.dart`, `log_service.dart`, `sensor_service.dart`, `device_storage_service.dart`, `audio_service.dart`

**lib/screens/:**
- Purpose: Full-screen pages
- Contains: MainContainer, DashboardScreen, LogsScreen, BluetoothScanScreen
- Key files: `main_container.dart`, `dashboard_screen.dart`, `logs_screen.dart`, `bluetooth_scan_screen.dart`

**lib/widgets/:**
- Purpose: Reusable UI components
- Contains: Gauge cards, panels, buttons, dialogs
- Key files: `speed_gauge_card.dart`, `rpm_gauge_card.dart`, `combined_gauge_card.dart`, `telemetry_chart_card.dart`, `cyber_button.dart`, `bluetooth_device_list.dart`, `diagnostic_logs_panel.dart`

**lib/theme/:**
- Purpose: Design system
- Contains: Colors, TextStyles, BoxDecorations
- Key files: `app_theme.dart`

**lib/constants/:**
- Purpose: Configuration values
- Contains: Timing constants, thresholds
- Key files: `bluetooth_constants.dart`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App initialization, Provider setup, SystemChrome configuration

**Configuration:**
- `lib/constants/bluetooth_constants.dart`: Timing configuration (scan timeout, polling intervals, reconnect settings)
- `lib/theme/app_theme.dart`: Design tokens (colors, typography, decorations)

**Core Logic:**
- `lib/services/obd_service.dart`: OBD protocol parsing and hierarchical polling
- `lib/providers/bluetooth_provider.dart`: Bluetooth connection management and OBD session handling
- `lib/providers/obd_data_provider.dart`: OBD data state management
- `lib/providers/riding_stats_provider.dart`: Riding event detection

**Testing:**
- No dedicated test directory - tests would go in `test/` (not present)

## Naming Conventions

**Files:**
- PascalCase for Dart files that define classes: `bluetooth_provider.dart`, `obd_service.dart`
- Avoid underscores in file names

**Directories:**
- All lowercase: `models/`, `providers/`, `services/`, `widgets/`, `screens/`

**Classes:**
- PascalCase: `BluetoothProvider`, `OBDService`, `OBDDataProvider`
- Suffix: Provider for state managers, Service for business logic

**Variables/Methods:**
- camelCase: `isConnected`, `startScan()`, `updateRealTimeData()`

**Private Members:**
- Prefix underscore: `_obdService`, `_writeCharacteristic`, `_isPollingActive`

**Enums:**
- PascalCase for enum name: `RidingEventType`, `DeviceConnectionStatus`
- Lowercase for members: `extremeLean`, `hardBraking`, `rapidAcceleration`

**Constants:**
- camelCase for constants: `scanTimeout`, `pollingBaseIntervalMs`
- Use `static const` for compile-time constants

## Where to Add New Code

**New Feature:**
- Core logic: Add to appropriate service in `lib/services/`
- State: Add to appropriate provider in `lib/providers/`
- UI: Add screen in `lib/screens/` or widget in `lib/widgets/`

**New Provider:**
- Implementation: Create new file in `lib/providers/`
- Register: Add to MultiProvider in `lib/main.dart`
- Tests: Create corresponding test in `test/` (create directory if needed)

**New Service:**
- Implementation: Create new file in `lib/services/`
- Dependencies: Pass via constructor with named parameters and `required` keyword
- Logging: Use optional callback parameter for logging

**New Widget:**
- Implementation: Create new file in `lib/widgets/`
- Follow existing patterns: const constructor, Consumer pattern, separation of complex build logic
- Naming: PascalCase for class, matching filename

**New Model:**
- Implementation: Create new file in `lib/models/`
- Pattern: Use Dart class with final fields, manual copyWith method
- Enums: Define at end of file or separate file

**Utilities:**
- Shared helpers: Consider adding to appropriate service or create new utility file
- Constants: Add to existing constants file or create new file in `lib/constants/`

## Special Directories

**lib/old_code/:**
- Purpose: Deprecated code to be cleaned up
- Generated: No
- Committed: Yes (contains old bluetooth_service.dart)

---

*Structure analysis: 2026-03-13*
