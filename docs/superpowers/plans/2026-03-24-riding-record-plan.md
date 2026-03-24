# Riding Record Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增骑行记录功能模块，记录 GPS 轨迹与 OBD 数据统计，支持本地持久化和历史查看。

**Architecture:** 使用 Provider 状态管理，RidingRecordProvider 集中管理骑行状态。GPS 采样通过 geolocator 实现，轨迹数据存储在 Hive 本地数据库，地图使用 flutter_map + OpenStreetMap。蓝牙连接状态触发自动开始/停止。

**Tech Stack:** geolocator, flutter_map, latlong2, hive, hive_flutter

---

## File Structure

```
lib/
├── models/
│   └── riding_record.dart          # [新建] RidingRecord, TrackPoint 模型
├── providers/
│   └── riding_record_provider.dart  # [新建] 骑行记录状态管理
├── services/
│   └── gps_service.dart            # [新建] GPS 位置跟踪服务
├── screens/
│   ├── riding_history_screen.dart   # [新建] 历史记录列表页
│   └── riding_record_screen.dart    # [新建] 实时骑行记录页
└── widgets/
    ├── riding_record_card.dart      # [新建] 历史记录卡片
    └── mini_track_preview.dart      # [新建] 缩略轨迹图

[修改]
├── pubspec.yaml                    # 添加依赖
├── lib/main.dart                   # 注册 RidingRecordProvider
├── lib/screens/main_container.dart  # 添加页面 + 自动流程
├── android/app/src/main/AndroidManifest.xml  # 位置权限
└── lib/widgets/top_navigation_bar.dart     # 添加骑行记录 Tab
```

---

## Task 1: 添加依赖包

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加依赖**

```yaml
dependencies:
  # ... existing deps
  geolocator: ^11.0.0
  flutter_map: ^6.1.0
  latlong2: ^0.9.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
```

Run: `flutter pub add geolocator flutter_map latlong2 hive hive_flutter`
Expected: Dependencies added successfully

- [ ] **Step 2: Commit**

```bash
git add pubspec.yaml
git commit -m "feat: add geolocator, flutter_map, hive dependencies for riding record"
```

---

## Task 2: 添加位置权限

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 添加 ACCESS_COARSE_LOCATION 权限**

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat: add location permissions for GPS tracking"
```

---

## Task 3: 创建数据模型

**Files:**
- Create: `lib/models/riding_record.dart`

- [ ] **Step 1: 创建 RidingRecord 和 TrackPoint 模型**

```dart
import 'package:latlong2/latlong.dart';
import 'riding_event.dart';

/// 骑行记录模型
class RidingRecord {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double distance;         // 里程 (km)
  final Duration duration;       // 时长
  final double maxSpeed;         // 最高速度 (km/h)
  final double avgSpeed;         // 平均速度 (km/h)
  final int maxLeanLeft;        // 左倾最大角度
  final int maxLeanRight;       // 右倾最大角度
  final Map<RidingEventType, int> eventCounts;  // 事件统计
  final List<TrackPoint> trackPoints;          // GPS轨迹点
  final bool isCompleted;        // 是否已完成

  RidingRecord({
    required this.id,
    required this.startTime,
    this.endTime,
    this.distance = 0,
    this.duration = Duration.zero,
    this.maxSpeed = 0,
    this.avgSpeed = 0,
    this.maxLeanLeft = 0,
    this.maxLeanRight = 0,
    this.eventCounts = const {},
    this.trackPoints = const [],
    this.isCompleted = false,
  });

