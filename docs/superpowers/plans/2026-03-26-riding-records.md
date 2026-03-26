# 骑行记录功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 CYBER-CYCLE OBD Dashboard 添加骑行记录功能，支持 GPS 定位记录、数据持久化、统计聚合、事件追溯。

**Architecture:**
- GPS 定位使用 `geolocator` 插件，逆地理编码使用 `geocoding` 插件
- SQLite 数据库使用 `sqflite` 封装，支持骑行记录、事件、每日聚合存储
- Provider 模式管理状态，遵循项目现有架构

**Tech Stack:** Flutter, Provider, sqflite, geolocator, geocoding, path_provider, intl

---

## 文件结构

```
lib/
├── models/
│   └── riding_record.dart              # 骑行记录数据模型（RidingRecord, RidingRecordEvent, DailyStats）
├── providers/
│   └── riding_record_provider.dart     # 骑行记录状态管理
├── services/
│   ├── database_service.dart          # SQLite数据库服务
│   ├── location_service.dart           # GPS定位服务
│   └── geocoding_service.dart         # 逆地理编码服务
├── screens/
│   └── record_screen.dart              # 骑行记录页面
└── widgets/
    ├── stats_summary_card.dart         # 聚合统计卡片
    ├── ride_record_card.dart          # 骑行记录卡片
    ├── ride_event_list_modal.dart     # 事件列表弹窗
    ├── delete_confirm_dialog.dart      # 删除确认弹窗
    └── swipeable_record_card.dart      # 可滑动删除的记录卡片
```

---

### Task 1: 添加依赖并配置权限

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 添加依赖到 pubspec.yaml**

```yaml
dependencies:
  # 新增
  geolocator: ^11.0.0        # GPS定位
  geocoding: ^2.1.0          # 逆地理编码（坐标转地名）
  sqflite: ^2.3.0            # SQLite数据库
  intl: ^0.19.0              # 日期格式化
```

- [ ] **Step 2: 运行 flutter pub get**

Run: `cd /Users/dangliuhui/Desktop/tttzzz/moto_code/dashboard_test01 && flutter pub get`
Expected: 依赖安装成功

- [ ] **Step 3: 添加 GPS 权限到 AndroidManifest.xml（第7行后添加）**

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

- [ ] **Step 4: 提交**

```bash
git add pubspec.yaml android/app/src/main/AndroidManifest.xml
git commit -m "feat: 添加骑行记录功能依赖（geolocator, geocoding, sqflite, intl）"
```

---

### Task 2: 实现 DatabaseService（SQLite 封装）

**Files:**
- Create: `lib/services/database_service.dart`

- [ ] **Step 1: 创建 DatabaseService**

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite数据库服务 - 单例模式
class DatabaseService {
  static Database? _database;
  static const String _dbName = 'obd_dashboard.db';
  static const int _dbVersion = 1;

  /// 获取数据库实例
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  /// 创建表
  static Future<void> _onCreate(Database db, int version) async {
    // 骑行记录表
    await db.execute('''
      CREATE TABLE riding_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        start_latitude REAL,
        start_longitude REAL,
        start_place_name TEXT,
        end_latitude REAL,
        end_longitude REAL,
        end_place_name TEXT,
        distance REAL DEFAULT 0,
        avg_speed REAL DEFAULT 0,
        duration INTEGER DEFAULT 0,
        max_speed REAL DEFAULT 0,
        max_left_lean REAL DEFAULT 0,
        max_right_lean REAL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // 骑行事件表
    await db.execute('''
      CREATE TABLE riding_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        trigger_value REAL,
        threshold REAL,
        timestamp INTEGER NOT NULL,
        additional_data TEXT,
        FOREIGN KEY (record_id) REFERENCES riding_records(id) ON DELETE CASCADE
      )
    ''');

    // 每日聚合表
    await db.execute('''
      CREATE TABLE daily_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        total_distance REAL DEFAULT 0,
        total_duration INTEGER DEFAULT 0,
        avg_speed REAL DEFAULT 0,
        max_speed REAL DEFAULT 0,
        max_left_lean REAL DEFAULT 0,
        max_right_lean REAL DEFAULT 0,
        ride_count INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_riding_records_start_time ON riding_records(start_time)');
    await db.execute('CREATE INDEX idx_riding_events_record_id ON riding_events(record_id)');
    await db.execute('CREATE INDEX idx_daily_stats_date ON daily_stats(date)');
  }

  // ========== 骑行记录 CRUD ==========

