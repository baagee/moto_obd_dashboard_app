import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obd_dashboard/utils/gear_util.dart';
import '../models/obd_data.dart';
import '../models/riding_event.dart' as stats;
import '../models/riding_record.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import 'log_provider.dart';
import 'loggable.dart';
import 'obd_data_provider.dart';
import 'riding_record_provider.dart';
import 'settings_provider.dart';

/// 骑行统计 Provider
/// 负责数据采样、事件检测、统计汇总
class RidingStatsProvider extends ChangeNotifier {
  final OBDDataProvider _obdDataProvider;
  final AudioService? _audioService;
  RidingRecordProvider? _ridingRecordProvider;
  SettingsProvider? _settingsProvider;

  // 日志回调
  late final void Function(String source, LogType type, String message)
      _logCallback;

  // 最新添加的事件（用于外部监听）
  stats.RidingEvent? _latestEvent;

  /// 获取最新事件
  stats.RidingEvent? get latestEvent => _latestEvent;

  /// 清除最新事件（消费后调用）
  void clearLatestEvent() {
    _latestEvent = null;
  }

  // 采样间隔 2Hz
  static const Duration sampleInterval = Duration(milliseconds: 500);

  // 时间窗口 5 秒
  static const Duration windowDuration = Duration(seconds: 5);

  // 事件冷却时间现由 SettingsProvider 动态提供，不再使用静态常量

  // 数据采样器
  final DataSampler _sampler = DataSampler();

  // 降频采样定时器
  Timer? _sampleTimer;

  // 事件冷却时间记录
  final Map<stats.RidingEventType, DateTime> _lastEventTime = {};

  // 事件历史列表
  final List<stats.RidingEvent> _eventHistory = [];

  // 骑行状态
  bool _isRiding = false;
  DateTime? _rideStartTime;

  // GPS 轨迹追踪
  StreamSubscription<Position>? _positionSubscription;
  PositionData? _trackStartPoint; // 只保留起点坐标（终点用 _lastPosition）
  double _totalGpsDistance = 0; // 米
  PositionData? _lastPosition;

  // 轨迹点分批落库
  static const Duration _waypointInterval = Duration(seconds: 1);
  static const int _waypointBatchSize = 15;
  Timer? _waypointTimer;
  final List<Map<String, dynamic>> _pendingWaypoints = [];
  int? _currentRecordId;
  PositionData? _lastWaypointPosition; // 用于距离过滤

  // 骑行统计快照定时器（每 30s 持久化一次，防止闪退丢数据）
  static const Duration _snapshotInterval = Duration(seconds: 30);
  Timer? _snapshotTimer;

  // 全程统计数据（用于保存记录）
  double _maxSpeed = 0;
  double _maxLeftLean = 0;
  double _maxRightLean = 0;
  double _totalSpeedSum = 0;
  int _totalSampleCount = 0;

  List<stats.RidingEvent> get eventHistory => _eventHistory;
  bool get isRiding => _isRiding;

  RidingStatsProvider({
    required OBDDataProvider obdDataProvider,
    required LogProvider logProvider,
    AudioService? audioService,
    RidingRecordProvider? ridingRecordProvider,
    SettingsProvider? settingsProvider,
  })  : _obdDataProvider = obdDataProvider,
        _audioService = audioService,
        _ridingRecordProvider = ridingRecordProvider,
        _settingsProvider = settingsProvider {
    _logCallback = createLogger(logProvider);
  }

  /// 注入 SettingsProvider（用于读取 amapKey 等配置）
  void updateSettings(SettingsProvider settings) {
    _settingsProvider = settings;
  }