  RidingRecord copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    double? distance,
    Duration? duration,
    double? maxSpeed,
    double? avgSpeed,
    int? maxLeanLeft,
    int? maxLeanRight,
    Map<RidingEventType, int>? eventCounts,
    List<TrackPoint>? trackPoints,
    bool? isCompleted,
  }) {
    return RidingRecord(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      maxLeanLeft: maxLeanLeft ?? this.maxLeanLeft,
      maxLeanRight: maxLeanRight ?? this.maxLeanRight,
      eventCounts: eventCounts ?? this.eventCounts,
      trackPoints: trackPoints ?? this.trackPoints,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// 计算平均速度
  double calculateAvgSpeed() {
    if (duration.inMinutes == 0) return 0;
    return (distance / duration.inMinutes) * 60;
  }
}

/// 轨迹点模型
class TrackPoint {
  final double latitude;
  final double longitude;
  final double speed;       // 对应速度 (km/h)
  final DateTime timestamp;

  TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.timestamp,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'speed': speed,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
    latitude: json['latitude'] as double,
    longitude: json['longitude'] as double,
    speed: json['speed'] as double,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/riding_record.dart
git commit -m "feat: add RidingRecord and TrackPoint models"
```

---

## Task 4: 创建 GPS 服务

**Files:**
- Create: `lib/services/gps_service.dart`

- [ ] **Step 1: 创建 GPS 服务**

```dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/riding_record.dart';

/// GPS 服务 - 负责位置跟踪和轨迹点采集
class GPSService {
  StreamSubscription<Position>? _positionSubscription;
  final void Function(TrackPoint)? onTrackPoint;

  GPSService({this.onTrackPoint});

  /// 检查并请求位置权限
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// 获取当前位置
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// 开始位置跟踪
  void startTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 移动超过5米才更新
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (position.accuracy > 20) return; // 过滤精度过低的数据

      final trackPoint = TrackPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed * 3.6, // m/s 转 km/h
        timestamp: DateTime.now(),
      );
      onTrackPoint?.call(trackPoint);
    });
  }

  /// 停止位置跟踪
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    stopTracking();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/gps_service.dart
git commit -m "feat: add GPS service for location tracking"
```

---

## Task 5: 创建 RidingRecordProvider

**Files:**
- Create: `lib/providers/riding_record_provider.dart`

- [ ] **Step 1: 创建 RidingRecordProvider**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../models/riding_record.dart';
import '../models/riding_event.dart';
import '../services/gps_service.dart';
import 'log_provider.dart';
import 'loggable.dart';

/// 骑行记录 Provider
class RidingRecordProvider extends ChangeNotifier {
  final LogProvider _logProvider;
  late final void Function(String source, LogType type, String message) _logCallback;

  final GPSService _gpsService = GPSService();
  StreamSubscription<Position>? _gpsSubscription;

  // 当前骑行记录
  RidingRecord? _currentRecord;
  bool _isTracking = false;

  // 实时统计
  double _currentSpeed = 0;
  double _maxSpeed = 0;
  double _totalDistance = 0;
  Duration _duration = Duration.zero;
  int _maxLeanLeft = 0;
  int _maxLeanRight = 0;
  Timer? _durationTimer;
  DateTime? _lastTrackTime;

  // 历史记录
  List<RidingRecord> _records = [];

  // Getters
  bool get isTracking => _isTracking;
  RidingRecord? get currentRecord => _currentRecord;
  List<RidingRecord> get records => _records;
  double get currentSpeed => _currentSpeed;
  double get maxSpeed => _maxSpeed;
  double get totalDistance => _totalDistance;
  Duration get duration => _duration;
  int get maxLeanLeft => _maxLeanLeft;
  int get maxLeanRight => _maxLeanRight;

  // Hive box
  static const String _boxName = 'riding_records';
  Box? _box;

  RidingRecordProvider({required LogProvider logProvider})
      : _logProvider = logProvider {
    _logCallback = createLogger(logProvider);
  }

  /// 初始化（必须在使用前调用）
  Future<void> initialize() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    await _loadRecords();
  }

  /// 从 Hive 加载历史记录
  Future<void> _loadRecords() async {
    if (_box == null) return;
    final List<RidingRecord> loaded = [];
    for (var key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        loaded.add(_recordFromMap(Map<String, dynamic>.from(data)));
      }
    }
    loaded.sort((a, b) => b.startTime.compareTo(a.startTime));
    _records = loaded;
    notifyListeners();
  }

  /// 保存记录到 Hive
  Future<void> _saveRecord(RidingRecord record) async {
    await _box?.put(record.id, _recordToMap(record));
    await _loadRecords();
  }

  Map<String, dynamic> _recordToMap(RidingRecord record) => {
    'id': record.id,
    'startTime': record.startTime.toIso8601String(),
    'endTime': record.endTime?.toIso8601String(),
    'distance': record.distance,
    'durationMs': record.duration.inMilliseconds,
    'maxSpeed': record.maxSpeed,
    'avgSpeed': record.avgSpeed,
    'maxLeanLeft': record.maxLeanLeft,
    'maxLeanRight': record.maxLeanRight,
    'eventCounts': record.eventCounts.map((k, v) => MapEntry(k.index.toString(), v)),
    'trackPoints': record.trackPoints.map((p) => p.toJson()).toList(),
    'isCompleted': record.isCompleted,
  };

  factory RidingRecord._recordFromMap(Map<String, dynamic> map) => RidingRecord(
    id: map['id'] as String,
    startTime: DateTime.parse(map['startTime'] as String),
    endTime: map['endTime'] != null ? DateTime.parse(map['endTime'] as String) : null,
    distance: (map['distance'] as num).toDouble(),
    duration: Duration(milliseconds: map['durationMs'] as int),
    maxSpeed: (map['maxSpeed'] as num).toDouble(),
    avgSpeed: (map['avgSpeed'] as num).toDouble(),
    maxLeanLeft: map['maxLeanLeft'] as int,
    maxLeanRight: map['maxLeanRight'] as int,
    eventCounts: (map['eventCounts'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(RidingEventType.values[int.parse(k)], v as int),
    ) ?? {},
    trackPoints: (map['trackPoints'] as List?)
        ?.map((p) => TrackPoint.fromJson(Map<String, dynamic>.from(p)))
        .toList() ?? [],
    isCompleted: map['isCompleted'] as bool? ?? false,
  )..copyWith(
    duration: Duration(milliseconds: map['durationMs'] as int),
  );

  /// 开始骑行（蓝牙连接成功时调用）
  Future<void> startRide() async {
    if (_isTracking) return;

    // 检查 GPS 权限
    final hasPermission = await _gpsService.checkAndRequestPermission();
    if (!hasPermission) {
      _logCallback?.call('RidingRecord', LogType.warning, 'GPS 权限未授权');
      return;
    }

    _isTracking = true;
    _currentRecord = RidingRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      trackPoints: [],
    );

    _maxSpeed = 0;
    _totalDistance = 0;
    _duration = Duration.zero;
    _maxLeanLeft = 0;
    _maxLeanRight = 0;
    _lastTrackTime = null;

    // 开始时长计时
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _duration = DateTime.now().difference(_currentRecord!.startTime);
      notifyListeners();
    });

    // 开始 GPS 跟踪
    _gpsService.onTrackPoint = _onTrackPoint;
    _gpsService.startTracking();

    _logCallback?.call('RidingRecord', LogType.info, '开始骑行记录');
    notifyListeners();
  }

  void _onTrackPoint(TrackPoint point) {
    if (_currentRecord == null) return;

    final points = List<TrackPoint>.from(_currentRecord!.trackPoints)..add(point);

    // 计算里程
    if (_lastTrackTime != null && points.length > 1) {
      const distance = Distance();
      final prev = points[points.length - 2];
      final curr = point;
      final meters = distance.as(
        LengthUnit.Meter,
        LatLng(prev.latitude, prev.longitude),
        LatLng(curr.latitude, curr.longitude),
      );
      _totalDistance += meters / 1000; // 转为公里
    }
    _lastTrackTime = point.timestamp;

    // 更新实时速度
    _currentSpeed = point.speed;
    if (point.speed > _maxSpeed) {
      _maxSpeed = point.speed;
    }

    _currentRecord = _currentRecord!.copyWith(
      trackPoints: points,
      distance: _totalDistance,
      maxSpeed: _maxSpeed,
      avgSpeed: _totalDistance > 0 ? (_totalDistance / _duration.inMinutes) * 60 : 0,
    );

    notifyListeners();
  }

  /// 更新倾角（由外部调用）
  void updateLeanAngle(int angle, String direction) {
    if (!_isTracking || _currentRecord == null) return;

    if (direction.toUpperCase() == 'LEFT' && angle > _maxLeanLeft) {
      _maxLeanLeft = angle;
    } else if (direction.toUpperCase() == 'RIGHT' && angle > _maxLeanRight) {
      _maxLeanRight = angle;
    }

    _currentRecord = _currentRecord!.copyWith(
      maxLeanLeft: _maxLeanLeft,
      maxLeanRight: _maxLeanRight,
    );
    notifyListeners();
  }

  /// 添加事件（由外部调用）
  void addEvent(RidingEventType type) {
    if (!_isTracking || _currentRecord == null) return;

    final counts = Map<RidingEventType, int>.from(_currentRecord!.eventCounts);
    counts[type] = (counts[type] ?? 0) + 1;

    _currentRecord = _currentRecord!.copyWith(eventCounts: counts);
    notifyListeners();
  }

  /// 结束骑行（蓝牙断开时调用）
  Future<void> endRide() async {
    if (!_isTracking || _currentRecord == null) return;

    _isTracking = false;
    _gpsService.stopTracking();
    _durationTimer?.cancel();
    _durationTimer = null;

    final completedRecord = _currentRecord!.copyWith(
      endTime: DateTime.now(),
      duration: _duration,
      distance: _totalDistance,
      maxSpeed: _maxSpeed,
      avgSpeed: _totalDistance > 0 ? (_totalDistance / _duration.inMinutes) * 60 : 0,
      maxLeanLeft: _maxLeanLeft,
      maxLeanRight: _maxLeanRight,
      isCompleted: true,
    );

    await _saveRecord(completedRecord);

    _logCallback?.call('RidingRecord', LogType.info,
        '骑行结束: ${_duration.inMinutes}分钟, ${_totalDistance.toStringAsFixed(2)}km');

    _currentRecord = null;
    _currentSpeed = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _gpsService.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/riding_record_provider.dart
git commit -m "feat: add RidingRecordProvider for state management"
```

