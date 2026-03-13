# Coding Conventions

**Analysis Date:** 2026-03-13

## Naming Patterns

**Files:**
- Use lowercase with underscores: `bluetooth_provider.dart`, `obd_service.dart`
- Widgets: `cyber_button.dart`, `speed_gauge_card.dart`
- Models: `obd_data.dart`, `bluetooth_device.dart`

**Functions:**
- Use camelCase: `startScan()`, `connectToDevice()`, `initialize()`
- Private methods: prefix with `_`: `_checkPermission()`, `_autoReconnectLastDevice()`
- Factory functions: `createLogger()` in `loggable.dart`

**Variables:**
- Use camelCase: `isBluetoothOn`, `scannedDevices`, `connectedDevice`
- Private fields: prefix with `_`: `_permissionStatus`, `_obdService`
- Constants: `static const` within classes, all caps for enum values

**Types:**
- Classes: PascalCase (`OBDData`, `BluetoothProvider`, `CyberButton`)
- Enums: PascalCase enum name, lowercase members:
  ```dart
  enum LogType { success, error, warning, info }
  enum RidingEventType { extremeLean, hardBraking, rapidAcceleration }
  ```

## Code Style

**Formatting:**
- Tool: Built-in Dart formatter (via `flutter analyze`)
- Uses standard Flutter lints: `include: package:flutter_lints/flutter.yaml`
- No custom lint rules configured (all defaults from Flutter)

**Indentation:**
- 2 spaces per level (Dart standard)
- Trailing commas used for readability in lists and parameters

**Naming Conventions:**
- Models: All fields `final`, manual `copyWith` method required
- Services: Dependency injection via constructor with `required` keyword
- Providers: Extend `ChangeNotifier`, private fields with `_`, expose via getters

## Import Organization

**Order:**
1. Dart built-in packages: `dart:async`, `dart:convert`
2. Flutter/Third-party packages: `package:flutter/material.dart`
3. Relative imports from project: `../models/`, `../providers/`, `../services/`

**Path Aliases:**
- No path aliases configured (uses relative imports)
- Third-party packages aliased when needed: `import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;`

## Error Handling

**Patterns:**
- Try-catch blocks for async operations with specific error messages
- Silent fail for non-critical errors: `.catchError((_) {})`
- Exception throwing for critical failures: `throw Exception('message')`
- Error type checking: `if (errorMsg.contains('device is disconnected'))`

**Examples:**
```dart
// Connection error handling
try {
  await device.flutterDevice!.connect(...);
} catch (e) {
  _logCallback?.call('Bluetooth', LogType.error, 'Error: $e');
}

// Silent fail for non-critical
await notifyChar.setNotifyValue(false).catchError((_) {});

// Critical failure
if (_writeCharacteristic == null) {
  throw Exception('写入特征未设置');
}
```

## Logging

**Framework:** Custom `LogProvider` with `LogService` file persistence

**Patterns:**
- Log via callback function created by `createLogger(logProvider)` factory
- Log levels: `LogType.success`, `LogType.error`, `LogType.warning`, `LogType.info`
- Each log includes: source, type, message

**Usage:**
```dart
// Create logger callback
_logCallback = createLogger(logProvider);

// Use in code
_logCallback?.call('Bluetooth', LogType.info, '开始扫描蓝牙设备...');
_logCallback?.call('OBD', LogType.error, '解析数据失败: $e');
```

## Comments

**When to Comment:**
- Chinese comments for all public APIs and complex logic
- Describe what code does, not what it obvious does
- Document constants with detailed explanations

**Examples:**
```dart
/// 蓝牙状态 Provider - 管理蓝牙权限和状态
class BluetoothProvider extends ChangeNotifier { ... }

/// 蓝牙设备扫描超时时间
/// 超过此时间后停止扫描
static const Duration scanTimeout = Duration(seconds: 3);
```

## Function Design

**Size:**
- Methods generally under 50 lines
- Complex logic separated into private helper methods

**Parameters:**
- Required parameters use `required` keyword
- Optional parameters with defaults for common cases

**Return Values:**
- Explicit return types always specified
- `Future<void>` for async operations

## Module Design

**Exports:**
- Direct exports, no barrel files (`index.dart`)
- Each file is self-contained with its own imports

**Barrel Files:**
- Not used in this project

## Widget Design

**Component Type:**
- Prefer `StatelessWidget` with `Consumer<Provider>` pattern
- All custom widgets use `const` constructors

**Pattern:**
```dart
class CyberButton extends StatelessWidget {
  const CyberButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = CyberButtonType.primary,
  });

  // Named factory constructors for specific types
  const CyberButton.primary({
    super.key,
    required this.text,
    this.onPressed,
  }) : type = CyberButtonType.primary;
}
```

**Build Methods:**
- Separate complex layouts into private methods
- Example: `_buildButton()`, `_buildContent()`

---

*Convention analysis: 2026-03-13*
