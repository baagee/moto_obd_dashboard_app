# Architecture

**Analysis Date:** 2026-03-13

## Pattern Overview

**Overall:** Provider-based State Management with Service Layer Architecture

**Key Characteristics:**
- Provider pattern for state management (no Riverpod or Bloc)
- Service layer for business logic and hardware communication
- Clear separation between UI widgets, business logic (providers), and data/hardware services
- Callback-based event handling for cross-layer communication

## Layers

### UI Layer (Widgets & Screens)
- **Purpose:** Render UI and collect user input
- **Location:** `lib/screens/` and `lib/widgets/`
- **Contains:** Screens (DashboardScreen, LogsScreen, BluetoothScanScreen) and reusable UI components
- **Depends on:** Providers for state
- **Used by:** Flutter framework via MaterialApp

### State Management Layer (Providers)
- **Purpose:** Manage application state and coordinate between services and UI
- **Location:** `lib/providers/`
- **Contains:** OBDDataProvider, BluetoothProvider, LogProvider, SensorProvider, RidingStatsProvider
- **Depends on:** Services for data operations
- **Used by:** Screens and widgets via Consumer/Context

**Key Providers:**
- `OBDDataProvider` - Maintains OBD data state (rpm, speed, throttle, etc.) and history
- `BluetoothProvider` - Manages Bluetooth permissions, scanning, connection, and OBD session
- `LogProvider` - Manages diagnostic logs (memory + file dual-write)
- `RidingStatsProvider` - Riding statistics with 2Hz downsampling, 5-second time window, event detection
- `SensorProvider` - Manages lean angle sensor data

### Service Layer (Hardware & Business Logic)
- **Purpose:** Handle hardware communication and core business logic
- **Location:** `lib/services/`
- **Contains:** BluetoothService, OBDService, LogService, SensorService, DeviceStorageService, AudioService
- **Depends on:** Hardware APIs (flutter_blue_plus), models
- **Used by:** Providers

**Key Services:**
- `OBDService` - OBD protocol parsing, hierarchical polling (high/medium/low frequency PIDs)
- `BluetoothService` - Bluetooth permission detection, state detection, settings navigation
- `LogService` - Real-time log file writing and sharing
- `SensorService` - Lean angle sensor reading
- `DeviceStorageService` - Device info persistence
- `AudioService` - Audio playback for event notifications

### Data Model Layer
- **Purpose:** Define data structures
- **Location:** `lib/models/`
- **Contains:** OBDData, BluetoothDeviceModel, RidingEvent, EventVoiceConfig
- **Used by:** All layers

### Constants Layer
- **Purpose:** Centralize configuration values
- **Location:** `lib/constants/`
- **Contains:** BluetoothConstants (scan timeout, connection timeout, polling intervals)
- **Used by:** Providers and Services

### Theme Layer
- **Purpose:** Centralize styling and design tokens
- **Location:** `lib/theme/`
- **Contains:** AppTheme (colors, TextStyles, BoxDecorations)
- **Used by:** All UI components

## Data Flow

**OBD Data Flow:**

1. **Bluetooth Connection**
   ```
   BluetoothProvider.startScan() → flutter_blue_plus scan
   → BluetoothProvider.connectToDevice() → BLE connection
   → OBDService.initialize() (ELM327 AT commands)
   ```

2. **OBD Data Acquisition**
   ```
   OBDService.startPolling() → Send OBD commands (50ms base interval)
   → BLE notification → OBDService.handleNotification()
   → OBDService.parseResponse() → OBDDataProvider.updateRealTimeData()
   → OBDDataProvider notifies consumers
   ```

3. **Hierarchical Polling Pattern:**
   - High frequency (50ms): Speed (0x0D), RPM (0x0C) - ~14Hz
   - Medium frequency (200ms): Throttle (0x11), Intake Temp (0x0F), MAP (0x0B) - ~4Hz
   - Low frequency (500ms): Coolant Temp (0x05), Load (0x04), Voltage (0x42) - ~2Hz

**State Update Flow:**
```
BLE Device → OBDService → OBDDataProvider → UI (Consumer/Context.watch)
                     ↓
            RidingStatsProvider (event detection)
                     ↓
            AudioService + EventNotificationDialog
```

**Connection State Flow:**
```
App Start → BluetoothProvider.initialize()
  → Load last device → Auto-reconnect if available
  → Listen to adapter state changes
  → On disconnect → Cleanup → Auto-reconnect (max 2 attempts)
```

## Key Abstractions

**OBDData Model:**
- Purpose: Represents real-time OBD data
- Location: `lib/models/obd_data.dart`
- Pattern: Immutable data class with manual copyWith

**BluetoothDeviceModel:**
- Purpose: Represents a Bluetooth device
- Location: `lib/models/bluetooth_device.dart`
- Pattern: Immutable with DeviceConnectionStatus enum

**OBDService:**
- Purpose: OBD protocol handling
- Location: `lib/services/obd_service.dart`
- Pattern: Callback-based logging, hierarchical polling

**BluetoothProvider:**
- Purpose: Central Bluetooth state management
- Location: `lib/providers/bluetooth_provider.dart`
- Pattern: ChangeNotifier with dependency injection

## Entry Points

**main.dart:**
- Location: `lib/main.dart`
- Triggers: App launch
- Responsibilities: Force landscape mode, configure SystemChrome, setup MultiProvider, create OBDDashboardApp

**MainContainer:**
- Location: `lib/screens/main_container.dart`
- Triggers: Home page rendered
- Responsibilities: Initialize Bluetooth, manage IndexedStack pages, handle navigation, show event notifications

**DashboardScreen:**
- Location: `lib/screens/dashboard_screen.dart`
- Triggers: User navigates to Dashboard tab
- Responsibilities: Display gauges, charts, and telemetry data

**BluetoothScanScreen:**
- Location: `lib/screens/bluetooth_scan_screen.dart`
- Triggers: User navigates to Devices tab or taps "Link Vehicle"
- Responsibilities: Scan and list devices, handle connection

## Error Handling

**Strategy:** Callback-based logging with centralized LogProvider

**Patterns:**
1. Service methods use optional log callbacks instead of direct LogProvider references
2. Callbacks created via `createLogger(logProvider)` factory function
3. Log entries written to both memory (List) and file (real-time) via LogService
4. Connection errors trigger automatic reconnection (max 2 attempts)
5. BLE operation errors caught and logged, UI updated accordingly

**Bluetooth Errors:**
- Permission denied → Show BluetoothAlertDialog
- Bluetooth off → Show BluetoothAlertDialog
- Connection failed → Log error, cleanup resources
- Device disconnected → Auto-reconnect (2 attempts max)

## Cross-Cutting Concerns

**Logging:** Centralized via LogProvider and LogService
- Memory list for UI display (recent logs)
- File write for persistence (obd_logs.txt)

**Validation:** Not centralized - validation done at entry points
- Device model validates required fields
- OBD data has default values for missing fields

**Authentication:** Not applicable - uses BLE pairing

**Configuration:** Centralized in constants
- BluetoothConstants for timing values
- AppTheme for design tokens

---

*Architecture analysis: 2026-03-13*