---

## Task 6: 创建历史记录卡片组件

**Files:**
- Create: `lib/widgets/riding_record_card.dart`

- [ ] **Step 1: 创建 RidingRecordCard**

```dart
import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../models/riding_event.dart';
import '../theme/app_theme.dart';
import 'mini_track_preview.dart';

/// 骑行记录卡片
class RidingRecordCard extends StatelessWidget {
  final RidingRecord record;
  final VoidCallback? onTap;

  const RidingRecordCard({
    super.key,
    required this.record,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.surfaceBorderDefault,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：日期时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateTime(record.startTime),
                  style: AppTheme.titleMedium,
                ),
                if (record.trackPoints.isNotEmpty)
                  SizedBox(
                    width: 80,
                    height: 40,
                    child: MiniTrackPreview(
                      trackPoints: record.trackPoints,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 中部：时长和里程
            Row(
              children: [
                _StatItem(
                  label: '时长',
                  value: _formatDuration(record.duration),
                ),
                const SizedBox(width: 24),
                _StatItem(
                  label: '里程',
                  value: '${record.distance.toStringAsFixed(2)} km',
                ),
                const SizedBox(width: 24),
                _StatItem(
                  label: '最高速度',
                  value: '${record.maxSpeed.toStringAsFixed(1)} km/h',
                ),
                const SizedBox(width: 24),
                _StatItem(
                  label: '平均速度',
                  value: '${record.avgSpeed.toStringAsFixed(1)} km/h',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 底部：倾角和事件统计
            Row(
              children: [
                _LeanBadge(label: '左倾', value: '${record.maxLeanLeft}°'),
                const SizedBox(width: 8),
                _LeanBadge(label: '右倾', value: '${record.maxLeanRight}°'),
                const SizedBox(width: 16),
                if (record.eventCounts.isNotEmpty) ...[
                  _EventBadge(
                    type: RidingEventType.extremeLean,
                    count: record.eventCounts[RidingEventType.extremeLean] ?? 0,
                  ),
                  const SizedBox(width: 8),
                  _EventBadge(
                    type: RidingEventType.performanceBurst,
                    count: record.eventCounts[RidingEventType.performanceBurst] ?? 0,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h${m}m';
    return '${m}m';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.valueMedium),
      ],
    );
  }
}

class _LeanBadge extends StatelessWidget {
  final String label;
  final String value;

  const _LeanBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary20,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label $value',
        style: AppTheme.labelSmall.copyWith(color: AppTheme.primary),
      ),
    );
  }
}

class _EventBadge extends StatelessWidget {
  final RidingEventType type;
  final int count;

  const _EventBadge({required this.type, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange20,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${_getEventName(type)} $count',
        style: AppTheme.labelSmall.copyWith(color: AppTheme.accentOrange),
      ),
    );
  }

  String _getEventName(RidingEventType type) {
    switch (type) {
      case RidingEventType.extremeLean:
        return '压弯';
      case RidingEventType.performanceBurst:
        return '爆发';
      default:
        return '事件';
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/riding_record_card.dart
git commit -m "feat: add RidingRecordCard widget"
```

