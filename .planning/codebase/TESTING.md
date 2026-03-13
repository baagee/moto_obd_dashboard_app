# Testing Patterns

**Analysis Date:** 2026-03-13

## Test Framework

**Runner:**
- `flutter_test` (included in dev_dependencies)
- No additional test framework configured

**Assertion Library:**
- Built-in from `flutter_test`

**Run Commands:**
```bash
flutter test              # Run all tests
flutter test --watch     # Watch mode (if supported)
flutter test --coverage # Coverage report
```

## Test File Organization

**Location:**
- Not detected - No test files currently exist in this project

**Naming:**
- Standard Flutter pattern: `*_test.dart` or `*_spec.dart`

**Expected Structure:**
```
test/
├── models/
│   └── obd_data_test.dart
├── providers/
│   ├── bluetooth_provider_test.dart
│   └── obd_data_provider_test.dart
└── services/
    └── obd_service_test.dart
```

## Test Structure

**Suite Organization:**
- Use standard `test()` and `group()` functions
- Mock dependencies using `mocktail` or built-in mocking

**Expected Pattern:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/models/obd_data.dart';
import 'package:obd_dashboard/providers/obd_data_provider.dart';
import 'package:obd_dashboard/providers/log_provider.dart';

void main() {
  group('OBDData', () {
    test('copyWith should create new instance with updated values', () {
      final original = OBDData(
        rpm: 3000,
        speed: 80,
        throttle: 50,
        // ... other required fields
      );

      final updated = original.copyWith(rpm: 4000);

      expect(updated.rpm, 4000);
      expect(updated.speed, 80); // unchanged
    });
  });
}
```

## Mocking

**Framework:**
- Not configured - No mocking library added yet

**Recommended Approach:**
- Use `flutter_test` built-in mocking or add `mocktail` to dev_dependencies

**Patterns to Implement:**
```dart
// Mock Provider
class MockOBDDataProvider extends Mock implements OBDDataProvider {}

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

// Mock LogProvider
class MockLogProvider extends Mock implements LogProvider {
  @override
  void addLog(String source, LogType type, String message) {
    // No-op for tests
  }
}
```

**What to Mock:**
- Bluetooth device connections (`flutter_blue_plus`)
- File system operations (`path_provider`)
- Device sensors (`sensors_plus`)

**What NOT to Mock:**
- Domain models (test real instances)
- Simple value objects
- Providers that are the test subject

## Fixtures and Factories

**Test Data:**
- Not established - No test fixtures currently exist

**Recommended Pattern:**
```dart
// In test/fixtures/obd_fixtures.dart
class OBDDataFixtures {
  static OBDData minimal() => OBDData(
    rpm: 0,
    speed: 0,
    throttle: 0,
    load: 0,
    leanAngle: 0,
    leanDirection: 'none',
    pressure: 0,
    voltage: 12.5,
    coolantTemp: 90,
    intakeTemp: 25,
    rpmHistory: [],
    velocityHistory: [],
  );

  static OBDData riding() => OBDData(
    rpm: 5000,
    speed: 100,
    throttle: 80,
    load: 75,
    leanAngle: 30,
    leanDirection: 'left',
    pressure: 50,
    voltage: 14.2,
    coolantTemp: 95,
    intakeTemp: 40,
    rpmHistory: [4500, 4800, 5000],
    velocityHistory: [95, 98, 100],
  );
}
```

## Coverage

**Requirements:** Not enforced

**View Coverage:**
```bash
flutter test --coverage
# Coverage report generated in coverage/lcov.info
```

## Test Types

**Unit Tests:**
- Models: `copyWith`, constructors, getters
- Providers: State changes, method calls
- Services: Data parsing, command generation

**Integration Tests:**
- Not currently implemented
- Would test Bluetooth flow, OBD polling

**E2E Tests:**
- Not used in this project

## Common Patterns to Establish

**Async Testing:**
```dart
test('BluetoothProvider initializes correctly', () async {
  final provider = BluetoothProvider(
    obdDataProvider: MockOBDDataProvider(),
    logProvider: MockLogProvider(),
  );

  await provider.initialize();

  expect(provider.isInitialized, true);
});
```

**Error Testing:**
```dart
test('OBDService throws when write characteristic not set', () async {
  final service = OBDService(
    obdDataProvider: MockOBDDataProvider(),
  );

  expect(
    () => service.initialize(),
    throwsException,
  );
});
```

## Recommendations

1. **Add test dependencies:**
   ```yaml
   dev_dependencies:
     flutter_test:
       sdk: flutter
     mocktail: ^1.0.0
   ```

2. **Create test directory structure:**
   - `test/models/` for model unit tests
   - `test/providers/` for provider tests
   - `test/services/` for service tests
   - `test/fixtures/` for test data

3. **Priority test targets:**
   - `OBDData.copyWith()` - critical model method
   - `OBDService.parseResponse()` - core parsing logic
   - `BluetoothProvider.connectToDevice()` - complex async flow

---

*Testing analysis: 2026-03-13*
