import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/obd_data.dart';
import '../models/riding_record.dart';
import '../models/riding_event.dart';
import '../services/gps_service.dart';
import 'log_provider.dart';
import 'loggable.dart';

/// 骑行记录 Provider - 管理骑行记录的状态和存储
class RidingRecordProvider extends ChangeNotifier {
  static const String _boxName = 'riding_records';
  static const String _currentRecordKey = 'current_record';

  bool _isInitialized = false;
  bool _isTracking = false;
  Box<RidingRecord>? _box;

  // 当前骑行记录
  RidingRecord? _currentRecord;
  // 所有历史记录
  List<RidingRecord> _records = [];

  // 实时状态
  double _currentSpeed = 0;
  double _maxSpeed = 0;
  double _totalDistance = 0;
  Duration _duration = Duration.zero;
  int _maxLeanLeft = 0;
  int _maxLeanRight = 0;

  // GPS 服务
  GPSService? _gpsService;

  // 日志回调
  late final void Function(String source, LogType type, String message) _logCallback;

  // Getter
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  RidingRecord? get currentRecord => _currentRecord;
  List<RidingRecord> get records => List.unmodifiable(_records);
  bool get isRiding => _currentRecord != null && !_currentRecord!.isCompleted;
  double get currentSpeed => _currentSpeed;
  double get maxSpeed => _maxSpeed;
  double get totalDistance => _totalDistance;
  Duration get duration => _duration;
  int get maxLeanLeft => _maxLeanLeft;
  int get maxLeanRight => _maxLeanRight;

  /// 构造函数 - 通过依赖注入接收 LogProvider
  RidingRecordProvider({required LogProvider logProvider}) {
    _logCallback = createLogger(logProvider);
  }

  /// 初始化 Provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    _logCallback.call('RidingRecord', LogType.info, '骑行记录服务初始化中...');

    // 初始化 Hive
    await Hive.initFlutter();

