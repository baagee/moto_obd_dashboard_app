# Technology Stack

**Analysis Date:** 2026-03-13

## Languages

**Primary:**
- Dart 3.x - All application code (UI, business logic, services)
- Kotlin 1.9.x - Android native code
- XML - Android manifest and resources

**Secondary:**
- N/A

## Runtime

**Environment:**
- Flutter 3.x (Android only, mobile)
- Android SDK with minSdk matching Flutter defaults, targetSdk matching Flutter defaults

**Package Manager:**
- Pub (Dart package manager)
- Gradle (Android build system)
- Lockfile: `pubspec.lock` (present)

## Frameworks

**Core:**
- Flutter 3.0+ - Cross-platform UI framework

**State Management:**
- Provider 6.1.1 - Application state management

**Testing:**
- flutter_test - Unit and widget testing
- No additional testing framework detected

**Build/Dev:**
- flutter_lints 3.0.1 - Code analysis and linting
- Gradle - Android build

## Key Dependencies

**UI & Visualization:**
- fl_chart 0.66.0 - Charting library for telemetry visualization
- google_fonts 6.1.0 - Space Grotesk font (cyberpunk theme)
- cupertino_icons 1.0.6 - iOS-style icons

**Bluetooth & Hardware:**
- flutter_blue_plus 1.32.0 - BLE Bluetooth API
- sensors_plus 4.0.0 - Accelerometer and gyroscope access

**Permissions & Settings:**
- permission_handler 11.0.0 - Runtime permission management
- android_intent_plus 4.0.2 - Launch system settings (Bluetooth, etc.)

**Storage & File:**
- path_provider 2.1.0 - App documents directory access
- share_plus 7.0.0 - Share log files externally

**Audio:**
- audioplayers 6.0.0 - Audio playback for alerts

## Configuration

**Environment:**
- AndroidManifest.xml - Bluetooth permissions, hardware features
- No .env file detected (no runtime environment variables)

**Build:**
- `pubspec.yaml` - Dart dependencies
- `android/app/build.gradle.kts` - Android build configuration
- `analysis_options.yaml` - Dart analyzer configuration

**Build Configuration Details:**
- compileSdk: flutter.compileSdkVersion (from Flutter)
- minSdk: flutter.minSdkVersion (from Flutter)
- targetSdk: flutter.targetSdkVersion (from Flutter)
- Java version: 17
- Kotlin JVM target: 17
- NDK Version: 27.0.12077973

## Platform Requirements

**Development:**
- Flutter SDK 3.0+
- Android SDK (API 21+)
- Java 17

**Production:**
- Android 5.0+ (API 21 minimum)
- Bluetooth 4.0+ (BLE)
- GPS/Location permission required for BLE scanning
- Screen orientation: Landscape only (forced)

---

*Stack analysis: 2026-03-13*