  /// 插入骑行记录
  static Future<int> insertRidingRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert('riding_records', record);
  }

  /// 查询所有骑行记录（按时间倒序）
  static Future<List<Map<String, dynamic>>> getAllRidingRecords() async {
    final db = await database;
    return await db.query(
      'riding_records',
      orderBy: 'start_time DESC',
    );
  }

  /// 查询指定时间范围内的骑行记录
  static Future<List<Map<String, dynamic>>> getRidingRecordsByTimeRange(
    int startTime,
    int endTime,
  ) async {
    final db = await database;
    return await db.query(
      'riding_records',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [startTime, endTime],
      orderBy: 'start_time DESC',
    );
  }

  /// 删除骑行记录（级联删除事件）
  static Future<int> deleteRidingRecord(int id) async {
    final db = await database;
    return await db.delete(
      'riding_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== 骑行事件 CRUD ==========

  /// 插入骑行事件
  static Future<int> insertRidingEvent(int recordId, Map<String, dynamic> event) async {
    final db = await database;
    final data = Map<String, dynamic>.from(event);
    data['record_id'] = recordId;
    return await db.insert('riding_events', data);
  }

  /// 批量插入骑行事件
  static Future<void> insertRidingEvents(int recordId, List<Map<String, dynamic>> events) async {
    final db = await database;
    final batch = db.batch();
    for (final event in events) {
      final data = Map<String, dynamic>.from(event);
      data['record_id'] = recordId;
      batch.insert('riding_events', data);
    }
    await batch.commit(noResult: true);
  }

  /// 查询指定骑行记录的所有事件
  static Future<List<Map<String, dynamic>>> getEventsByRecordId(int recordId) async {
    final db = await database;
    return await db.query(
      'riding_events',
      where: 'record_id = ?',
      whereArgs: [recordId],
      orderBy: 'timestamp ASC',
    );
  }

  // ========== 每日聚合 ==========

  /// 更新或插入每日统计（UPSERT）
  static Future<void> upsertDailyStats(String date, Map<String, dynamic> stats) async {
    final db = await database;
    final data = Map<String, dynamic>.from(stats);
    data['date'] = date;
    data['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'daily_stats',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 查询指定日期范围的每日统计
  static Future<List<Map<String, dynamic>>> getDailyStatsByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      'daily_stats',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC',
    );
  }

  /// 查询当日统计
  static Future<Map<String, dynamic>?> getDailyStats(String date) async {
    final db = await database;
    final results = await db.query(
      'daily_stats',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ========== 聚合计算 ==========

  /// 计算今日统计（实时从 riding_records 聚合）
  static Future<Map<String, dynamic>> calculateTodayStats() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startTime = startOfDay.millisecondsSinceEpoch;

    final records = await db.query(
      'riding_records',
      where: 'start_time >= ?',
      whereArgs: [startTime],
    );

    return _aggregateRecords(records);
  }

  /// 从 daily_stats 聚合计算近7天/30天统计
  static Future<Map<String, dynamic>> calculatePeriodStats(int days) async {
    final db = await database;
    final now = DateTime.now();
    final endDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final startDate = '${now.subtract(Duration(days: days)).year}-${(now.subtract(Duration(days: days))).month.toString().padLeft(2, '0')}-${(now.subtract(Duration(days: days))).day.toString().padLeft(2, '0')}';

    final dailyStats = await getDailyStatsByDateRange(startDate, endDate);

    double totalDistance = 0;
    int totalDuration = 0;
    double maxSpeed = 0;
    double maxLeftLean = 0;
    double maxRightLean = 0;
    int rideCount = 0;
    double totalSpeedSum = 0;

    for (final stat in dailyStats) {
      totalDistance += (stat['total_distance'] as num?)?.toDouble() ?? 0;
      totalDuration += (stat['total_duration'] as int?) ?? 0;
      maxSpeed = maxSpeed > ((stat['max_speed'] as num?)?.toDouble() ?? 0) ? maxSpeed : ((stat['max_speed'] as num?)?.toDouble() ?? 0);
      maxLeftLean = maxLeftLean > ((stat['max_left_lean'] as num?)?.toDouble() ?? 0) ? maxLeftLean : ((stat['max_left_lean'] as num?)?.toDouble() ?? 0);
      maxRightLean = maxRightLean > ((stat['max_right_lean'] as num?)?.toDouble() ?? 0) ? maxRightLean : ((stat['max_right_lean'] as num?)?.toDouble() ?? 0);
      rideCount += (stat['ride_count'] as int?) ?? 0;
      if ((stat['avg_speed'] as num?)?.toDouble() != null && (stat['ride_count'] as int?) != null) {
        totalSpeedSum += ((stat['avg_speed'] as num).toDouble() * (stat['ride_count'] as int));
      }
    }

    return {
      'distance': totalDistance,
      'duration': totalDuration,
      'avgSpeed': rideCount > 0 ? totalSpeedSum / rideCount : 0.0,
      'maxSpeed': maxSpeed,
      'maxLeftLean': maxLeftLean,
      'maxRightLean': maxRightLean,
      'rideCount': rideCount,
    };
  }

  /// 聚合骑行记录列表
  static Map<String, dynamic> _aggregateRecords(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return {
        'distance': 0.0,
        'duration': 0,
        'avgSpeed': 0.0,
        'maxSpeed': 0.0,
        'maxLeftLean': 0.0,
        'maxRightLean': 0.0,
        'rideCount': 0,
      };
    }

    double totalDistance = 0;
    int totalDuration = 0;
    double maxSpeed = 0;
    double maxLeftLean = 0;
    double maxRightLean = 0;
    double speedSum = 0;

    for (final record in records) {
      totalDistance += (record['distance'] as num?)?.toDouble() ?? 0;
      totalDuration += (record['duration'] as int?) ?? 0;
      maxSpeed = maxSpeed > ((record['max_speed'] as num?)?.toDouble() ?? 0) ? maxSpeed : ((record['max_speed'] as num?)?.toDouble() ?? 0);
      maxLeftLean = maxLeftLean > ((record['max_left_lean'] as num?)?.toDouble() ?? 0) ? maxLeftLean : ((record['max_left_lean'] as num?)?.toDouble() ?? 0);
      maxRightLean = maxRightLean > ((record['max_right_lean'] as num?)?.toDouble() ?? 0) ? maxRightLean : ((record['max_right_lean'] as num?)?.toDouble() ?? 0);
      speedSum += (record['avg_speed'] as num?)?.toDouble() ?? 0;
    }

    return {
      'distance': totalDistance,
      'duration': totalDuration,
      'avgSpeed': records.isNotEmpty ? speedSum / records.length : 0.0,
      'maxSpeed': maxSpeed,
      'maxLeftLean': maxLeftLean,
      'maxRightLean': maxRightLean,
      'rideCount': records.length,
    };
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查语法**

Run: `flutter analyze lib/services/database_service.dart`
Expected: 无 error（warning 可以接受）

- [ ] **Step 3: 提交**

```bash
git add lib/services/database_service.dart
git commit -m "feat: 实现 DatabaseService SQLite 封装"
```

---

### Task 3: 实现 LocationService（GPS 服务）

**Files:**
- Create: `lib/services/location_service.dart`

- [ ] **Step 1: 创建 LocationService**

```dart
import 'package:geolocator/geolocator.dart';

/// GPS定位服务
class LocationService {
  /// 检查定位权限
  static Future<bool> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  /// 请求定位权限
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// 检查定位服务是否开启
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// 获取当前位置
  static Future<Position?> getCurrentPosition() async {
    try {
      // 检查服务
      if (!await isLocationServiceEnabled()) {
        return null;
      }

      // 检查权限
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        final permission = await requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }

      // 获取位置
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取位置更新流（用于持续追踪）
  static Stream<Position> getPositionStream({
    int distanceFilter = 10,  // 米
    Duration? timeLimit,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
      ),
    );
  }
}

/// 位置数据模型（兼容 geolocator）
class PositionData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime timestamp;

  PositionData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.timestamp,
  });

  factory PositionData.fromGeolocator(Position position) {
    return PositionData(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      timestamp: position.timestamp,
    );
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查语法**

Run: `flutter analyze lib/services/location_service.dart`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/services/location_service.dart
git commit -m "feat: 实现 LocationService GPS 服务"
```

---

### Task 4: 实现 GeocodingService（逆地理编码）

**Files:**
- Create: `lib/services/geocoding_service.dart`

- [ ] **Step 1: 创建 GeocodingService**

```dart
import 'package:geocoding/geocoding.dart';

/// 逆地理编码服务 - 将坐标转换为地名
class GeocodingService {
  /// 根据坐标获取地名
  static Future<String?> getPlaceName(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final parts = <String>[];

      if (place.street != null && place.street!.isNotEmpty) {
        parts.add(place.street!);
      }
      if (place.subLocality != null && place.subLocality!.isNotEmpty) {
        parts.add(place.subLocality!);
      }
      if (place.locality != null && place.locality!.isNotEmpty) {
        parts.add(place.locality!);
      }
      if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
        parts.add(place.administrativeArea!);
      }

      return parts.isNotEmpty ? parts.join(' ') : null;
    } catch (e) {
      return null;
    }
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查语法**

Run: `flutter analyze lib/services/geocoding_service.dart`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/services/geocoding_service.dart
git commit -m "feat: 实现 GeocodingService 逆地理编码服务"
```

---

### Task 5: 创建 RidingRecord 模型

**Files:**
- Create: `lib/models/riding_record.dart`

- [ ] **Step 1: 创建 RidingRecord 模型**

```dart
import 'dart:convert';

/// 骑行记录数据模型
class RidingRecord {
  final int? id;
  final int startTime;              // 毫秒时间戳
  final int? endTime;              // 毫秒时间戳
  final double? startLatitude;
  final double? startLongitude;
  final String? startPlaceName;
  final double? endLatitude;
  final double? endLongitude;
  final String? endPlaceName;
  final double distance;           // km
  final double avgSpeed;           // km/h
  final int duration;              // 秒
  final double maxSpeed;           // km/h
  final double maxLeftLean;        // °
  final double maxRightLean;       // °
  final int createdAt;            // 毫秒时间戳

  RidingRecord({
    this.id,
    required this.startTime,
    this.endTime,
    this.startLatitude,
    this.startLongitude,
    this.startPlaceName,
    this.endLatitude,
    this.endLongitude,
    this.endPlaceName,
    this.distance = 0,
    this.avgSpeed = 0,
    this.duration = 0,
    this.maxSpeed = 0,
    this.maxLeftLean = 0,
    this.maxRightLean = 0,
    required this.createdAt,
  });

  /// 从数据库 Map 构造
  factory RidingRecord.fromMap(Map<String, dynamic> map) {
    return RidingRecord(
      id: map['id'] as int?,
      startTime: map['start_time'] as int,
      endTime: map['end_time'] as int?,
      startLatitude: (map['start_latitude'] as num?)?.toDouble(),
      startLongitude: (map['start_longitude'] as num?)?.toDouble(),
      startPlaceName: map['start_place_name'] as String?,
      endLatitude: (map['end_latitude'] as num?)?.toDouble(),
      endLongitude: (map['end_longitude'] as num?)?.toDouble(),
      endPlaceName: map['end_place_name'] as String?,
      distance: (map['distance'] as num?)?.toDouble() ?? 0,
      avgSpeed: (map['avg_speed'] as num?)?.toDouble() ?? 0,
      duration: (map['duration'] as int?) ?? 0,
      maxSpeed: (map['max_speed'] as num?)?.toDouble() ?? 0,
      maxLeftLean: (map['max_left_lean'] as num?)?.toDouble() ?? 0,
      maxRightLean: (map['max_right_lean'] as num?)?.toDouble() ?? 0,
      createdAt: map['created_at'] as int,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'start_time': startTime,
      'end_time': endTime,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'start_place_name': startPlaceName,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'end_place_name': endPlaceName,
      'distance': distance,
      'avg_speed': avgSpeed,
      'duration': duration,
      'max_speed': maxSpeed,
      'max_left_lean': maxLeftLean,
      'max_right_lean': maxRightLean,
      'created_at': createdAt,
    };
  }

  /// 获取格式化时间字符串
  String get formattedStartTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(startTime);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedEndTime {
    if (endTime == null) return '--:--';
    final dt = DateTime.fromMillisecondsSinceEpoch(endTime!);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// 获取骑行时长格式化字符串
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours.${minutes.toString().padLeft(2, '0')}h';
    }
    return '${minutes}min';
  }

  RidingRecord copyWith({
    int? id,
    int? startTime,
    int? endTime,
    double? startLatitude,
    double? startLongitude,
    String? startPlaceName,
    double? endLatitude,
    double? endLongitude,
    String? endPlaceName,
    double? distance,
    double? avgSpeed,
    int? duration,
    double? maxSpeed,
    double? maxLeftLean,
    double? maxRightLean,
    int? createdAt,
  }) {
    return RidingRecord(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      startPlaceName: startPlaceName ?? this.startPlaceName,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      endPlaceName: endPlaceName ?? this.endPlaceName,
      distance: distance ?? this.distance,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      duration: duration ?? this.duration,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      maxLeftLean: maxLeftLean ?? this.maxLeftLean,
      maxRightLean: maxRightLean ?? this.maxRightLean,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 骑行事件数据模型（用于存储到数据库）
class RidingRecordEvent {
  final int? id;
  final int? recordId;
  final String type;
  final String title;
  final String? description;
  final double triggerValue;
  final double threshold;
  final int timestamp;
  final Map<String, dynamic>? additionalData;

  RidingRecordEvent({
    this.id,
    this.recordId,
    required this.type,
    required this.title,
    this.description,
    required this.triggerValue,
    required this.threshold,
    required this.timestamp,
    this.additionalData,
  });

  factory RidingRecordEvent.fromMap(Map<String, dynamic> map) {
    return RidingRecordEvent(
      id: map['id'] as int?,
      recordId: map['record_id'] as int?,
      type: map['type'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      triggerValue: (map['trigger_value'] as num?)?.toDouble() ?? 0,
      threshold: (map['threshold'] as num?)?.toDouble() ?? 0,
      timestamp: map['timestamp'] as int,
      additionalData: map['additional_data'] != null
          ? json.decode(map['additional_data'] as String) as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (recordId != null) 'record_id': recordId,
      'type': type,
      'title': title,
      'description': description,
      'trigger_value': triggerValue,
      'threshold': threshold,
      'timestamp': timestamp,
      'additional_data': additionalData != null ? json.encode(additionalData) : null,
    };
  }

  String get formattedTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

/// 每日统计模型
class DailyStats {
  final String date;              // '2026-03-26'
  final double totalDistance;      // km
  final int totalDuration;         // 秒
  final double avgSpeed;           // km/h
  final double maxSpeed;           // km/h
  final double maxLeftLean;        // °
  final double maxRightLean;       // °
  final int rideCount;

  DailyStats({
    required this.date,
    this.totalDistance = 0,
    this.totalDuration = 0,
    this.avgSpeed = 0,
    this.maxSpeed = 0,
    this.maxLeftLean = 0,
    this.maxRightLean = 0,
    this.rideCount = 0,
  });

  factory DailyStats.fromMap(Map<String, dynamic> map) {
    return DailyStats(
      date: map['date'] as String,
      totalDistance: (map['total_distance'] as num?)?.toDouble() ?? 0,
      totalDuration: (map['total_duration'] as int?) ?? 0,
      avgSpeed: (map['avg_speed'] as num?)?.toDouble() ?? 0,
      maxSpeed: (map['max_speed'] as num?)?.toDouble() ?? 0,
      maxLeftLean: (map['max_left_lean'] as num?)?.toDouble() ?? 0,
      maxRightLean: (map['max_right_lean'] as num?)?.toDouble() ?? 0,
      rideCount: (map['ride_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'total_distance': totalDistance,
      'total_duration': totalDuration,
      'avg_speed': avgSpeed,
      'max_speed': maxSpeed,
      'max_left_lean': maxLeftLean,
      'max_right_lean': maxRightLean,
      'ride_count': rideCount,
    };
  }
}

/// 聚合统计数据模型
class AggregationStats {
  final double distance;      // km
  final int duration;         // 秒
  final double avgSpeed;      // km/h
  final double maxSpeed;      // km/h
  final double maxLeftLean;   // °
  final double maxRightLean;  // °
  final int rideCount;

  AggregationStats({
    this.distance = 0,
    this.duration = 0,
    this.avgSpeed = 0,
    this.maxSpeed = 0,
    this.maxLeftLean = 0,
    this.maxRightLean = 0,
    this.rideCount = 0,
  });

  factory AggregationStats.fromMap(Map<String, dynamic> map) {
    return AggregationStats(
      distance: (map['distance'] as num?)?.toDouble() ?? 0,
      duration: (map['duration'] as int?) ?? 0,
      avgSpeed: (map['avgSpeed'] as num?)?.toDouble() ?? 0,
      maxSpeed: (map['maxSpeed'] as num?)?.toDouble() ?? 0,
      maxLeftLean: (map['maxLeftLean'] as num?)?.toDouble() ?? 0,
      maxRightLean: (map['maxRightLean'] as num?)?.toDouble() ?? 0,
      rideCount: (map['rideCount'] as int?) ?? 0,
    );
  }

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    return '$hours.${minutes.toString().padLeft(2, '0')}h';
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查语法**

Run: `flutter analyze lib/models/riding_record.dart`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/models/riding_record.dart
git commit -m "feat: 添加 RidingRecord 数据模型"
```

---

### Task 6: 创建 RidingRecordProvider（记录状态管理）

**Files:**
- Create: `lib/providers/riding_record_provider.dart`

- [ ] **Step 1: 创建 RidingRecordProvider**

```dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/riding_record.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';

/// 骑行记录 Provider
class RidingRecordProvider extends ChangeNotifier {
  List<RidingRecord> _records = [];
  AggregationStats _todayStats = AggregationStats();
  AggregationStats _weekStats = AggregationStats();
  AggregationStats _monthStats = AggregationStats();
  bool _isLoading = false;

  List<RidingRecord> get records => _records;
  AggregationStats get todayStats => _todayStats;
  AggregationStats get weekStats => _weekStats;
  AggregationStats get monthStats => _monthStats;
  bool get isLoading => _isLoading;

  /// 初始化 - 加载所有记录和统计数据
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      _loadRecords(),
      _loadTodayStats(),
      _loadWeekStats(),
      _loadMonthStats(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  /// 加载所有骑行记录
  Future<void> _loadRecords() async {
    final maps = await DatabaseService.getAllRidingRecords();
    _records = maps.map((m) => RidingRecord.fromMap(m)).toList();
  }

  /// 加载今日统计（实时计算）
  Future<void> _loadTodayStats() async {
    final stats = await DatabaseService.calculateTodayStats();
    _todayStats = AggregationStats.fromMap(stats);
  }

  /// 加载近7天统计（从 daily_stats 聚合）
  Future<void> _loadWeekStats() async {
    final stats = await DatabaseService.calculatePeriodStats(7);
    _weekStats = AggregationStats.fromMap(stats);
  }

  /// 加载近30天统计（从 daily_stats 聚合）
  Future<void> _loadMonthStats() async {
    final stats = await DatabaseService.calculatePeriodStats(30);
    _monthStats = AggregationStats.fromMap(stats);
  }

  /// 获取指定骑行记录的事件列表
  Future<List<RidingRecordEvent>> getEventsForRecord(int recordId) async {
    final maps = await DatabaseService.getEventsByRecordId(recordId);
    return maps.map((m) => RidingRecordEvent.fromMap(m)).toList();
  }

  /// 删除骑行记录
  Future<void> deleteRecord(int id) async {
    await DatabaseService.deleteRidingRecord(id);
    _records.removeWhere((r) => r.id == id);
    notifyListeners();

    // 重新加载统计数据
    await Future.wait([
      _loadTodayStats(),
      _loadWeekStats(),
      _loadMonthStats(),
    ]);
    notifyListeners();
  }

  /// 保存骑行记录（骑行结束时调用）
  Future<void> saveRidingRecord({
    required int startTime,
    required int endTime,
    required int duration,
    required double distance,
    required double avgSpeed,
    required double maxSpeed,
    required double maxLeftLean,
    required double maxRightLean,
    required List<RidingRecordEvent> events,
  }) async {
    // 获取起点位置
    final startPosition = await LocationService.getCurrentPosition();
    String? startPlaceName;
    if (startPosition != null) {
      startPlaceName = await GeocodingService.getPlaceName(
        startPosition.latitude,
        startPosition.longitude,
      );
    }

    // 获取终点位置
    final endPosition = await LocationService.getCurrentPosition();
    String? endPlaceName;
    if (endPosition != null) {
      endPlaceName = await GeocodingService.getPlaceName(
        endPosition.latitude,
        endPosition.longitude,
      );
    }

    // 创建记录
    final record = RidingRecord(
      startTime: startTime,
      endTime: endTime,
      startLatitude: startPosition?.latitude,
      startLongitude: startPosition?.longitude,
      startPlaceName: startPlaceName,
      endLatitude: endPosition?.latitude,
      endLongitude: endPosition?.longitude,
      endPlaceName: endPlaceName,
      distance: distance,
      avgSpeed: avgSpeed,
      duration: duration,
      maxSpeed: maxSpeed,
      maxLeftLean: maxLeftLean,
      maxRightLean: maxRightLean,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // 保存到数据库
    final id = await DatabaseService.insertRidingRecord(record.toMap());

    // 保存事件
    if (events.isNotEmpty) {
      await DatabaseService.insertRidingEvents(
        id,
        events.map((e) => e.toMap()).toList(),
      );
    }

    // 更新每日统计
    await _updateDailyStats(endTime, distance, duration, avgSpeed, maxSpeed, maxLeftLean, maxRightLean);

    // 重新加载
    await initialize();
  }

  /// 更新每日统计
  Future<void> _updateDailyStats(
    int endTime,
    double distance,
    int duration,
    double avgSpeed,
    double maxSpeed,
    double maxLeftLean,
    double maxRightLean,
  ) async {
    final endDate = DateTime.fromMillisecondsSinceEpoch(endTime);
    final dateStr = DateFormat('yyyy-MM-dd').format(endDate);

    // 获取现有统计
    final existing = await DatabaseService.getDailyStats(dateStr);
    final stats = existing != null
        ? DailyStats.fromMap(existing)
        : DailyStats(date: dateStr);

    // 更新统计
    final updatedStats = DailyStats(
      date: dateStr,
      totalDistance: stats.totalDistance + distance,
      totalDuration: stats.totalDuration + duration,
      avgSpeed: _calculateWeightedAvg(
        stats.avgSpeed, stats.rideCount,
        avgSpeed, 1,
      ),
      maxSpeed: maxSpeed > stats.maxSpeed ? maxSpeed : stats.maxSpeed,
      maxLeftLean: maxLeftLean > stats.maxLeftLean ? maxLeftLean : stats.maxLeftLean,
      maxRightLean: maxRightLean > stats.maxRightLean ? maxRightLean : stats.maxRightLean,
      rideCount: stats.rideCount + 1,
    );

    await DatabaseService.upsertDailyStats(dateStr, updatedStats.toMap());
  }

  /// 计算加权平均
  double _calculateWeightedAvg(
    double avg1, int count1,
    double avg2, int count2,
  ) {
    if (count1 + count2 == 0) return 0;
    return (avg1 * count1 + avg2 * count2) / (count1 + count2);
  }

  /// 刷新统计数据
  Future<void> refreshStats() async {
    await Future.wait([
      _loadTodayStats(),
      _loadWeekStats(),
      _loadMonthStats(),
    ]);
    notifyListeners();
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查语法**

Run: `flutter analyze lib/providers/riding_record_provider.dart`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/providers/riding_record_provider.dart
git commit -m "feat: 实现 RidingRecordProvider 骑行记录状态管理"
```

---

### Task 7: 修改 MainContainer 添加 RECORD 页面入口

**Files:**
- Modify: `lib/screens/main_container.dart`
- Modify: `lib/main.dart`
- Create: `lib/screens/record_screen.dart`

- [ ] **Step 1: 创建 RecordScreen 占位页面**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 骑行记录页面
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'RECORD - 待实现',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
    );
  }
}
```

- [ ] **Step 2: 修改 MainContainer 添加 RECORD 页面**

在 `_pages` 列表中添加 `RecordScreen()`，位于 `DashboardScreen()` 和 `LogsScreen()` 之间：

```dart
final List<Widget> _pages = const [
  DashboardScreen(),
  RecordScreen(),  // 新增
  LogsScreen(),
  BluetoothScanScreen(),
];
```

同时修改 `TopNavigationBar` 的 `navItems`：

```dart
this.navItems = const ['DASHBOARD', 'RECORD', 'LOGS', 'DEVICES'],
```

- [ ] **Step 3: 修改 main.dart 添加 RidingRecordProvider**

在 `MultiProvider` 中添加：

```dart
ChangeNotifierProvider<RidingRecordProvider>(
  create: (_) => RidingRecordProvider(),
),
```

- [ ] **Step 4: 运行 flutter analyze 检查**

Run: `flutter analyze`
Expected: 无 error

- [ ] **Step 5: 提交**

```bash
git add lib/screens/main_container.dart lib/screens/record_screen.dart lib/main.dart
git commit -m "feat: 添加 RECORD 页面入口（占位）"
```

---

### Task 8: 实现 RecordScreen 页面

**Files:**
- Modify: `lib/screens/record_screen.dart`

- [ ] **Step 1: 实现完整 RecordScreen**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/riding_record_provider.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';
import '../widgets/stats_summary_card.dart';
import '../widgets/swipeable_record_card.dart';
import '../widgets/ride_event_list_modal.dart';

/// 骑行记录页面
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  int _selectedTabIndex = 0;  // 0=今天, 1=近7天, 2=近30天

  @override
  void initState() {
    super.initState();
    // 初始化加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RidingRecordProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundDark,
      child: SafeArea(
        child: Column(
          children: [
            // Tab 切换
            _buildTabBar(),
            // 聚合统计
            _buildStatsSummary(),
            // 骑行历史列表
            Expanded(child: _buildRecordsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTabButton('今天', 0),
          const SizedBox(width: 8),
          _buildTabButton('近一周', 1),
          const SizedBox(width: 8),
          _buildTabButton('近一月', 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.slateGray,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.primary20,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    return Consumer<RidingRecordProvider>(
      builder: (context, provider, _) {
        AggregationStats stats;
        switch (_selectedTabIndex) {
          case 1:
            stats = provider.weekStats;
            break;
          case 2:
            stats = provider.monthStats;
            break;
          default:
            stats = provider.todayStats;
        }
        return StatsSummaryCard(stats: stats);
      },
    );
  }

  Widget _buildRecordsList() {
    return Consumer<RidingRecordProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        if (provider.records.isEmpty) {
          return Center(
            child: Text(
              '暂无骑行记录',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: provider.records.length,
          itemBuilder: (context, index) {
            final record = provider.records[index];
            return SwipeableRecordCard(
              record: record,
              onViewEvents: () => _showEventsModal(record),
              onDelete: () => _confirmDelete(record),
            );
          },
        );
      },
    );
  }

  void _showEventsModal(RidingRecord record) async {
    final provider = context.read<RidingRecordProvider>();
    final events = await provider.getEventsForRecord(record.id!);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => RideEventListModal(events: events),
    );
  }

  void _confirmDelete(RidingRecord record) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmDialog(
        onConfirm: () {
          context.read<RidingRecordProvider>().deleteRecord(record.id!);
        },
      ),
    );
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查**

Run: `flutter analyze lib/screens/record_screen.dart`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/screens/record_screen.dart
git commit -m "feat: 实现 RecordScreen 骑行记录页面"
```