  /// 开始骑行
  void startRide() async {
    _isRiding = true;
    _rideStartTime = DateTime.now();
    _sampler.clear();
    _lastEventTime.clear();
    _eventHistory.clear();
    _trackStartPoint = null;
    _totalGpsDistance = 0;
    _lastPosition = null;
    _pendingWaypoints.clear();
    _lastWaypointPosition = null;
    _currentRecordId = null;

    // 重置全程统计数据
    _maxSpeed = 0;
    _maxLeftLean = 0;
    _maxRightLean = 0;
    _totalSpeedSum = 0;
    _totalSampleCount = 0;

    String? placeName;
    double? startLat;
    double? startLng;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 并行获取起点位置 + 逆地理编码，完成后再插入带完整起点信息的记录
    try {
      _logCallback('Stats', LogType.info, '正在获取起点位置...');
      // 最多等 10s（LocationService 内部已有 timeLimit）
      final position =
          await LocationService.getCurrentPosition(logCallback: _logCallback);

      if (position != null) {
        startLat = position.latitude;
        startLng = position.longitude;
        _logCallback('Stats', LogType.success, '起点位置已获取: $startLat, $startLng');

        // 记录起点坐标（只保留第一次）
        _trackStartPoint ??= PositionData.fromGeolocator(position);
        _lastPosition = _trackStartPoint;

        // 逆地理编码获取地名
        placeName = await GeocodingService.getPlaceName(
          startLat,
          startLng,
          amapKey: _settingsProvider?.amapKey ?? '',
          logCallback: _logCallback,
        );
        _logCallback('Stats', LogType.info, '起点地名: ${placeName ?? '未知'}');
      } else {
        _logCallback('Stats', LogType.warning, '起点位置获取失败，将以空坐标入库');
      }
    } catch (e) {
      _logCallback('Stats', LogType.warning, '起点位置获取失败: $e，开始点将无法落库');
      // _currentRecordId 保持 null，_waypointTimer 启动但写库时跳过
    }

    try {
      _currentRecordId = await DatabaseService.insertRidingRecord({
        'start_time': now,
        'end_time': null,
        'start_latitude': startLat,
        'start_longitude': startLng,
        'start_place_name': placeName,
        'distance': 0,
        'avg_speed': 0,
        'duration': 0,
        'max_speed': 0,
        'max_left_lean': 0,
        'max_right_lean': 0,
        'created_at': now,
      });
      _logCallback(
          'Stats', LogType.info, '骑行记录已插入，record_id=$_currentRecordId');
      // 插入成功后刷新记录列表，让进行中的记录立即出现在记录页
      _ridingRecordProvider?.refreshRecords();
    } catch (e) {
      _logCallback('Stats', LogType.warning, '骑行记录初始化插入失败: $e');
      // _currentRecordId 保持 null，_waypointTimer 启动但写库时跳过
    }

    // 启动降频采样定时器
    _startSampling();

    // 启动 GPS 追踪
    _startGpsTracking();

    // 启动轨迹点采集定时器
    _startWaypointTimer();

    // 启动统计快照定时器（每 30s 持久化一次防闪退丢数据）
    _startSnapshotTimer();

    _logCallback('Stats', LogType.info, '开始骑行统计');
    notifyListeners();
  }

  /// 结束骑行
  void endRide() async {
    _isRiding = false;
    _stopSampling();
    _stopGpsTracking();
    _stopWaypointTimer();
    _stopSnapshotTimer();
    GSX8SCalculator.reset();

    final duration = _rideStartTime != null
        ? DateTime.now().difference(_rideStartTime!).inSeconds
        : 0;
    _logCallback('Stats', LogType.info,
        '骑行结束，总时长: ${duration ~/ 60}分钟，总距离: ${(_totalGpsDistance / 1000).toStringAsFixed(2)} km');
    notifyListeners();

    // 将剩余未落库的轨迹点（尾巴批次）落库
    await _flushPendingWaypoints();

    // 保存骑行记录（await 确保 end_time 写入完成后再返回，消除竞态）
    await _saveRidingRecord(duration);
  }

  /// 启动轨迹点采集定时器
  void _startWaypointTimer() {
    _waypointTimer?.cancel();
    _waypointTimer =
        Timer.periodic(_waypointInterval, (_) => _collectWaypoint());
  }

  /// 停止轨迹点采集定时器
  void _stopWaypointTimer() {
    _waypointTimer?.cancel();
    _waypointTimer = null;
  }

  /// 启动统计快照定时器
  void _startSnapshotTimer() {
    _snapshotTimer?.cancel();
    _snapshotTimer =
        Timer.periodic(_snapshotInterval, (_) => _snapshotRidingStats());
  }

  /// 停止统计快照定时器
  void _stopSnapshotTimer() {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
  }