    // 注册适配器
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(RidingRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TrackPointAdapter());
    }

    // 打开 Box
    _box = await Hive.openBox<RidingRecord>(_boxName);

    // 加载历史记录
    await _loadRecords();

    // 检查是否有未完成的骑行
    _currentRecord = _box?.get(_currentRecordKey);
    if (_currentRecord != null && !_currentRecord!.isCompleted) {
      _logCallback.call('RidingRecord', LogType.info, '发现未完成的骑行记录，继续记录');
    } else {
      _currentRecord = null;
    }

    _isInitialized = true;
    _logCallback.call('RidingRecord', LogType.success, '骑行记录服务初始化完成');
    notifyListeners();
  }

  /// 加载历史记录
  Future<void> _loadRecords() async {
    if (_box == null) return;

    _records = _box!.values
        .where((record) => record.isCompleted)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    _logCallback.call('RidingRecord', LogType.info, '加载了 ${_records.length} 条历史记录');
  }

  /// 开始新骑行
  Future<void> startRide() async {
    if (!(_isInitialized && _box != null)) {
      _logCallback.call('RidingRecord', LogType.error, 'RidingRecordProvider 未初始化');
      return;
    }

    if (_currentRecord != null && !_currentRecord!.isCompleted) {
      _logCallback.call('RidingRecord', LogType.warning, '当前已有进行中的骑行');
      return;
    }

    // 创建新记录
    _currentRecord = RidingRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      isCompleted: false,
    );

    // 保存当前记录
    await _box!.put(_currentRecordKey, _currentRecord!);

    // 初始化 GPS 服务
    _gpsService = GPSService(onTrackPoint: _onTrackPoint);
    final hasPermission = await _gpsService!.checkAndRequestPermission();
    if (hasPermission) {
      _gpsService!.startTracking();
      _logCallback.call('RidingRecord', LogType.success, '开始新骑行');
    } else {
      _logCallback.call('RidingRecord', LogType.warning, 'GPS 权限未授予，无法记录轨迹');
    }

    notifyListeners();
  }

  /// 结束当前骑行
  Future<void> endRide() async {
    if (_currentRecord == null || _currentRecord!.isCompleted) {
      _logCallback.call('RidingRecord', LogType.warning, '没有进行中的骑行');
      return;
    }

    // 停止 GPS 跟踪
    _gpsService?.stopTracking();
    _gpsService?.dispose();
    _gpsService = null;

    // 更新记录
    final endTime = DateTime.now();
    final duration = endTime.difference(_currentRecord!.startTime);

    // 计算平均速度
    final avgSpeed = duration.inMinutes > 0
        ? (_currentRecord!.distance / duration.inMinutes) * 60
        : 0.0;

    _currentRecord = _currentRecord!.copyWith(
      endTime: endTime,
      duration: duration,
      avgSpeed: avgSpeed,
      isCompleted: true,
    );

    // 保存到历史记录
    await _box!.put(_currentRecord!.id, _currentRecord!);

    // 清除当前记录
    await _box!.delete(_currentRecordKey);

    // 更新历史记录列表
    await _loadRecords();

    _logCallback.call(
      'RidingRecord',
      LogType.success,
      '骑行结束 - 里程 ${_currentRecord!.distance.toStringAsFixed(1)}km，'
      '时长 ${_formatDuration(duration)}，最高速度 ${_currentRecord!.maxSpeed.toStringAsFixed(1)}km/h',
    );

    _currentRecord = null;
    notifyListeners();
  }

  /// 更新倾角
  void updateLeanAngle(int leanAngle, String direction) {
    if (_currentRecord == null || _currentRecord!.isCompleted) return;

    if (direction == 'left') {
      if (leanAngle > _currentRecord!.maxLeanLeft) {
        _currentRecord = _currentRecord!.copyWith(maxLeanLeft: leanAngle);
        _saveCurrentRecord();
      }
    } else if (direction == 'right') {
      if (leanAngle > _currentRecord!.maxLeanRight) {
        _currentRecord = _currentRecord!.copyWith(maxLeanRight: leanAngle);
        _saveCurrentRecord();
      }
    }
  }

  /// 添加事件
  void addEvent(RidingEventType type) {
    if (_currentRecord == null || _currentRecord!.isCompleted) return;

    final eventCounts = Map<RidingEventType, int>.from(_currentRecord!.eventCounts);
    eventCounts[type] = (eventCounts[type] ?? 0) + 1;

    _currentRecord = _currentRecord!.copyWith(eventCounts: eventCounts);
    _saveCurrentRecord();

    _logCallback.call('RidingRecord', LogType.info, '记录事件: ${getEventTypeDisplayName(type)}');
  }

  /// GPS 轨迹点回调
  void _onTrackPoint(TrackPoint point) {
    if (_currentRecord == null || _currentRecord!.isCompleted) return;

    // 计算移动距离（简化计算，使用直线距离）
    double addedDistance = 0;
    if (_currentRecord!.trackPoints.isNotEmpty) {
      final lastPoint = _currentRecord!.trackPoints.last;
      addedDistance = _calculateDistance(
        lastPoint.latitude,
        lastPoint.longitude,
        point.latitude,
        point.longitude,
      );
    }

    // 更新最高速度
    double maxSpeed = _currentRecord!.maxSpeed;
    if (point.speed > maxSpeed) {
      maxSpeed = point.speed;
    }

    // 添加轨迹点
    final trackPoints = List<TrackPoint>.from(_currentRecord!.trackPoints)..add(point);

    _currentRecord = _currentRecord!.copyWith(
      trackPoints: trackPoints,
      distance: _currentRecord!.distance + addedDistance,
      maxSpeed: maxSpeed,
    );

    _saveCurrentRecord();
  }

  /// 保存当前记录到 Hive
  Future<void> _saveCurrentRecord() async {
    if (_currentRecord == null || _box == null) return;
    await _box!.put(_currentRecordKey, _currentRecord!);
    notifyListeners();
  }

  /// 删除骑行记录
  Future<void> deleteRecord(String recordId) async {
    if (_box == null) return;

    await _box!.delete(recordId);
    await _loadRecords();
    notifyListeners();

    _logCallback.call('RidingRecord', LogType.info, '删除骑行记录: $recordId');
  }

  /// 清空所有历史记录
  Future<void> clearAllRecords() async {
    if (_box == null) return;

    await _box!.clear();
    _records = [];
    notifyListeners();

    _logCallback.call('RidingRecord', LogType.info, '已清空所有历史记录');
  }

  /// 获取指定记录
  RidingRecord? getRecord(String recordId) {
    return _box?.get(recordId);
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// 计算两点间距离（简化版，使用勾股定理）
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) * _sin(dLon / 2) * _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * 3.141592653589793 / 180;
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorSin(x + 3.141592653589793 / 2);
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }
  double _atan(double x) {
    // 使用泰勒级数计算 atan
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 3.141592653589793 / 2 - _atan(1 / x);
    }
    double result = 0;
    double term = x;
    for (int n = 0; n < 20; n++) {
      result += term / (2 * n + 1) * (n % 2 == 0 ? 1 : -1);
      term *= x * x;
    }
    return result;
  }
  double _taylorSin(double x) {
    // 归一化到 -pi 到 pi
    while (x > 3.141592653589793) {
      x -= 2 * 3.141592653589793;
    }
    while (x < -3.141592653589793) {
      x += 2 * 3.141592653589793;
    }
    double result = 0;
    double term = x;
    for (int n = 0; n < 10; n++) {
      result += term;
      term *= -x * x / ((2 * n + 2) * (2 * n + 3));
    }
    return result;
  }

  @override
  void dispose() {
    _gpsService?.dispose();
    _box?.close();
    super.dispose();
  }
}

/// Hive 适配器 - RidingRecord
class RidingRecordAdapter extends TypeAdapter<RidingRecord> {
  @override
  final int typeId = 0;

  @override
  RidingRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return RidingRecord(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
      distance: fields[3] as double,
      duration: Duration(microseconds: fields[4] as int),
      maxSpeed: fields[5] as double,
      avgSpeed: fields[6] as double,
      maxLeanLeft: fields[7] as int,
      maxLeanRight: fields[8] as int,
      eventCounts: (fields[9] as Map).cast<RidingEventType, int>(),
      trackPoints: (fields[10] as List).cast<TrackPoint>(),
      isCompleted: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RidingRecord obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.duration.inMicroseconds)
      ..writeByte(5)
      ..write(obj.maxSpeed)
      ..writeByte(6)
      ..write(obj.avgSpeed)
      ..writeByte(7)
      ..write(obj.maxLeanLeft)
      ..writeByte(8)
      ..write(obj.maxLeanRight)
      ..writeByte(9)
      ..write(obj.eventCounts)
      ..writeByte(10)
      ..write(obj.trackPoints)
      ..writeByte(11)
      ..write(obj.isCompleted);
  }
}

/// Hive 适配器 - TrackPoint
class TrackPointAdapter extends TypeAdapter<TrackPoint> {
  @override
  final int typeId = 1;

  @override
  TrackPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return TrackPoint(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      speed: fields[2] as double,
      timestamp: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TrackPoint obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.speed)
      ..writeByte(3)
      ..write(obj.timestamp);
  }
}
