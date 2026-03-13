# External Integrations

**Analysis Date:** 2026-03-13

## APIs & External Services

**OBD Diagnostics:**
- ELM327 OBD Adapter (Bluetooth) - Reads vehicle diagnostics data
  - Protocol: Bluetooth BLE (flutter_blue_plus)
  - PIDs:转速(0C),车速(0D),水温(05),节气门(11),进气温度(0F),MAP(0B),负载(04),电压(42)
  - Connection: Device-initiated pairing

**Bluetooth:**
- Flutter Blue Plus - BLE Bluetooth communication
  - Purpose: Connect to OBD adapters and read vehicle data
  - Permissions required: BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION
  - Intent: Opens system Bluetooth settings (android_intent_plus)

## Data Storage

**Local File Storage:**
- Application Documents Directory
  - Logs: `{app_documents}/obd_logs.txt` (real-time write via StreamController)
  - Device: `{app_documents}/last_device.json` (JSON persistence for auto-reconnect)
- No external database detected

**State Management:**
- Provider 6.1.1 - In-memory state management
- No persistent database (SQLite, etc.)

## Hardware Sensors

**Accelerometer:**
- sensors_plus package
- Purpose: Calculate motorcycle lean angle
- Data: Accelerometer X/Y/Z + Gyroscope X for complementary filtering

**No other hardware integrations detected.**

## Authentication & Identity

**N/A** - No authentication system. This is a local-only OBD dashboard.

## Monitoring & Observability

**Logging:**
- Custom LogService with dual write (memory + file)
- No external logging service

**Error Tracking:**
- None detected (no Crashlytics, Sentry, etc.)

**No CI/CD pipeline detected.**

## Environment Configuration

**Required Android permissions (in AndroidManifest.xml):**
- BLUETOOTH - Classic Bluetooth (API < 31)
- BLUETOOTH_ADMIN - Bluetooth administration (API < 31)
- BLUETOOTH_SCAN - BLE scan (Android 12+)
- BLUETOOTH_CONNECT - BLE connect (Android 12+)
- ACCESS_FINE_LOCATION - Required for BLE scanning on older Android

**No runtime environment variables detected.**

## Webhooks & Callbacks

**Incoming:**
- None - No HTTP server or webhook receiver

**Outgoing:**
- None - No outgoing webhook calls

---

*Integration audit: 2026-03-13*