---

### Task 9: 实现 StatsSummaryCard 聚合统计卡片

**Files:**
- Create: `lib/widgets/stats_summary_card.dart`

- [ ] **Step 1: 创建 StatsSummaryCard**

```dart
import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';

/// 聚合统计卡片组件
class StatsSummaryCard extends StatelessWidget {
  final AggregationStats stats;

  const StatsSummaryCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.surfaceBorderDefault,
      child: Row(
        children: [
          Expanded(child: _buildStatItem('骑行距离', '${stats.distance.toStringAsFixed(1)} km', AppTheme.textPrimary)),
          Expanded(child: _buildStatItem('平均速度', '${stats.avgSpeed.toStringAsFixed(1)} km/h', AppTheme.accentCyan)),
          Expanded(child: _buildStatItem('骑行时间', stats.formattedDuration, AppTheme.accentGreen)),
          Expanded(child: _buildStatItem('最快速度', '${stats.maxSpeed.toStringAsFixed(0)} km/h', AppTheme.accentOrange)),
          Expanded(child: _buildLeanAngle()),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTheme.labelSmall.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.valueMedium.copyWith(color: valueColor),
        ),
      ],
    );
  }

  Widget _buildLeanAngle() {
    final left = stats.maxLeftLean;
    final right = stats.maxRightLean;
    final maxLean = left > right ? left : right;
    final direction = left > right ? '左' : '右';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '最大倾角',
          style: AppTheme.labelSmall.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          '${maxLean.toStringAsFixed(0)}°$direction',
          style: AppTheme.valueMedium.copyWith(color: AppTheme.accentPink),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查**

Run: `flutter analyze lib/widgets/stats_summary_card.dart`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/widgets/stats_summary_card.dart
git commit -m "feat: 实现 StatsSummaryCard 聚合统计卡片"
```

