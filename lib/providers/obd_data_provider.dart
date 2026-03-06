import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/obd_data.dart';

/// OBD数据提供者 - 管理所有动态数据
class OBDDataProvider extends ChangeNotifier {
  // 数据更新定时器
  Timer? _updateTimer;
  Timer? _eventTimer;

  // OBD数据
  OBDData _data = OBDData(
    rpm: 8500,
    speed: 124,
    gear: 4,
    throttle: 65,
    load: 42,
    leanAngle: 32,
    leanDirection: 'LEFT',
    pressure: 101,
    voltage: 14.2,
    coolantTemp: 92,
    intakeTemp: 34,
    rpmHistory: [],
    velocityHistory: [],
  );

  // 骑行事件列表
  final List<RidingEvent> _events = [];

  // 随机数生成器
  final Random _random = Random();

  // 最大数据点数
  static const int _maxDataPoints = 30;
  static const int _maxPressurePoints = 15;

  // 气压历史
  final List<int> _pressureHistory = [];

  // Getter
  OBDData get data => _data;
  List<RidingEvent> get events => _events;
  List<int> get pressureHistory => _pressureHistory;

  OBDDataProvider() {
    _initializeData();
    _startTimers();
  }

  /// 初始化数据
  void _initializeData() {
    // 初始化历史数据
    for (int i = 0; i < _maxDataPoints; i++) {
      _data = _data.copyWith(
        rpmHistory: [..._data.rpmHistory, _generateRPM()],
        velocityHistory: [..._data.velocityHistory, _generateVelocity()],
      );
    }

    // 初始化气压历史
    for (int i = 0; i < _maxPressurePoints; i++) {
      _pressureHistory.add(_generatePressure());
    }

    // 初始化事件
    for (int i = 0; i < 3; i++) {
      _events.insert(0, _generateEvent());
    }
  }

  /// 启动定时器
  void _startTimers() {
    // 每X秒更新OBD数据
    _updateTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _updateOBDData();
    });

    // 每8秒添加新事件
    _eventTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _addEvent();
    });
  }

  /// 更新OBD数据
  void _updateOBDData() {
    // 更新历史数据
    List<int> newRpmHistory = [..._data.rpmHistory, _generateRPM()];
    List<int> newVelocityHistory = [..._data.velocityHistory, _generateVelocity()];

    if (newRpmHistory.length > _maxDataPoints) {
      newRpmHistory.removeAt(0);
      newVelocityHistory.removeAt(0);
    }

    // 更新气压历史
    _pressureHistory.add(_generatePressure());
    if (_pressureHistory.length > _maxPressurePoints) {
      _pressureHistory.removeAt(0);
    }

    final newRpm = newRpmHistory.last;
    final newSpeed = newVelocityHistory.last;

    _data = _data.copyWith(
      rpm: newRpm,
      speed: newSpeed,
      gear: _calculateGear(newSpeed),
      throttle: _generateThrottle(),
      load: _generateLoad(),
      leanAngle: _generateLeanAngle(),
      leanDirection: _random.nextBool() ? 'LEFT' : 'RIGHT',
      pressure: _pressureHistory.last,
      voltage: _generateVoltage(),
      coolantTemp: _generateCoolantTemp(),
      intakeTemp: _generateIntakeTemp(),
      rpmHistory: newRpmHistory,
      velocityHistory: newVelocityHistory,
    );

    notifyListeners();
  }

  /// 添加骑行事件
  void _addEvent() {
    _events.insert(0, _generateEvent());
    if (_events.length > 5) {
      _events.removeLast();
    }
    notifyListeners();
  }

  // ========== 数据生成方法 ==========

  int _generateRPM() => 6000 + _random.nextInt(6000);

  int _generateVelocity() => 80 + _random.nextInt(120);

  int _generateThrottle() => 20 + _random.nextInt(60);

  int _generateLoad() => 20 + _random.nextInt(50);

  int _generateLeanAngle() => _random.nextInt(45);

  int _generatePressure() => 95 + _random.nextInt(15);

  double _generateVoltage() => 13.5 + _random.nextDouble() * 1.5;

  int _generateCoolantTemp() => 85 + _random.nextInt(20);

  int _generateIntakeTemp() => 28 + _random.nextInt(15);

  int _calculateGear(int speed) {
    if (speed < 30) return 1;
    if (speed < 60) return 2;
    if (speed < 100) return 3;
    if (speed < 150) return 4;
    if (speed < 200) return 5;
    return 6;
  }

  RidingEvent _generateEvent() {
    final events = [
      RidingEvent(type: EventType.warning, title: 'Critical Alert', message: 'High Water Temp Detected'),
      RidingEvent(type: EventType.info, title: 'Event Logged', message: 'Aggressive Cornering'),
      RidingEvent(type: EventType.success, title: 'System Check', message: 'ABS Diagnostics: Nominal'),
      RidingEvent(type: EventType.warning, title: 'Caution', message: 'Tire Pressure Low'),
      RidingEvent(type: EventType.info, title: 'Performance', message: 'Optimal Power Band'),
      RidingEvent(type: EventType.success, title: 'Status', message: 'Fuel Efficiency: Good'),
    ];
    return events[_random.nextInt(events.length)];
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _eventTimer?.cancel();
    super.dispose();
  }
}