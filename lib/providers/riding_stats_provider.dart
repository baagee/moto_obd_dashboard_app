import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obd_dashboard/utils/gear_util.dart';
import '../models/obd_data.dart';
import '../models/riding_event.dart' as stats;
import '../models/riding_record.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart';
import 'log_provider.dart';
import 'loggable.dart';
import 'obd_data_provider.dart';
import 'riding_record_provider.dart';

/// 骑行统计 Provider
/// 负责数据采样、事件检测、统计汇总
class RidingStatsProvider extends ChangeNotifier {
  final OBDDataProvider _obdDataProvider;
  final AudioService? _audioService;
  RidingRecordProvider? _ridingRecordProvider;

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

  // 事件冷却时间（防止重复触发）
  static const Duration eventCooldown = Duration(seconds: 30);
  static const Duration extremeLeanCooldown = Duration(seconds: 60);
  static const Duration longRidingCooldown = Duration(seconds: 1200);
  static const Duration efficientCruisingCooldown = Duration(seconds: 300);
  static const Duration coldEnvironmentCooldown = Duration(seconds: 120);

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
  final List<PositionData> _gpsTrack = [];
  double _totalGpsDistance = 0; // 米
  PositionData? _lastPosition;

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
  })  : _obdDataProvider = obdDataProvider,
        _audioService = audioService,
        _ridingRecordProvider = ridingRecordProvider {
    _logCallback = createLogger(logProvider);
  }

  /// 开始骑行
  void startRide() {
    _isRiding = true;
    _rideStartTime = DateTime.now();
    _sampler.clear();
    _lastEventTime.clear();
    _eventHistory.clear();
    _gpsTrack.clear();
    _totalGpsDistance = 0;
    _lastPosition = null;

    // 重置全程统计数据
    _maxSpeed = 0;
    _maxLeftLean = 0;
    _maxRightLean = 0;
    _totalSpeedSum = 0;
    _totalSampleCount = 0;

    // 启动降频采样定时器
    _startSampling();

    // 启动 GPS 追踪
    _startGpsTracking();

    _logCallback?.call('Stats', LogType.info, '开始骑行统计');
    notifyListeners();
  }

  /// 结束骑行
  void endRide() {
    _isRiding = false;
    _stopSampling();
    _stopGpsTracking();
    GSX8SCalculator.reset();

    final duration = _rideStartTime != null
        ? DateTime.now().difference(_rideStartTime!).inSeconds
        : 0;
    _logCallback?.call('Stats', LogType.info,
        '骑行结束，总时长: ${duration ~/ 60}分钟，总距离: ${(_totalGpsDistance / 1000).toStringAsFixed(2)} km');
    notifyListeners();

    // 保存骑行记录
    _saveRidingRecord(duration);
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
    LocationService.requestBackgroundPermission().then((granted) {
      if (!granted) {
        _logCallback?.call(
            'GPS', LogType.warning, '后台定位权限未授权，切换到后台时 GPS 追踪可能暂停');
      } else {
        _logCallback?.call('GPS', LogType.success, '后台定位权限已授权');
      }
    });

    try {
      _positionSubscription = LocationService.getPositionStream(
        distanceFilter: 0, // 0米触发（每次位置变化都回调，最高精度）
      ).listen((position) {
        _onPositionUpdate(PositionData.fromGeolocator(position));
      });
    } catch (e) {
      _logCallback?.call('Stats', LogType.warning, 'GPS 追踪启动失败: $e');
    }
  }

  /// 停止 GPS 追踪
  void _stopGpsTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// GPS 过滤常量
  static const double _maxReasonableSpeedMs = 69.44; // 250 km/h，摩托车极速上限
  static const int _maxGpsGapSeconds = 30; // GPS 失联超过此时长视为异常跳跃
  static const double _minMoveDistance = 3.0; // 小于 3m 视为静止噪声，不累加

  /// GPS 位置更新处理
  void _onPositionUpdate(PositionData position) {
    if (!_isRiding) return;

    // 时间过滤：距离上次更新至少 0.5 秒（避免静止时频繁回调）
    if (_lastPosition != null) {
      final timeDiff = position.timestamp.difference(_lastPosition!.timestamp);
      if (timeDiff.inMilliseconds < 500) return;
    }

    _gpsTrack.add(position);

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
        _logCallback?.call('GPS', LogType.warning,
            'GPS 信号中断 ${timeDiffSec.toStringAsFixed(0)}s 后重连，跳过此段 ${distance.toStringAsFixed(0)}m');
      } else if (speed > _maxReasonableSpeedMs) {
        // 速度超出摩托车极限：GPS 漂移，过滤
        _logCallback?.call('GPS', LogType.warning,
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
    final cooldown = customCooldown ?? eventCooldown;
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime) > cooldown;
  }

  /// 记录事件触发时间
  void _recordEventTime(stats.RidingEventType type) {
    _lastEventTime[type] = DateTime.now();
  }

  /// 性能爆发检测：RPM > 6300 且速度上升趋势
  void _checkPerformanceBurst() {
    final avgRpm = _sampler.getAverage('rpm');
    if (avgRpm == null || avgRpm <= 6300) return;
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

  /// 极限压弯检测：速度 >= 60km/h 且倾角 >= 20°
  void _checkExtremeLean(double? avgSpeed, double? avgLean) {
    if (avgSpeed == null || avgLean == null) return;
    if (avgSpeed < 60) return;
    if (avgLean < 20) return;
    if (!_canTriggerEvent(stats.RidingEventType.extremeLean,
        customCooldown: extremeLeanCooldown)) return;

    final direction = _obdDataProvider.data.leanDirection;
    final event = stats.RidingEvent.extremeLean(
      vehicleSpeed: avgSpeed,
      leanAngle: avgLean,
      direction: direction.toLowerCase(),
    );
    _addEvent(event);
  }

  /// 引擎过热检测：水温 > 110°C
  void _checkEngineOverheating(double? avgTemp) {
    if (avgTemp == null || avgTemp <= 110) return;
    if (!_canTriggerEvent(stats.RidingEventType.engineOverheating)) return;

    final event = stats.RidingEvent.engineOverheating(coolantTemp: avgTemp);
    _addEvent(event);
  }

  /// 电压异常检测：电压 < 11.5V 或 > 15.3V
  void _checkVoltageAnomaly(double? avgVoltage) {
    if (avgVoltage == null) return;
    if (avgVoltage >= 11.5 && avgVoltage <= 15.3) return;
    if (!_canTriggerEvent(stats.RidingEventType.voltageAnomaly)) return;

    final anomalyType = avgVoltage < 11.5 ? 'low' : 'high';
    final event = stats.RidingEvent.voltageAnomaly(
      voltage: avgVoltage,
      anomalyType: anomalyType,
    );
    _addEvent(event);
  }

  /// 高负荷检测：负荷 > 70%
  void _checkHighEngineLoad(double? avgLoad) {
    if (avgLoad == null || avgLoad <= 70) return;
    if (!_canTriggerEvent(stats.RidingEventType.highEngineLoad)) return;

    final event = stats.RidingEvent.highEngineLoad(engineLoad: avgLoad);
    _addEvent(event);
  }

  /// 长途骑行检测：骑行时间 > 1小时
  void _checkLongRiding() {
    if (_rideStartTime == null) return;

    final duration = DateTime.now().difference(_rideStartTime!);
    if (duration.inHours < 1) return;
    if (!_canTriggerEvent(stats.RidingEventType.longRiding,
        customCooldown: longRidingCooldown)) return;

    final event = stats.RidingEvent.longRiding(duration: duration);
    _addEvent(event);
  }

  /// 高效巡航检测：速度 70-100km/h 且负荷 < 30%
  void _checkEfficientCruising(
      double? avgSpeed, double? avgLoad, double? avgThrottle) {
    if (avgSpeed == null || avgLoad == null || avgThrottle == null) return;
    if (avgSpeed < 70 || avgSpeed > 100) return;
    if (avgLoad >= 30) return;
    if (!_canTriggerEvent(stats.RidingEventType.efficientCruising,
        customCooldown: efficientCruisingCooldown)) return;

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

  /// 引擎预热检测：水温 < 70°C 且 RPM > 6000
  void _checkEngineWarmup(double? avgTemp, double? avgRpm) {
    if (avgTemp == null || avgRpm == null) return;
    if (avgTemp >= 70) return;
    if (avgRpm <= 6000) return;
    if (!_canTriggerEvent(stats.RidingEventType.engineWarmup)) return;

    final vehicleSpeed = _obdDataProvider.data.speed.toDouble();
    final event = stats.RidingEvent.engineWarmup(
      coolantTemp: avgTemp,
      vehicleSpeed: vehicleSpeed,
    );
    _addEvent(event);
  }

  /// 低温环境风险检测：进气温度 < 5°C 且速度 > 40km/h
  void _checkColdEnvironmentRisk(double? avgIntakeTemp, double? avgSpeed) {
    if (avgIntakeTemp == null || avgSpeed == null) return;
    if (avgIntakeTemp >= 5) return;
    if (avgSpeed <= 40) return;
    if (!_canTriggerEvent(stats.RidingEventType.coldEnvironmentRisk,
        customCooldown: coldEnvironmentCooldown)) return;

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
    // 最多保留 100 条
    if (_eventHistory.length > 100) {
      _eventHistory.removeLast();
    }

    // 设置最新事件（供外部监听显示弹窗）
    _latestEvent = event;
    _logCallback?.call('Stats', LogType.warning, '事件触发: ${event.title}');
    notifyListeners();
  }

  void _saveRidingRecord(int duration) async {
    if (_ridingRecordProvider == null || _rideStartTime == null) return;

    // 无效骑行过滤：以下任一条件满足则丢弃
    //  1. 最大速度为 0（整个会话没有行驶，比如设备连接后立即断开）
    //  2. 距离 < 20米 且 时长 < 30秒（短时误触/测试）
    final distanceMeters = _totalGpsDistance;
    if (_maxSpeed == 0) {
      _logCallback?.call('Stats', LogType.warning,
          '骑行记录已丢弃（最大速度为 0，判定为未实际行驶，时长=${duration}s）');
      return;
    }
    if (duration < 30 && distanceMeters < 20) {
      _logCallback?.call('Stats', LogType.warning,
          '骑行记录已丢弃（时长=${duration}s, 距离=${distanceMeters.toStringAsFixed(1)}m，未达到最小阈值）');
      return;
    }

    // 使用实时累积的全程统计数据
    final avgSpeed =
        _totalSampleCount > 0 ? _totalSpeedSum / _totalSampleCount : 0.0;
    final maxSpeed = _maxSpeed;
    final maxLeftLean = _maxLeftLean;
    final maxRightLean = _maxRightLean;

    // 从 GPS 轨迹中取起点（第一个点）和终点（最后一个点）
    // GPS 轨迹在 startRide 时清空，第一个点就是真实起点
    final startPoint = _gpsTrack.isNotEmpty ? _gpsTrack.first : null;
    final endPoint = _gpsTrack.isNotEmpty ? _gpsTrack.last : null;

    // 转换事件
    final events = _eventHistory.map((e) => e.toRidingRecordEvent()).toList();

    // 优先使用 GPS 计算的距离，否则用 OBD 车速积分
    double distance;
    if (_totalGpsDistance > 0) {
      distance = _totalGpsDistance / 1000; // 转换为公里
    } else {
      // 回退：平均速度(km/h) * 时长(h)
      distance = avgSpeed * (duration / 3600);
    }

    _ridingRecordProvider!.saveRidingRecord(
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
  }

  @override
  void dispose() {
    // 注意：dispose 时只做资源清理，不调用 endRide()
    // 调用 endRide() 会触发 _saveRidingRecord，产生幽灵记录
    // endRide() 应由业务层（蓝牙断开）主动调用
    _stopSampling();
    _stopGpsTracking();
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
