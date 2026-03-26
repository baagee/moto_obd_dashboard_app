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