---

## Task 7: 创建缩略轨迹图组件

**Files:**
- Create: `lib/widgets/mini_track_preview.dart`

- [ ] **Step 1: 创建 MiniTrackPreview**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';

/// 缩略轨迹图组件
class MiniTrackPreview extends StatelessWidget {
  final List<TrackPoint> trackPoints;

  const MiniTrackPreview({super.key, required this.trackPoints});

  @override
  Widget build(BuildContext context) {
    if (trackPoints.isEmpty) {
      return Container(
        decoration: AppTheme.surfaceBorder(
          borderColor: AppTheme.primary,
          opacity: 0.1,
        ),
        child: const Center(
          child: Text('--', style: AppTheme.labelSmall),
        ),
      );
    }

    final points = trackPoints.map((p) => p.toLatLng()).toList();
    final bounds = LatLngBounds.fromPoints(points);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(8),
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.obd_dashboard',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/mini_track_preview.dart
git commit -m "feat: add MiniTrackPreview widget"
```

---

## Task 8: 创建历史记录列表页

**Files:**
- Create: `lib/screens/riding_history_screen.dart`

- [ ] **Step 1: 创建 RidingHistoryScreen**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/riding_record_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/riding_record_card.dart';

/// 骑行历史记录页面
class RidingHistoryScreen extends StatelessWidget {
  const RidingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('骑行记录', style: AppTheme.titleMedium),
        centerTitle: true,
      ),
      body: Consumer<RidingRecordProvider>(
        builder: (context, provider, _) {
          final records = provider.records;

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 64,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无骑行记录',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '连接设备后将自动开始记录',
                    style: AppTheme.labelSmall,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return RidingRecordCard(
                record: record,
                onTap: () => _showRecordDetail(context, record),
              );
            },
          );
        },
      ),
    );
  }

  void _showRecordDetail(BuildContext context, record) {
    // TODO: 后续可扩展详情页
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/riding_history_screen.dart
git commit -m "feat: add RidingHistoryScreen"
```

---

## Task 9: 创建实时骑行记录页

**Files:**
- Create: `lib/screens/riding_record_screen.dart`

- [ ] **Step 1: 创建 RidingRecordScreen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/riding_record_provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 实时骑行记录页面
class RidingRecordScreen extends StatefulWidget {
  const RidingRecordScreen({super.key});

  @override
  State<RidingRecordScreen> createState() => _RidingRecordScreenState();
}

class _RidingRecordScreenState extends State<RidingRecordScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<RidingRecordProvider>(
        builder: (context, provider, _) {
          final record = provider.currentRecord;
          final trackPoints = record?.trackPoints ?? [];

          return Stack(
            children: [
              // 地图
              if (trackPoints.isNotEmpty)
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(
                        trackPoints.map((p) => p.toLatLng()).toList(),
                      ),
                      padding: const EdgeInsets.all(32),
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.obd_dashboard',
                    ),
                    // 轨迹线
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: trackPoints.map((p) => p.toLatLng()).toList(),
                          strokeWidth: 4,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                    // 起点标记
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: trackPoints.first.toLatLng(),
                          child: const Icon(
                            Icons.circle,
                            color: AppTheme.accentGreen,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                const Center(
                  child: Text(
                    '等待 GPS 信号...',
                    style: AppTheme.labelMedium,
                  ),
                ),

              // 底部统计面板
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StatsPanel(provider: provider),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

class _StatsPanel extends StatelessWidget {
  final RidingRecordProvider provider;

  const _StatsPanel({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: AppTheme.primary20, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 当前速度
          _SpeedDisplay(speed: provider.currentSpeed),
          const SizedBox(width: 32),

          // 时长 | 里程
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_formatDuration(provider.duration), style: AppTheme.valueMedium),
              const SizedBox(height: 4),
              Text('${provider.totalDistance.toStringAsFixed(2)} km',
                  style: AppTheme.labelSmall),
            ],
          ),
          const SizedBox(width: 32),

          // 最高/平均速度
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_upward, size: 14, color: AppTheme.accentOrange),
                  const SizedBox(width: 4),
                  Text(
                    '${provider.maxSpeed.toStringAsFixed(1)} km/h',
                    style: AppTheme.valueMedium.copyWith(color: AppTheme.accentOrange),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.trending_flat, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${(provider.totalDistance / provider.duration.inMinutes * 60).toStringAsFixed(1)} km/h',
                    style: AppTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 32),

          // 倾角
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.rotate_left, size: 14, color: AppTheme.accentCyan),
                  const SizedBox(width: 4),
                  Text('${provider.maxLeanLeft}°', style: AppTheme.valueMedium),
                  const SizedBox(width: 16),
                  const Icon(Icons.rotate_right, size: 14, color: AppTheme.accentCyan),
                  const SizedBox(width: 4),
                  Text('${provider.maxLeanRight}°', style: AppTheme.valueMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text('倾角', style: AppTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _SpeedDisplay extends StatelessWidget {
  final double speed;

  const _SpeedDisplay({required this.speed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              speed.toStringAsFixed(0),
              style: AppTheme.headingLarge.copyWith(
                color: AppTheme.primary,
                fontSize: 72,
              ),
            ),
            const SizedBox(width: 4),
            const Text('km/h', style: AppTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 4),
        const Text('当前速度', style: AppTheme.labelSmall),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/riding_record_screen.dart
git commit -m "feat: add RidingRecordScreen with live map and stats"
```

---

## Task 10: 注册 Provider 并修改 MainContainer

**Files:**
- Modify: `lib/main.dart:29-93`
- Modify: `lib/screens/main_container.dart:1-258`

- [ ] **Step 1: 在 main.dart 添加 RidingRecordProvider**

```dart
import 'providers/riding_record_provider.dart';

// 在 MultiProvider 中添加
ChangeNotifierProxyProvider2<OBDDataProvider, LogProvider, RidingRecordProvider>(
  create: (context) => RidingRecordProvider(
    logProvider: context.read<LogProvider>(),
  ),
  update: (context, obdDataProvider, logProvider, previous) =>
      previous ??
      RidingRecordProvider(
        logProvider: logProvider,
      ),
),
```

**在 initialize() 后添加初始化调用：**
```dart
// 初始化骑行记录 Provider
await context.read<RidingRecordProvider>().initialize();
```

- [ ] **Step 2: 在 main_container.dart 添加页面和自动流程**

添加 import:
```dart
import 'riding_history_screen.dart';
import 'riding_record_screen.dart';
```

添加页面到列表:
```dart
final List<Widget> _pages = const [
  DashboardScreen(),
  LogsScreen(),
  BluetoothScanScreen(),
  RidingHistoryScreen(),  // 新增
];
```

在 `_buildPageView` 中添加骑行中跳转逻辑:
```dart
// 在 builder 的 selector 中添加
if (provider.isTracking) {
  // 骑行中时显示 RidingRecordScreen
  return const RidingRecordScreen();
}
```

在蓝牙连接状态变化时调用 startRide/endRide:
```dart
// 连接成功
if (isConnected && !_hasStartedRide) {
  _hasStartedRide = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<RidingStatsProvider>().startRide();
    context.read<RidingRecordProvider>().startRide(); // 新增
  });
}
// 断开连接
if (!isConnected && _hasStartedRide) {
  _hasStartedRide = false;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<RidingStatsProvider>().endRide();
    context.read<RidingRecordProvider>().endRide(); // 新增
  });
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart lib/screens/main_container.dart
git commit -m "feat: integrate RidingRecordProvider and auto-tracking"
```

---

## Task 11: 添加 TopNavigationBar Tab

**Files:**
- Modify: `lib/widgets/top_navigation_bar.dart`

- [ ] **Step 1: 添加骑行记录 Tab**

在导航项列表中添加:
```dart
const NavItem(
  icon: Icons.route,
  label: '骑行',
),
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/top_navigation_bar.dart
git commit -m "feat: add riding record tab to navigation"
```

---

## Task 12: 修复编译错误并验证

- [ ] **Step 1: 运行 flutter analyze**

Run: `flutter analyze`
Expected: 无 error（warning 可忽略）

- [ ] **Step 2: 修复所有 error**

（根据实际情况修复编译错误）

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "fix: resolve compilation errors in riding record feature"
```

---

## 执行方式

**推荐使用 Subagent-Driven：**
- 每个 Task 由独立 subagent 执行
- 任务间有依赖关系，需按顺序执行
- Task 1 → Task 2 → Task 3 → ... → Task 12

**快速检查清单：**
- [ ] 所有 12 个 Task 完成
- [ ] `flutter analyze` 无 error
- [ ] 提交记录完整