  /// 将当前骑行统计快照写入 DB（防闪退丢数据）
  Future<void> _snapshotRidingStats() async {
    if (!_isRiding || _currentRecordId == null) return;
    final avgSpeed =
        _totalSampleCount > 0 ? _totalSpeedSum / _totalSampleCount : 0.0;
    final distance = _totalGpsDistance > 0 ? _totalGpsDistance / 1000 : 0.0;
    final duration = _rideStartTime != null
        ? DateTime.now().difference(_rideStartTime!).inSeconds
        : 0;
    try {
      _logCallback('Stats', LogType.info,
          '[DB] snapshot updateRidingRecord id=$_currentRecordId: distance=${distance.toStringAsFixed(3)}km duration=${duration}s avgSpeed=${avgSpeed.toStringAsFixed(1)} maxSpeed=${_maxSpeed.toStringAsFixed(1)}');
      await DatabaseService.updateRidingRecord(_currentRecordId!, {
        'avg_speed': avgSpeed,
        'max_speed': _maxSpeed,
        'distance': distance,
        'duration': duration,
        'max_left_lean': _maxLeftLean,
        'max_right_lean': _maxRightLean,
      });
    } catch (e) {
      _logCallback('Stats', LogType.warning, '统计快照写入失败: $e');
    }
  }

  /// 采集当前轨迹点（每 2 秒调用一次）
  void _collectWaypoint() {
    if (!_isRiding || _lastPosition == null || _currentRecordId == null) return;

    final pos = _lastPosition!;

    // 距离过滤：与上一个轨迹点距离 < 3m 视为静止，不记录
    if (_lastWaypointPosition != null) {
      final dist = _calculateDistance(_lastWaypointPosition!, pos);
      if (dist < 3.0) return;
    }

    _lastWaypointPosition = pos;
    final speed = _obdDataProvider.data.speed.toDouble();

    _pendingWaypoints.add({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'speed': speed,
      'timestamp': pos.timestamp.millisecondsSinceEpoch,
    });

    // 达到批次阈值时落库
    if (_pendingWaypoints.length >= _waypointBatchSize) {
      _flushPendingWaypoints();
    }
  }

  /// 将 _pendingWaypoints 批量写入数据库
  Future<void> _flushPendingWaypoints() async {
    if (_pendingWaypoints.isEmpty || _currentRecordId == null) return;
    final batch = List<Map<String, dynamic>>.from(_pendingWaypoints);
    _pendingWaypoints.clear();
    try {
      await DatabaseService.insertWaypoints(_currentRecordId!, batch);
      _logCallback('Stats', LogType.info, '已落库 ${batch.length} 个轨迹点');
    } catch (e) {
      _logCallback('Stats', LogType.error, '轨迹点落库失败: $e');
    }
  }

  /// 启动降频采样
  void _startSampling() {
    _sampleTimer?.cancel();
    _sampleTimer =
        Timer.periodic(sampleInterval, (_) => _performSamplingAndDetection());
  }