---

### Task 10: 实现 SwipeableRecordCard 可滑动删除的记录卡片

**Files:**
- Create: `lib/widgets/swipeable_record_card.dart`

- [ ] **Step 1: 创建 SwipeableRecordCard**

```dart
import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';
import 'delete_confirm_dialog.dart';

/// 可滑动删除的骑行记录卡片
class SwipeableRecordCard extends StatefulWidget {
  final RidingRecord record;
  final VoidCallback onViewEvents;
  final VoidCallback onDelete;

  const SwipeableRecordCard({
    super.key,
    required this.record,
    required this.onViewEvents,
    required this.onDelete,
  });

  @override
  State<SwipeableRecordCard> createState() => _SwipeableRecordCardState();
}

class _SwipeableRecordCardState extends State<SwipeableRecordCard> {
  double _dragExtent = 0;
  static const double _deleteButtonWidth = 80;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragExtent = (_dragExtent + details.delta.dx).clamp(-_deleteButtonWidth, 0);
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragExtent < -_deleteButtonWidth / 2) {
          setState(() => _dragExtent = -_deleteButtonWidth);
        } else {
          setState(() => _dragExtent = 0);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Stack(
          children: [
            // 删除按钮（在卡片下面）
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => _showDeleteConfirm(),
                child: Container(
                  width: _deleteButtonWidth,
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: const Center(
                    child: Text(
                      '删除',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 卡片主体
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              transform: Matrix4.translationValues(_dragExtent, 0, 0),
              child: _buildCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final record = widget.record;
    final showDeleteButton = _dragExtent < -10;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.primary20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：时间和查看事件按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${record.formattedStartTime} → ${record.formattedEndTime}',
                style: AppTheme.valueMedium.copyWith(color: AppTheme.textPrimary),
              ),
              if (!showDeleteButton)
                GestureDetector(
                  onTap: widget.onViewEvents,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.slateGray,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      '查看事件',
                      style: AppTheme.labelSmall.copyWith(color: AppTheme.primary),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // 第二行：地点
          Text(
            '${record.startPlaceName ?? '未知'} → ${record.endPlaceName ?? '未知'}',
            style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          // 第三行：统计数据
          Row(
            children: [
              _buildStat('距离', '${record.distance.toStringAsFixed(1)}km'),
              _buildStat('均速', '${record.avgSpeed.toStringAsFixed(0)}km/h'),
              _buildStat('极速', '${record.maxSpeed.toStringAsFixed(0)}km/h'),
              _buildLeanAngle(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Expanded(
      child: Text(
        '$label:$value',
        style: AppTheme.labelMedium.copyWith(color: AppTheme.textMuted),
      ),
    );
  }

  Widget _buildLeanAngle() {
    final record = widget.record;
    final left = record.maxLeftLean;
    final right = record.maxRightLean;
    final maxLean = left > right ? left : right;
    final direction = left > right ? '左' : '右';

    return Expanded(
      child: Text(
        '倾角:${maxLean.toStringAsFixed(0)}°$direction',
        style: AppTheme.labelMedium.copyWith(color: AppTheme.accentPink),
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => DeleteConfirmDialog(onConfirm: widget.onDelete),
    );
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查**

Run: `flutter analyze lib/widgets/swipeable_record_card.dart`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/widgets/swipeable_record_card.dart
git commit -m "feat: 实现 SwipeableRecordCard 可滑动删除卡片"
```

