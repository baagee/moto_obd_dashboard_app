import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/obd_data.dart';
import '../models/riding_event.dart' as stats;
import '../services/audio_service.dart';
import 'log_provider.dart';
import 'loggable.dart';
import 'obd_data_provider.dart';

/// 骑行统计 Provider
/// 负责数据采样、事件检测、统计汇总
class RidingStatsProvider extends ChangeNotifier {
  final OBDDataProvider _obdDataProvider;
  final AudioService? _audioService;

  // 日志回调
  late final void Function(String source, LogType type, String message) _logCallback;

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

  List<stats.RidingEvent> get eventHistory => _eventHistory;
  bool get isRiding => _isRiding;

  RidingStatsProvider({
    required OBDDataProvider obdDataProvider,
    required LogProvider logProvider,
    AudioService? audioService,
  })  : _obdDataProvider = obdDataProvider,
        _audioService = audioService {
    _logCallback = createLogger(logProvider);
  }


  /// 开始骑行
  void startRide() {
    _isRiding = true;
    _rideStartTime = DateTime.now();
    _sampler.clear();
    _lastEventTime.clear();
    _eventHistory.clear();
    // _statistics = stats.EventStatistics.empty();

    // 启动降频采样定时器
    _startSampling();

    _logCallback?.call('Stats', LogType.info, '开始骑行统计');
    notifyListeners();
  }

  /// 结束骑行
  void endRide() {
    _isRiding = false;
    _stopSampling();

    final duration = _rideStartTime != null
        ? DateTime.now().difference(_rideStartTime!)
        : Duration.zero;
    _logCallback?.call('Stats', LogType.info, '骑行结束，总时长: ${duration.inMinutes}分钟');
    notifyListeners();
  }

  /// 启动降频采样
  void _startSampling() {
    _sampleTimer?.cancel();
    _sampleTimer = Timer.periodic(sampleInterval, (_) => _performSamplingAndDetection());
  }

  /// 停止采样
  void _stopSampling() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
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
    _sampler.addSample('lean', data.leanAngle.toDouble());
    _sampler.addSample('intakeTemp', data.intakeTemp.toDouble());
    _sampler.addSample('throttle', data.throttle.toDouble());

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
  bool _canTriggerEvent(stats.RidingEventType type, {Duration? customCooldown}) {
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

  /// 极限压弯检测：速度 >= 60km/h 且倾角 >= 30°
  void _checkExtremeLean(double? avgSpeed, double? avgLean) {
    if (avgSpeed == null || avgLean == null) return;
    if (avgSpeed < 60) return;
    if (avgLean < 30) return;
    if (!_canTriggerEvent(stats.RidingEventType.extremeLean, customCooldown: extremeLeanCooldown)) return;

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
    if (!_canTriggerEvent(stats.RidingEventType.longRiding, customCooldown: longRidingCooldown)) return;

    final event = stats.RidingEvent.longRiding(duration: duration);
    _addEvent(event);
  }

  /// 高效巡航检测：速度 60-80km/h 且负荷 < 30%
  void _checkEfficientCruising(double? avgSpeed, double? avgLoad, double? avgThrottle) {
    if (avgSpeed == null || avgLoad == null || avgThrottle == null) return;
    if (avgSpeed < 60 || avgSpeed > 80) return;
    if (avgLoad >= 30) return;
    if (!_canTriggerEvent(stats.RidingEventType.efficientCruising, customCooldown: efficientCruisingCooldown)) return;

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
    if (!_canTriggerEvent(stats.RidingEventType.coldEnvironmentRisk, customCooldown: coldEnvironmentCooldown)) return;

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

  @override
  void dispose() {
    _stopSampling();
    endRide();
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
    final variance = values.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) / values.length;
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
