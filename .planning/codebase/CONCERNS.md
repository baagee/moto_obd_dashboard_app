# Codebase Concerns

**Analysis Date:** 2026-03-13

## Tech Debt

**Debug Code Not Cleaned Up:**
- Issue: Test code left in production with TODO markers
- Files: `lib/screens/main_container.dart` (lines 45-79)
- Impact: Dead code that should be removed before release
- Fix approach: Delete the `_triggerTestEvent()` method and its call in `initState()`

**Orphaned Code:**
- Issue: Large unused Bluetooth service implementation (837 lines)
- Files: `lib/old_code/bluetooth_service.dart`
- Impact: Increases repo size, confusing for developers
- Fix approach: Delete the entire `old_code/` directory

**Large Complex Files:**
- Issue: Files exceed 600 lines making them hard to maintain
- Files:
  - `lib/providers/bluetooth_provider.dart` (720 lines)
  - `lib/widgets/combined_gauge_card.dart` (627 lines)
- Impact: Difficult to understand, test, and modify
- Fix approach: Extract into smaller focused classes/providers

---

## Memory Leaks

**StreamController Never Closed:**
- Issue: Static StreamController in LogService never disposed
- Files: `lib/services/log_service.dart` (lines 14-15)
- Impact: Resource leak if app runs for extended sessions
- Fix approach: Add static `dispose()` method or use `close()` in app termination

---

## Error Handling Issues

**Silent Error Catching:**
- Issue: Multiple catch blocks that silently swallow errors without logging
- Files:
  - `lib/services/log_service.dart` (lines 28-30, 60-62, 88-90, 105-107)
  - `lib/services/device_storage_service.dart` (lines 34, 63, 78)
  - `lib/services/bluetooth_service.dart` (lines 73, 88, 99, 106)
- Impact: Hidden failures make debugging difficult
- Fix approach: Add proper error logging even if recovery is not possible

**Catch Without Type:**
- Issue: Generic `catch (e)` without specific exception types
- Files: Multiple locations in providers and services
- Impact: Can't distinguish between expected and unexpected errors
- Fix approach: Catch specific exceptions where possible

---

## Debug Code in Production

**Debug Print Statements:**
- Issue: `debugPrint` calls remain in production code
- Files: `lib/screens/main_container.dart` (line 78)
- Impact: Performance overhead and log noise in release builds
- Fix approach: Remove debug statements or use conditional logging

---

## Test Coverage Gaps

**No Unit Tests:**
- Issue: No test files found in the project
- Files: No `test/` directory or test files
- Impact: No automated verification of business logic
- Priority: High
- Risk: Refactoring can break functionality without detection

**Missing Test Coverage Areas:**
- OBD parsing logic in `lib/services/obd_service.dart`
- Riding event detection in `lib/providers/riding_stats_provider.dart`
- Bluetooth connection state machine in `lib/providers/bluetooth_provider.dart`

---

## Performance Concerns

**List Growth Without Limit:**
- Issue: History lists (`_rpmHistory`, `_velocityHistory`, `_pressureHistory`) use `removeAt(0)` for bounded growth
- Files: `lib/providers/obd_data_provider.dart` (lines 97-99)
- Impact: O(n) removal from front of list is inefficient
- Fix approach: Use `CircularBuffer` or `Queue` data structure

**Timer-Based Polling:**
- Issue: Multiple periodic timers running simultaneously
- Locations:
  - `lib/services/obd_service.dart` (line 238)
  - `lib/providers/bluetooth_provider.dart` (line 667)
  - `lib/providers/riding_stats_provider.dart` (line 132)
  - `lib/services/sensor_service.dart` (line 74)
- Impact: Battery drain on mobile device
- Fix approach: Consolidate timers or use event-driven approach

---

## Security Considerations

**No Input Validation:**
- Issue: OBD response parsing trusts input without validation
- Files: `lib/services/obd_service.dart` (lines 94-170)
- Risk: Malformed Bluetooth responses could cause unexpected behavior
- Current mitigation: Basic null checks
- Recommendations: Add schema validation for OBD responses

---

## Fragile Areas

**Bluetooth Connection State Machine:**
- Files: `lib/providers/bluetooth_provider.dart` (720 lines)
- Why fragile: Complex async state transitions, many edge cases
- Safe modification: Add extensive logging before changes
- Test coverage: None - high risk

**OBD Protocol Parsing:**
- Files: `lib/services/obd_service.dart`
- Why fragile: Relies on specific ELM327 response formats
- Safe modification: Test with multiple OBD adapters

---

## Dependencies at Risk

**Outdated Packages:**
- `flutter_blue_plus: ^1.32.0` - Major version changes may break API
- `fl_chart: ^0.66.0` - Older version, may miss performance improvements
- `provider: ^6.1.1` - Consider Riverpod for better scalability
- `permission_handler: ^11.0.0` - Android/iOS permission APIs change frequently

**Pinned Version Risks:**
- All dependencies use caret (^) allowing minor/patch updates
- Impact: Unexpected breaking changes in transitive dependencies
- Fix approach: Pin exact versions after testing

---

## Known Bugs

**Silent OBD Failures:**
- Issue: OBD commands returning `null` are silently ignored
- Files: `lib/services/obd_service.dart` (lines 97-108)
- Trigger: Poor Bluetooth signal or incompatible OBD adapter
- Workaround: None visible to user

**No Reconnection UI Feedback:**
- Issue: Automatic reconnection happens without user notification
- Files: `lib/providers/bluetooth_provider.dart`
- Trigger: After Bluetooth disconnect
- Workaround: None - user sees frozen UI

---

## Missing Critical Features

**Error Recovery:**
- Problem: No graceful degradation when OBD data unavailable
- Blocks: User cannot diagnose connection issues easily

**Offline Mode:**
- Problem: App requires Bluetooth connection to be useful
- Blocks: Testing UI without OBD device

---

*Concerns audit: 2026-03-13*
