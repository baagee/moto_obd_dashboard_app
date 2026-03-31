import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/obd_data.dart';
import '../models/riding_record.dart';
import '../services/database_service.dart';
import '../services/geocoding_service.dart';
import 'log_provider.dart';
import 'loggable.dart';
import 'settings_provider.dart';

/// 骑行记录 Provider
class RidingRecordProvider extends ChangeNotifier {
  late final void Function(String source, LogType type, String message)
      _logCallback;
  SettingsProvider? _settingsProvider;

  List<RidingRecord> _records = [];
  AggregationStats _todayStats = AggregationStats();
  AggregationStats _weekStats = AggregationStats();
  AggregationStats _monthStats = AggregationStats();
  bool _isLoading = false;
  bool _isInitialized = false;

  RidingRecordProvider({
    required LogProvider logProvider,
    SettingsProvider? settingsProvider,
  }) : _settingsProvider = settingsProvider {
    _logCallback = createLogger(logProvider);
  }

  /// 注入 SettingsProvider（用于读取 amapKey 等配置）
  void updateSettings(SettingsProvider settings) {
    _settingsProvider = settings;
  }

  List<RidingRecord> get records => _records;

  /// 今天的记录
  List<RidingRecord> get todayRecords {
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    return _records.where((r) => r.startTime >= todayStart).toList();
  }

  /// 近 7 天的记录
  List<RidingRecord> get weekRecords {
    final cutoff =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    return _records.where((r) => r.startTime >= cutoff).toList();
  }

  /// 近 30 天的记录
  List<RidingRecord> get monthRecords {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    return _records.where((r) => r.startTime >= cutoff).toList();
  }

  AggregationStats get todayStats => _todayStats;
  AggregationStats get weekStats => _weekStats;
  AggregationStats get monthStats => _monthStats;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// 初始化 - 加载所有记录和统计数据
  Future<void> initialize({bool force = false}) async {
    if (_isInitialized && !force) return;
    _isLoading = true;
    notifyListeners();

    // 启动时清理 30 天前的过期记录 & 清理空壳残留记录
    await DatabaseService.deleteExpiredRecords();
    await DatabaseService.deleteOrphanRecords();

    await Future.wait([
      _loadRecords(),
      _loadTodayStats(),
      _loadWeekStats(),
      _loadMonthStats(),
    ]);

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  /// 加载所有骑行记录
  Future<void> _loadRecords() async {
    final maps = await DatabaseService.getAllRidingRecords();
    _records = maps.map((m) => RidingRecord.fromMap(m)).toList();
  }

  /// 加载今日统计（从 daily_stats 读取，与周/月统计方式一致）
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

  /// 清空所有骑行记录
  Future<void> clearAllRecords() async {
    await DatabaseService.deleteAllRidingRecords();
    _records = [];
    _todayStats = AggregationStats();
    _weekStats = AggregationStats();
    _monthStats = AggregationStats();
    notifyListeners();
  }

  /// 获取指定骑行记录的轨迹点列表
  Future<List<RidingWaypoint>> getWaypointsForRecord(int recordId) async {
    final maps = await DatabaseService.getWaypointsByRecordId(recordId);
    return maps.map((m) => RidingWaypoint.fromMap(m)).toList();
  }

  /// 保存骑行记录（有预建占位 record 时调用，更新已有记录）
  Future<void> saveRidingRecordWithId({
    required int recordId,
    required int startTime,
    required int endTime,
    required int duration,
    required double distance,
    required double avgSpeed,
    required double maxSpeed,
    required double maxLeftLean,
    required double maxRightLean,
    required List<RidingRecordEvent> events,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
  }) async {
    // 第一步：立即写入核心字段（end_time、距离、时长等），让记录马上可见
    // 起点地名已在 startRide() 时写入，无需再次编码
    // 终点地名异步补充，不阻塞记录写入
    await DatabaseService.updateRidingRecord(recordId, {
      'end_time': endTime,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'distance': distance,
      'avg_speed': avgSpeed,
      'duration': duration,
      'max_speed': maxSpeed,
      'max_left_lean': maxLeftLean,
      'max_right_lean': maxRightLean,
    });

    // 保存事件
    if (events.isNotEmpty) {
      await DatabaseService.insertRidingEvents(
        recordId,
        events.map((e) => e.toMap()).toList(),
      );
    }

    // 更新每日统计
    await _updateDailyStats(endTime, distance, duration, avgSpeed, maxSpeed,
        maxLeftLean, maxRightLean);

    // 重新加载（记录已完整，UI 可以正常展示）
    await initialize(force: true);

    // 第二步：异步补充终点地名（不阻塞 UI 刷新）
    if (endLatitude != null && endLongitude != null) {
      GeocodingService.getPlaceName(
        endLatitude,
        endLongitude,
        logCallback: _logCallback,
      ).then((endPlaceName) async {
        if (endPlaceName != null) {
          await DatabaseService.updateRidingRecord(recordId, {
            'end_place_name': endPlaceName,
          });
          // 静默刷新，更新地名显示
          await initialize(force: true);
        }
      }).catchError((_) {});
    }
  }

  /// 保存骑行记录（骑行结束时调用）
  ///
  /// [startLatitude]/[startLongitude] - 骑行起点坐标（由调用方传入，在 startRide 时获取）
  /// [endLatitude]/[endLongitude] - 骑行终点坐标（由调用方传入，在 endRide 时获取）
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
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
  }) async {
    // 逆地理编码：将坐标转换为地名（使用高德 API，国内可用）
    String? startPlaceName;
    if (startLatitude != null && startLongitude != null) {
      startPlaceName = await GeocodingService.getPlaceName(
        startLatitude,
        startLongitude,
        amapKey: _settingsProvider?.amapKey ?? '',
        logCallback: _logCallback,
      );
    }

    String? endPlaceName;
    if (endLatitude != null && endLongitude != null) {
      endPlaceName = await GeocodingService.getPlaceName(
        endLatitude,
        endLongitude,
        amapKey: _settingsProvider?.amapKey ?? '',
        logCallback: _logCallback,
      );
    }

    // 创建记录
    final record = RidingRecord(
      startTime: startTime,
      endTime: endTime,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      startPlaceName: startPlaceName,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
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
    await _updateDailyStats(endTime, distance, duration, avgSpeed, maxSpeed,
        maxLeftLean, maxRightLean);

    // 重新加载
    await initialize(force: true);
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
        stats.avgSpeed,
        stats.rideCount,
        avgSpeed,
        1,
      ),
      maxSpeed: maxSpeed > stats.maxSpeed ? maxSpeed : stats.maxSpeed,
      maxLeftLean:
          maxLeftLean > stats.maxLeftLean ? maxLeftLean : stats.maxLeftLean,
      maxRightLean:
          maxRightLean > stats.maxRightLean ? maxRightLean : stats.maxRightLean,
      rideCount: stats.rideCount + 1,
    );

    await DatabaseService.upsertDailyStats(dateStr, updatedStats.toMap());
  }

  /// 计算加权平均
  double _calculateWeightedAvg(
    double avg1,
    int count1,
    double avg2,
    int count2,
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