---

### Task 11: 实现 DeleteConfirmDialog 删除确认弹窗

**Files:**
- Create: `lib/widgets/delete_confirm_dialog.dart`

- [ ] **Step 1: 创建 DeleteConfirmDialog**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 删除确认弹窗
class DeleteConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteConfirmDialog({super.key, required this.onConfirm});

  static Future<void> show(BuildContext context, {required VoidCallback onConfirm}) {
    return showDialog(
      context: context,
      builder: (ctx) => DeleteConfirmDialog(onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.accentRed50),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '确认删除',
              style: AppTheme.titleMedium.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              '确定要删除这条骑行记录吗？\n删除后无法恢复。',
              textAlign: TextAlign.center,
              style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.slateGray,
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      ),
                      child: Center(
                        child: Text(
                          '取消',
                          style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed,
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      ),
                      child: Center(
                        child: Text(
                          '删除',
                          style: AppTheme.labelMedium.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 扩展 Color 支持 accentRed50
extension ColorExtension on Color {
  static const Color accentRed50 = Color(0x80FF4D4D);
}
```

- [ ] **Step 2: 运行 flutter analyze 检查**

Run: `flutter analyze lib/widgets/delete_confirm_dialog.dart`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/widgets/delete_confirm_dialog.dart
git commit -m "feat: 实现 DeleteConfirmDialog 删除确认弹窗"
```

---

### Task 12: 实现 RideEventListModal 事件列表弹窗

**Files:**
- Create: `lib/widgets/ride_event_list_modal.dart`

- [ ] **Step 1: 创建 RideEventListModal**

```dart
import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';

/// 骑行事件列表弹窗
class RideEventListModal extends StatelessWidget {
  final List<RidingRecordEvent> events;

  const RideEventListModal({super.key, required this.events});

  static Future<void> show(BuildContext context, List<RidingRecordEvent> events) {
    return showDialog(
      context: context,
      builder: (ctx) => RideEventListModal(events: events),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.primary40),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              '骑行事件列表 · 共${events.length}个事件',
              style: AppTheme.labelMediumPrimary12.copyWith(color: AppTheme.primary),
            ),
            const SizedBox(height: 12),
            // 事件列表
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: events.length,
                itemBuilder: (context, index) {
                  return _buildEventItem(events[index]);
                },
              ),
            ),
            const SizedBox(height: 12),
            // 关闭按钮
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
                child: Center(
                  child: Text(
                    '关闭',
                    style: AppTheme.labelMedium.copyWith(color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(RidingRecordEvent event) {
    final color = _getEventColor(event.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.slateGray,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                event.title,
                style: AppTheme.labelMedium.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                event.formattedTime,
                style: AppTheme.labelSmall.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
          if (event.description != null) ...[
            const SizedBox(height: 4),
            Text(
              event.description!,
              style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'RidingEventType.extremeLean':
        return AppTheme.accentPink;
      case 'RidingEventType.efficientCruising':
        return AppTheme.accentOrange;
      case 'RidingEventType.performanceBurst':
        return AppTheme.primary;
      case 'RidingEventType.engineOverheating':
        return AppTheme.accentRed;
      case 'RidingEventType.highEngineLoad':
        return AppTheme.accentOrange;
      default:
        return AppTheme.textSecondary;
    }
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查**

Run: `flutter analyze lib/widgets/ride_event_list_modal.dart`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/widgets/ride_event_list_modal.dart
git commit -m "feat: 实现 RideEventListModal 事件列表弹窗"
```

---

### Task 13: 修改 RidingStatsProvider 骑行结束时保存记录

**Files:**
- Modify: `lib/providers/riding_stats_provider.dart`

- [ ] **Step 1: 添加 RidingRecordProvider 依赖并调用保存**

在 `RidingStatsProvider` 中：
1. 添加 `RidingRecordProvider` 参数
2. 在 `endRide()` 方法中调用保存

```dart
import '../providers/riding_record_provider.dart';  // 新增导入

class RidingStatsProvider extends ChangeNotifier {
  final OBDDataProvider _obdDataProvider;
  final AudioService? _audioService;
  final RidingRecordProvider? _ridingRecordProvider;  // 新增

  // ... 构造函数更新 ...
  RidingStatsProvider({
    required OBDDataProvider obdDataProvider,
    required LogProvider logProvider,
    AudioService? audioService,
    RidingRecordProvider? ridingRecordProvider,  // 新增
  })  : _obdDataProvider = obdDataProvider,
        _audioService = audioService,
        _ridingRecordProvider = ridingRecordProvider {  // 新增
    _logCallback = createLogger(logProvider);
  }

  // ... endRide 方法更新 ...
  void endRide() {
    _isRiding = false;
    _stopSampling();
    GSX8SCalculator.reset();

    final duration = _rideStartTime != null
        ? DateTime.now().difference(_rideStartTime!).inSeconds
        : 0;
    _logCallback?.call('Stats', LogType.info, '骑行结束，总时长: ${duration ~/ 60}分钟');
    notifyListeners();

    // 保存骑行记录
    _saveRidingRecord(duration);
  }

  // 新增方法
  void _saveRidingRecord(int duration) {
    if (_ridingRecordProvider == null || _rideStartTime == null) return;

    // 计算统计数据
    final distance = _calculateTotalDistance();
    final avgSpeed = duration > 0 ? (distance / (duration / 3600)) : 0.0;
    final maxSpeed = _getMaxSpeed();
    final maxLeftLean = _getMaxLeanAngle('left');
    final maxRightLean = _getMaxLeanAngle('right');

    // 转换事件
    final events = _eventHistory.map((e) => RidingRecordEvent(
      type: e.type.toString(),
      title: e.title,
      description: e.description,
      triggerValue: e.triggerValue,
      threshold: e.threshold,
      timestamp: e.timestamp.millisecondsSinceEpoch,
      additionalData: e.additionalData,
    )).toList();

    _ridingRecordProvider.saveRidingRecord(
      startTime: _rideStartTime!.millisecondsSinceEpoch,
      endTime: DateTime.now().millisecondsSinceEpoch,
      duration: duration,
      distance: distance,
      avgSpeed: avgSpeed,
      maxSpeed: maxSpeed,
      maxLeftLean: maxLeftLean,
      maxRightLean: maxRightLean,
      events: events,
    );
  }

  double _calculateTotalDistance() {
    // TODO: 实现距离计算（需要GPS轨迹或速度积分）
    // 暂时返回 0，后续与 GPS 服务集成后实现
    return 0;
  }

  double _getMaxSpeed() {
    // 从历史数据中获取最大速度
    double max = 0;
    for (final event in _eventHistory) {
      final speed = event.additionalData['vehicleSpeed'] as double?;
      if (speed != null && speed > max) max = speed;
    }
    return max;
  }

  double _getMaxLeanAngle(String direction) {
    double max = 0;
    for (final event in _eventHistory) {
      if (event.additionalData['direction'] == direction) {
        final angle = event.additionalData['leanAngle'] as double?;
        if (angle != null && angle.abs() > max) max = angle.abs();
      }
    }
    return max;
  }
}
```

- [ ] **Step 2: 更新 main.dart 中 RidingStatsProvider 的创建**

```dart
// 骑行统计 Provider
ChangeNotifierProxyProvider2<OBDDataProvider, LogProvider, RidingStatsProvider>(
  create: (context) => RidingStatsProvider(
    obdDataProvider: context.read<OBDDataProvider>(),
    logProvider: context.read<LogProvider>(),
    audioService: context.read<AudioService>(),
    ridingRecordProvider: context.read<RidingRecordProvider>(),
  ),
  update: (context, obdDataProvider, logProvider, previous) =>
      previous ??
      RidingStatsProvider(
        obdDataProvider: obdDataProvider,
        logProvider: logProvider,
        audioService: context.read<AudioService>(),
        ridingRecordProvider: context.read<RidingRecordProvider>(),
      ),
),
```

注意：`RidingRecordProvider` 需要在 `RidingStatsProvider` 之前创建，否则会报错。需要调整 Provider 顺序。

- [ ] **Step 3: 运行 flutter analyze 检查**

Run: `flutter analyze`
Expected: 无 error

- [ ] **Step 4: 提交**

```bash
git add lib/providers/riding_stats_provider.dart lib/main.dart
git commit -m "feat: 集成 RidingStatsProvider 保存骑行记录到数据库"
```

---

## 自检清单

- [ ] Spec 覆盖检查：每个需求都有对应 Task 实现
- [ ] 占位符扫描：无 "TBD"、"TODO" 等占位符
- [ ] 类型一致性：模型属性、方法签名一致
- [ ] 无新增 warning

---

**Plan complete and saved to `docs/superpowers/plans/2026-03-26-riding-records.md`.**

**Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