  /// 停止采样
  void _stopSampling() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
  }

  /// 启动 GPS 追踪
  void _startGpsTracking() {
    _stopGpsTracking();

    // 请求后台定位权限（确保 APP 切后台时 GPS 仍然工作）
    LocationService.requestBackgroundPermission(logCallback: _logCallback)
        .then((granted) {
      if (!granted) {
        _logCallback('GPS', LogType.warning, '后台定位权限未授权，切换到后台时 GPS 追踪可能暂停');
      } else {
        _logCallback('GPS', LogType.success, '后台定位权限已授权');
      }
    });

    try {
      _positionSubscription = LocationService.getPositionStream(
        distanceFilter: 0, // 0米触发（每次位置变化都回调，最高精度）
      ).listen((position) {
        _onPositionUpdate(PositionData.fromGeolocator(position));
      });
    } catch (e) {
      _logCallback('Stats', LogType.warning, 'GPS 追踪启动失败: $e');
    }
  }

  /// 停止 GPS 追踪
  void _stopGpsTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// GPS 过滤常量
  static const double _maxReasonableSpeedMs = 69.44; // 250 km/h，摩托车极速上限
  // codeflicker-fix: LOGIC-Issue-003/odko2evgylfq2rjqqr53
  // GPS 过滤参数改为从 SettingsProvider 动态读取
  double get _minMoveDistance => _settingsProvider?.minMoveDistance ?? 3.0;
  int get _maxGpsGapSeconds => _settingsProvider?.maxGpsGapSeconds ?? 30;

  /// GPS 位置更新处理
  void _onPositionUpdate(PositionData position) {
    if (!_isRiding) return;

    // 时间过滤：距离上次更新至少 0.5 秒（避免静止时频繁回调）
    if (_lastPosition != null) {
      final timeDiff = position.timestamp.difference(_lastPosition!.timestamp);
      if (timeDiff.inMilliseconds < 500) return;
    }

    // 记录起点（只保留第一次）
    _trackStartPoint ??= position;

    if (_lastPosition != null) {
      final distance = _calculateDistance(_lastPosition!, position);
      final timeDiffMs = position.timestamp
          .difference(_lastPosition!.timestamp)
          .inMilliseconds;
      final timeDiffSec = timeDiffMs / 1000.0;

      // 计算瞬时速度（m/s），使用毫秒精度避免 < 1s 时除零
      final speed = timeDiffMs > 0 ? (distance / timeDiffSec) : 0.0;

      if (distance < _minMoveDistance) {
        // 静止噪声：忽略，不计入里程
      } else if (timeDiffSec > _maxGpsGapSeconds) {
        // GPS 失联后大跳跃：跳过此段，避免里程虚增
        _logCallback('GPS', LogType.warning,
            'GPS 信号中断 ${timeDiffSec.toStringAsFixed(0)}s 后重连，跳过此段 ${distance.toStringAsFixed(0)}m');
      } else if (speed > _maxReasonableSpeedMs) {
        // 速度超出摩托车极限：GPS 漂移，过滤
        _logCallback('GPS', LogType.warning,
            '过滤 GPS 漂移: ${distance.toStringAsFixed(1)}m, ${(speed * 3.6).toStringAsFixed(1)}km/h');
      } else {
        // 正常采样：累加里程
        _totalGpsDistance += distance;
      }
    }
    _lastPosition = position;
  }

  /// 使用 Haversine 公式计算两个 GPS 点之间的距离（米）
  double _calculateDistance(PositionData p1, PositionData p2) {
    const R = 6371000.0; // 地球半径（米）
    final dLat = _toRadians(p2.latitude - p1.latitude);
    final dLon = _toRadians(p2.longitude - p1.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(p1.latitude)) *
            cos(_toRadians(p2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  /// 执行采样和检测
  void _performSamplingAndDetection() {
    if (!_isRiding) return;

    final data = _obdDataProvider.data;

    // 数据验证：过滤无效数据
    if (!_isValidData(data)) return;

    // 添加采样点
    _sampler.addSample('speed', data.speed.toDouble());
    _sampler.addSample('rpm', data.rpm.toDouble());
    _sampler.addSample('temp', data.coolantTemp.toDouble());
    _sampler.addSample('voltage', data.voltage);
    _sampler.addSample('load', data.load.toDouble());
    _sampler.addSample('intakeTemp', data.intakeTemp.toDouble());
    _sampler.addSample('throttle', data.throttle.toDouble());
    const int maxSpeed = 3;
    // 倾角只在车速 >= maxSpeed km/h 时统计，过滤低速/静止时的传感器噪声
    if (data.speed >= maxSpeed) {
      _sampler.addSample('lean', data.leanAngle.toDouble());
    }

    // 实时更新全程统计数据
    final speed = data.speed.toDouble();
    if (speed > _maxSpeed) _maxSpeed = speed;

    // 最大倾角只在车速 >= maxSpeed km/h 时统计，过滤低速/静止时的传感器噪声
    if (data.speed >= maxSpeed) {
      final leanAngle = data.leanAngle.toDouble();
      final leanDirection = data.leanDirection.toLowerCase();
      if (leanDirection == 'left' && leanAngle > _maxLeftLean) {
        _maxLeftLean = leanAngle;
      } else if (leanDirection == 'right' && leanAngle > _maxRightLean) {
        _maxRightLean = leanAngle;
      }
    }

    // 累积速度和计数（用于计算全程平均速度）
    _totalSpeedSum += speed;
    _totalSampleCount++;

    // 获取窗口数据
    final avgSpeed = _sampler.getAverage('speed');
    final avgRpm = _sampler.getAverage('rpm');
    final avgTemp = _sampler.getAverage('temp');
    final avgVoltage = _sampler.getAverage('voltage');
    final avgLoad = _sampler.getAverage('load');
    final avgLean = _sampler.getAverage('lean');
    final avgIntakeTemp = _sampler.getAverage('intakeTemp');
    final avgThrottle = _sampler.getAverage('throttle');

    // 检测事件
    _checkPerformanceBurst();
    _checkExtremeLean(avgSpeed, avgLean);
    _checkEngineOverheating(avgTemp);
    _checkVoltageAnomaly(avgVoltage);
    _checkHighEngineLoad(avgLoad);
    _checkLongRiding();
    _checkEfficientCruising(avgSpeed, avgLoad, avgThrottle);
    _checkEngineWarmup(avgTemp, avgRpm);
    _checkColdEnvironmentRisk(avgIntakeTemp, avgSpeed);
  }

  /// 数据有效性检查
  bool _isValidData(OBDData data) {
    // 过滤无效数据（负值、异常大值）
    if (data.speed <= 0 || data.speed > 300) return false;
    if (data.rpm <= 0 || data.rpm > 15000) return false;
    if (data.coolantTemp <= -40 || data.coolantTemp > 150) return false;
    if (data.voltage <= 0 || data.voltage > 20) return false;
    if (data.load <= 0 || data.load > 100) return false;
    if (data.leanAngle <= -90 || data.leanAngle > 90) return false;
    if (data.intakeTemp <= -40 || data.intakeTemp > 60) return false;
    if (data.throttle <= 0 || data.throttle > 100) return false;
    return true;
  }

  /// 检查是否可以触发事件
  bool _canTriggerEvent(stats.RidingEventType type,
      {Duration? customCooldown}) {
    final lastTime = _lastEventTime[type];
    final globalCooldown =
        Duration(seconds: _settingsProvider?.globalCooldownSeconds ?? 30);
    final cooldown = customCooldown ?? globalCooldown;
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime) > cooldown;
  }

  /// 记录事件触发时间
  void _recordEventTime(stats.RidingEventType type) {
    _lastEventTime[type] = DateTime.now();
  }

  /// 性能爆发检测：RPM > performanceBurstRpm 且速度上升趋势
  void _checkPerformanceBurst() {
    final avgRpm = _sampler.getAverage('rpm');
    final threshold =
        (_settingsProvider?.performanceBurstRpm ?? 6300).toDouble();
    if (avgRpm == null || avgRpm <= threshold) return;
    if (_settingsProvider?.performanceBurstEnabled == false) return;
    if (!_canTriggerEvent(stats.RidingEventType.performanceBurst)) return;

    // 检查速度趋势
    final speedTrend = _sampler.getTrend('speed');
    if (speedTrend != null && speedTrend > 0) {
      final event = stats.RidingEvent.performanceBurst(
        rpm: avgRpm,
        speedChangeRate: speedTrend,
      );
      _addEvent(event);
    }
  }

  /// 极限压弯检测
  void _checkExtremeLean(double? avgSpeed, double? avgLean) {
    if (avgSpeed == null || avgLean == null) return;
    if (_settingsProvider?.extremeLeanEnabled == false) return;
    final minSpeed = (_settingsProvider?.extremeLeanSpeedMin ?? 60).toDouble();
    final minAngle = (_settingsProvider?.extremeLeanAngleMin ?? 20).toDouble();
    final cooldownSec = _settingsProvider?.extremeLeanCooldown ?? 60;
    if (avgSpeed < minSpeed) return;
    if (avgLean < minAngle) return;
    if (!_canTriggerEvent(stats.RidingEventType.extremeLean,
        customCooldown: Duration(seconds: cooldownSec))) {
      return;
    } // codeflicker-fix: OPT-Issue-8/omvh7ni7j93qpiynr7sw

    final direction = _obdDataProvider.data.leanDirection;
    final event = stats.RidingEvent.extremeLean(
      vehicleSpeed: avgSpeed,
      leanAngle: avgLean,
      direction: direction.toLowerCase(),
    );
    _addEvent(event);
  }

  /// 引擎过热检测
  void _checkEngineOverheating(double? avgTemp) {
    if (avgTemp == null) return;
    if (_settingsProvider?.engineOverheatEnabled == false) return;
    final tempThreshold =
        (_settingsProvider?.engineOverheatTemp ?? 105).toDouble();
    if (avgTemp <= tempThreshold) return;
    if (!_canTriggerEvent(stats.RidingEventType.engineOverheating)) return;

    final event = stats.RidingEvent.engineOverheating(coolantTemp: avgTemp);
    _addEvent(event);
  }

  /// 电压异常检测
  void _checkVoltageAnomaly(double? avgVoltage) {
    if (avgVoltage == null) return;
    if (_settingsProvider?.voltageAnomalyEnabled == false) return;
    final low = _settingsProvider?.voltageAnomalyLow ?? 11.5;
    final high = _settingsProvider?.voltageAnomalyHigh ?? 15.3;
    if (avgVoltage >= low && avgVoltage <= high) return;
    if (!_canTriggerEvent(stats.RidingEventType.voltageAnomaly)) return;

    // codeflicker-fix: OPT-Issue-1/omvh7ni7j93qpiynr7sw
    final anomalyType = avgVoltage < low ? 'low' : 'high';
    final event = stats.RidingEvent.voltageAnomaly(
      voltage: avgVoltage,
      anomalyType: anomalyType,
    );
    _addEvent(event);
  }

  /// 高负荷检测
  void _checkHighEngineLoad(double? avgLoad) {
    if (avgLoad == null) return;
    if (_settingsProvider?.highLoadEnabled == false) return;
    final threshold = (_settingsProvider?.highLoadThreshold ?? 70).toDouble();
    if (avgLoad <= threshold) return;
    if (!_canTriggerEvent(stats.RidingEventType.highEngineLoad)) return;

    final event = stats.RidingEvent.highEngineLoad(engineLoad: avgLoad);
    _addEvent(event);
  }

  /// 长途骑行检测
  void _checkLongRiding() {
    if (_rideStartTime == null) return;
    if (_settingsProvider?.longRidingEnabled == false) return;
    final durationHours = _settingsProvider?.longRidingDurationHours ?? 1.0;
    final cooldownSec = _settingsProvider?.longRidingCooldownSeconds ?? 1200;
    final duration = DateTime.now().difference(_rideStartTime!);
    if (duration.inMinutes < (durationHours * 60).toInt()) return;
    if (!_canTriggerEvent(stats.RidingEventType.longRiding,
        customCooldown: Duration(seconds: cooldownSec))) {
      return;
    } // codeflicker-fix: OPT-Issue-8/omvh7ni7j93qpiynr7sw

    final event = stats.RidingEvent.longRiding(duration: duration);
    _addEvent(event);
  }

  /// 高效巡航检测
  void _checkEfficientCruising(
      double? avgSpeed, double? avgLoad, double? avgThrottle) {
    if (avgSpeed == null || avgLoad == null || avgThrottle == null) return;
    if (_settingsProvider?.efficientCruisingEnabled == false) return;
    final speedMin =
        (_settingsProvider?.efficientCruisingSpeedMin ?? 70).toDouble();
    final speedMax =
        (_settingsProvider?.efficientCruisingSpeedMax ?? 100).toDouble();
    final loadMax =
        (_settingsProvider?.efficientCruisingLoadMax ?? 30).toDouble();
    final cooldownSec = _settingsProvider?.efficientCruisingCooldown ?? 300;
    if (avgSpeed < speedMin || avgSpeed > speedMax) return;
    if (avgLoad >= loadMax) return;
    if (!_canTriggerEvent(stats.RidingEventType.efficientCruising,
        customCooldown: Duration(seconds: cooldownSec))) {
      return;
    } // codeflicker-fix: OPT-Issue-8/omvh7ni7j93qpiynr7sw

    // 计算油门稳定性（标准差）
    final throttleStdDev = _sampler.getStdDev('throttle');
    if (throttleStdDev == null || throttleStdDev > 10) return;

    final event = stats.RidingEvent.efficientCruising(
      avgSpeed: avgSpeed,
      avgLoad: avgLoad,
      throttleStability: avgThrottle,
    );
    _addEvent(event);
  }

  /// 引擎预热检测
  void _checkEngineWarmup(double? avgTemp, double? avgRpm) {
    if (avgTemp == null || avgRpm == null) return;
    if (_settingsProvider?.engineWarmupEnabled == false) return;
    final tempThreshold =
        (_settingsProvider?.engineWarmupTemp ?? 70).toDouble();
    final rpmThreshold =
        (_settingsProvider?.engineWarmupRpmMax ?? 6000).toDouble();
    if (avgTemp >= tempThreshold) return;
    if (avgRpm <= rpmThreshold) return;
    if (!_canTriggerEvent(stats.RidingEventType.engineWarmup)) return;

    final vehicleSpeed = _obdDataProvider.data.speed.toDouble();
    final event = stats.RidingEvent.engineWarmup(
      coolantTemp: avgTemp,
      vehicleSpeed: vehicleSpeed,
    );
    _addEvent(event);
  }

  /// 低温环境风险检测
  void _checkColdEnvironmentRisk(double? avgIntakeTemp, double? avgSpeed) {
    if (avgIntakeTemp == null || avgSpeed == null) return;
    if (_settingsProvider?.coldRiskEnabled == false) return;
    final tempThreshold = (_settingsProvider?.coldRiskTemp ?? 5).toDouble();
    final speedThreshold =
        (_settingsProvider?.coldRiskSpeedMin ?? 40).toDouble();
    final cooldownSec = _settingsProvider?.coldRiskCooldown ?? 120;
    if (avgIntakeTemp >= tempThreshold) return;
    if (avgSpeed <= speedThreshold) return;
    if (!_canTriggerEvent(stats.RidingEventType.coldEnvironmentRisk,
        customCooldown: Duration(seconds: cooldownSec))) {
      return;
    } // codeflicker-fix: OPT-Issue-8/omvh7ni7j93qpiynr7sw

    final vehicleSpeed = _obdDataProvider.data.speed.toDouble();
    final event = stats.RidingEvent.coldEnvironmentRisk(
      intakeAirTemp: avgIntakeTemp,
      vehicleSpeed: vehicleSpeed,
    );
    _addEvent(event);
  }

  /// 添加事件
  void _addEvent(stats.RidingEvent event) {
    _recordEventTime(event.type);

    // 添加到历史列表
    _eventHistory.insert(0, event);
    // codeflicker-fix: LOGIC-Issue-004/odko2evgylfq2rjqqr53
    final maxHistory = _settingsProvider?.maxEventHistory ?? 100;
    if (_eventHistory.length > maxHistory) {
      _eventHistory.removeLast();
    }

    // 设置最新事件（供外部监听显示弹窗）
    _latestEvent = event;
    _logCallback('Stats', LogType.warning, '事件触发: ${event.title}');
    notifyListeners();
  }

  Future<void> _saveRidingRecord(int duration) async {
    if (_ridingRecordProvider == null || _rideStartTime == null) return;

    // 无效骑行过滤：以下任一条件满足则丢弃
    //  1. 最大速度为 0（整个会话没有行驶，比如设备连接后立即断开）
    //  2. 距离 < 20米 且 时长 < 30秒（短时误触/测试）
    final distanceMeters = _totalGpsDistance;
    if (_maxSpeed == 0) {
      _logCallback('Stats', LogType.warning,
          '骑行记录已丢弃（最大速度为 0，判定为未实际行驶，时长=${duration}s）');
      // 若有占位记录，删除之（避免留下空壳记录）
      if (_currentRecordId != null) {
        try {
          _logCallback('Stats', LogType.warning,
              '[DB] deleteRidingRecord id=$_currentRecordId 原因: maxSpeed=0，判定未实际行驶');
          await DatabaseService.deleteRidingRecord(_currentRecordId!);
        } catch (e) {
          _logCallback('Stats', LogType.error,
              '[DB] deleteRidingRecord id=$_currentRecordId 失败: $e');
        }
      }
      return;
    }
    // 行驶距离不足阈值 → 丢弃（覆盖：原地怠速任意时长 / 短时误触）
    // codeflicker-fix: LOGIC-Issue-005/odko2evgylfq2rjqqr53
    final minDistance = _settingsProvider?.minRidingDistance ?? 20;
    if (distanceMeters < minDistance) {
      _logCallback('Stats', LogType.warning,
          '骑行记录已丢弃（距离=${distanceMeters.toStringAsFixed(1)}m < ${minDistance}m，判定为未实际行驶）');
      if (_currentRecordId != null) {
        try {
          _logCallback('Stats', LogType.warning,
              '[DB] deleteRidingRecord id=$_currentRecordId 原因: 距离${distanceMeters.toStringAsFixed(1)}m < ${minDistance}m');
          await DatabaseService.deleteRidingRecord(_currentRecordId!);
        } catch (e) {
          _logCallback('Stats', LogType.error,
              '[DB] deleteRidingRecord id=$_currentRecordId 失败: $e');
        }
      }
      return;
    }

    // 使用实时累积的全程统计数据
    final avgSpeed =
        _totalSampleCount > 0 ? _totalSpeedSum / _totalSampleCount : 0.0;
    final maxSpeed = _maxSpeed;
    final maxLeftLean = _maxLeftLean;
    final maxRightLean = _maxRightLean;

    // 起点 = 骑行开始时第一个 GPS 点，终点 = 骑行结束时最后更新的位置
    final startPoint = _trackStartPoint;
    final endPoint = _lastPosition;

    // 转换事件
    final events = _eventHistory.map((e) => e.toRidingRecordEvent()).toList();

    // 优先使用 GPS 计算的距离，否则用 OBD 车速积分
    double distance;
    if (_totalGpsDistance > 0) {
      distance = _totalGpsDistance / 1000;
    } else {
      distance = avgSpeed * (duration / 3600);
    }

    // 如果有占位记录，使用 updateRidingRecord 补全统计字段
    if (_currentRecordId != null) {
      try {
        await _ridingRecordProvider!.saveRidingRecordWithId(
          recordId: _currentRecordId!,
          startTime: _rideStartTime!.millisecondsSinceEpoch,
          endTime: DateTime.now().millisecondsSinceEpoch,
          duration: duration,
          distance: distance,
          avgSpeed: avgSpeed,
          maxSpeed: maxSpeed,
          maxLeftLean: maxLeftLean,
          maxRightLean: maxRightLean,
          events: events,
          startLatitude: startPoint?.latitude,
          startLongitude: startPoint?.longitude,
          endLatitude: endPoint?.latitude,
          endLongitude: endPoint?.longitude,
        );
        // 骑行记录更新完成，刷新记录列表
        _ridingRecordProvider!.refreshRecords();
      } catch (e) {
        _logCallback('Stats', LogType.error, '更新骑行记录失败: $e');
      }
    } else {
      // 降级：占位记录插入失败时，走原来的 insertRidingRecord 路径
      _logCallback('Stats', LogType.warning,
          '[DB] _saveRidingRecord 降级路径: _currentRecordId=null，走 insertRidingRecord');
      await _ridingRecordProvider!.saveRidingRecord(
        startTime: _rideStartTime!.millisecondsSinceEpoch,
        endTime: DateTime.now().millisecondsSinceEpoch,
        duration: duration,
        distance: distance,
        avgSpeed: avgSpeed,
        maxSpeed: maxSpeed,
        maxLeftLean: maxLeftLean,
        maxRightLean: maxRightLean,
        events: events,
        startLatitude: startPoint?.latitude,
        startLongitude: startPoint?.longitude,
        endLatitude: endPoint?.latitude,
        endLongitude: endPoint?.longitude,
      );
      // 降级路径：骑行记录保存完成，刷新记录列表
      unawaited(_ridingRecordProvider!.refreshRecords());
    }
  }

  @override
  void dispose() {
    // 注意：dispose 时只做资源清理，不调用 endRide()
    // 调用 endRide() 会触发 _saveRidingRecord，产生幽灵记录
    // endRide() 应由业务层（蓝牙断开）主动调用
    _stopSampling();
    _stopGpsTracking();
    _stopWaypointTimer();
    _stopSnapshotTimer();
    super.dispose();
  }
}

/// 数据采样器 - 负责时间窗口管理和数据采样
class DataSampler {
  // 采样间隔 2Hz
  static const Duration sampleInterval = Duration(milliseconds: 500);

  // 时间窗口 5 秒
  static const Duration windowDuration = Duration(seconds: 5);

  // 采样数据（按字段名存储）
  final Map<String, List<_SamplePoint>> _samples = {};

  /// 添加采样点
  void addSample(String field, double value) {
    final now = DateTime.now();
    _samples.putIfAbsent(field, () => []);
    _samples[field]!.add(_SamplePoint(value: value, timestamp: now));

    // 按时间窗口过滤，移除超过5秒的旧数据
    _trimSamples(field, now);
  }

  /// 按时间窗口过滤数据
  void _trimSamples(String field, DateTime now) {
    final cutoff = now.subtract(windowDuration);
    _samples[field]?.removeWhere((point) => point.timestamp.isBefore(cutoff));
  }

  /// 清空所有采样数据
  void clear() {
    _samples.clear();
  }

  /// 获取时间窗口内的均值
  double? getAverage(String field) {
    final points = _samples[field];
    if (points == null || points.isEmpty) return null;

    final sum = points.map((p) => p.value).reduce((a, b) => a + b);
    return sum / points.length;
  }

  /// 获取趋势（最新值 - 最旧值）
  double? getTrend(String field) {
    final points = _samples[field];
    if (points == null || points.length < 2) return null;

    // 按时间排序
    final sorted = List<_SamplePoint>.from(points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final oldest = sorted.first.value;
    final newest = sorted.last.value;
    return newest - oldest;
  }

  /// 获取标准差
  double? getStdDev(String field) {
    final points = _samples[field];
    if (points == null || points.length < 2) return null;

    final values = points.map((p) => p.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }

  /// 获取时间窗口内的数据点数量
  int getSampleCount(String field) {
    return _samples[field]?.length ?? 0;
  }
}

/// 采样点结构
class _SamplePoint {
  final double value;
  final DateTime timestamp;

  _SamplePoint({required this.value, required this.timestamp});
}
