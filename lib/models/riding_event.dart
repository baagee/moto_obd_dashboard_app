import 'riding_record.dart';

/// 骑行事件类型枚举
enum RidingEventType {
  performanceBurst, // 性能爆发
  efficientCruising, // 高效巡航
  engineOverheating, // 发动机较热
  voltageAnomaly, // 电压异常
  longRiding, // 持续长时间骑行
  highEngineLoad, // 发动机高负荷
  engineWarmup, // 引擎预热
  coldEnvironmentRisk, // 低温环境风险
  extremeLean, // 高速大倾角压弯
  gearShiftUp, // 建议升档
  gearShiftDown, // 建议降档
}

String getEventTypeDisplayName(RidingEventType type) {
  switch (type) {
    case RidingEventType.performanceBurst:
      return '性能爆发';
    case RidingEventType.efficientCruising:
      return '高效巡航';
    case RidingEventType.engineOverheating:
      return '引擎过热';
    case RidingEventType.voltageAnomaly:
      return '电压异常';
    case RidingEventType.longRiding:
      return '长途骑行';
    case RidingEventType.highEngineLoad:
      return '高负荷';
    case RidingEventType.engineWarmup:
      return '引擎预热';
    case RidingEventType.coldEnvironmentRisk:
      return '低温风险';
    case RidingEventType.extremeLean:
      return '极限压弯';
    case RidingEventType.gearShiftUp:
      return '建议升档';
    case RidingEventType.gearShiftDown:
      return '建议降档';
  }
}

/// 骑行事件数据模型
class RidingEvent {
  final RidingEventType type;
  final String title;
  final String description;
  final double triggerValue;
  final double threshold;
  final DateTime timestamp;
  final Map<String, dynamic> additionalData;

  RidingEvent({
    required this.type,
    required this.title,
    required this.description,
    required this.triggerValue,
    required this.threshold,
    required this.timestamp,
    this.additionalData = const {},
  });

  factory RidingEvent.performanceBurst({
    required double rpm,
    required double speedChangeRate,
    DateTime? timestamp,
  }) {
    return RidingEvent(
      type: RidingEventType.performanceBurst,
      title: getEventTypeDisplayName(RidingEventType.performanceBurst),
      description: '发动机转速高于6300rpm且车速快速攀升',
      triggerValue: rpm,
      threshold: 6300.0,
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        'speedChangeRate': speedChangeRate,
        // 'condition': 'rpm > 6300 && speed rapidly increasing',
      },
    );
  }

  factory RidingEvent.efficientCruising({
    required double avgSpeed,
    required double avgLoad,
    required double throttleStability,
    DateTime? timestamp,
  }) {
    return RidingEvent(
      type: RidingEventType.efficientCruising,
      title: getEventTypeDisplayName(RidingEventType.efficientCruising),
      description: '车速稳定在70-100km/h且发动机负荷较低且节气门开度稳定',
      triggerValue: avgSpeed,
      threshold: 80.0, // 目标巡航速度
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        'avgSpeed': avgSpeed,
        'avgLoad': avgLoad,
        'throttleStability': throttleStability,
        // 'condition': 'speed 70-100 km/h, load < 30%, throttle stable',
      },
    );
  }

  factory RidingEvent.engineOverheating({
    required double coolantTemp,
    DateTime? timestamp,
  }) {
    return RidingEvent(
      type: RidingEventType.engineOverheating,
      title: getEventTypeDisplayName(RidingEventType.engineOverheating),
      description: '引擎冷却液温度高于110摄氏度',
      triggerValue: coolantTemp,
      threshold: 110.0,
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        "coolantTemp": coolantTemp,
        // 'condition': 'coolant temperature > 110°C',
      },
    );
  }

  factory RidingEvent.voltageAnomaly({
    required double voltage,
    required String anomalyType,
    DateTime? timestamp,
  }) {
    final threshold = voltage < 11.5 ? 11.0 : 15.3;
    return RidingEvent(
      type: RidingEventType.voltageAnomaly,
      title: getEventTypeDisplayName(RidingEventType.voltageAnomaly),
      description: '控制模块电压小于11.5V或者大于15.3V',
      triggerValue: voltage,
      threshold: threshold,
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        'voltage': voltage,
        'anomalyType': anomalyType, // 'low' or 'high'
        // 'condition': 'voltage < 11.5V or voltage > 15.3V',
      },
    );
  }

  factory RidingEvent.longRiding({
    required Duration duration,
    DateTime? timestamp,
  }) {
    return RidingEvent(
      type: RidingEventType.longRiding,
      title: getEventTypeDisplayName(RidingEventType.longRiding),
      description: '持续运行时间大于1.5小时',
      triggerValue: duration.inHours.toDouble(),
      threshold: 1.5,
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        'durationMinutes': duration.inMinutes,
        // 'condition': 'continuous running time > 1.5 hours',
      },
    );
  }

  factory RidingEvent.highEngineLoad({
    required double engineLoad,
    DateTime? timestamp,
  }) {
    return RidingEvent(
      type: RidingEventType.highEngineLoad,
      title: getEventTypeDisplayName(RidingEventType.highEngineLoad),
      description: '发动机负荷大于70%',
      triggerValue: engineLoad,
      threshold: 70.0,
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        "engineLoad": engineLoad,
        // 'condition': 'engine load > 70%',
      },
    );
  }

  factory RidingEvent.engineWarmup({
    required double coolantTemp,
    required double vehicleSpeed,
    DateTime? timestamp,
  }) {
    return RidingEvent(
      type: RidingEventType.engineWarmup,
      title: getEventTypeDisplayName(RidingEventType.engineWarmup),
      description: '发动机水温较低但转速过高，请温和驾驶避免发动机损伤',
      triggerValue: coolantTemp,
      threshold: 70.0,
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        'coolantTemp': coolantTemp,
        'vehicleSpeed': vehicleSpeed,
        // 'condition': 'coolant temperature < 70°C and engine RPM > 6000',
      },
    );
  }

  factory RidingEvent.coldEnvironmentRisk({
    required double intakeAirTemp,
    required double vehicleSpeed,
    DateTime? timestamp,
  }) {
    return RidingEvent(
      type: RidingEventType.coldEnvironmentRisk,
      title: getEventTypeDisplayName(RidingEventType.coldEnvironmentRisk),
      description: '环境温度较低，轮胎抓地力下降，请谨慎驾驶保持安全距离',
      triggerValue: intakeAirTemp,
      threshold: 5.0,
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        'intakeAirTemp': intakeAirTemp,
        'vehicleSpeed': vehicleSpeed,
        // 'condition': 'intake air temperature < 5°C and vehicle speed > 40 km/h',
      },
    );
  }

  factory RidingEvent.extremeLean({
    required double vehicleSpeed,
    required double leanAngle,
    required String direction, // 'left' or 'right'
    DateTime? timestamp,
  }) {
    final angleThreshold = 20.0;
    final speedThreshold = 60.0;

    return RidingEvent(
      type: RidingEventType.extremeLean,
      title: getEventTypeDisplayName(RidingEventType.extremeLean),
      description: direction == 'left'
          ? '高速左倾压弯：车速${vehicleSpeed.toStringAsFixed(0)}km/h，倾角${leanAngle.toStringAsFixed(1)}°'
          : '高速右倾压弯：车速${vehicleSpeed.toStringAsFixed(0)}km/h，倾角${leanAngle.abs().toStringAsFixed(1)}°',
      triggerValue: leanAngle,
      threshold: angleThreshold,
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        'vehicleSpeed': vehicleSpeed,
        'leanAngle': leanAngle,
        'direction': direction,
        'speedThreshold': speedThreshold,
        'angleThreshold': angleThreshold,
        // 'condition': 'speed >= 60 km/h && |leanAngle| >= 20°',
      },
    );
  }

  factory RidingEvent.gearShiftUp({
    required int rpm,
    required int gear,
    required int upshiftRpm,
    DateTime? timestamp,
  }) {
    return RidingEvent(
      type: RidingEventType.gearShiftUp,
      title: getEventTypeDisplayName(RidingEventType.gearShiftUp),
      description: '${gear}档均值转速 $rpm rpm 持续高于升档阈值，建议升至${gear + 1}档',
      triggerValue: rpm.toDouble(),
      threshold: upshiftRpm.toDouble(),
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        'currentGear': gear,
        'suggestedGear': gear + 1,
        'avgRpm': rpm,
        'upshiftRpm': upshiftRpm,
      },
    );
  }

  factory RidingEvent.gearShiftDown({
    required int rpm,
    required int gear,
    required int downshiftRpm,
    DateTime? timestamp,
  }) {
    return RidingEvent(
      type: RidingEventType.gearShiftDown,
      title: getEventTypeDisplayName(RidingEventType.gearShiftDown),
      description: '${gear}档均值转速 $rpm rpm 持续低于降档阈值，建议降至${gear - 1}档',
      triggerValue: rpm.toDouble(),
      threshold: downshiftRpm.toDouble(),
      timestamp: timestamp ?? DateTime.now(),
      additionalData: {
        'currentGear': gear,
        'suggestedGear': gear - 1,
        'avgRpm': rpm,
        'downshiftRpm': downshiftRpm,
      },
    );
  }

  /// 转换为数据库存储用的 [RidingRecordEvent]
  RidingRecordEvent toRidingRecordEvent() {
    return RidingRecordEvent(
      type: type.toString(),
      title: title,
      description: description,
      triggerValue: triggerValue,
      threshold: threshold,
      timestamp: timestamp.millisecondsSinceEpoch,
      additionalData: additionalData.isEmpty ? null : additionalData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'title': title,
      'description': description,
      'triggerValue': triggerValue,
      'threshold': threshold,
      'timestamp': timestamp.toIso8601String(),
      'additionalData': additionalData,
    };
  }

  @override
  String toString() {
    return 'RidingEvent(type: $type, title: $title, value: ${triggerValue.toStringAsFixed(1)}, threshold: $threshold)';
  }
}

/// 事件触发历史统计
class EventStatistics {
  final Map<RidingEventType, int> eventCounts;
  final DateTime lastUpdateTime;
  final RidingEvent? lastEvent;

  EventStatistics({
    required this.eventCounts,
    required this.lastUpdateTime,
    this.lastEvent,
  });

  factory EventStatistics.empty() {
    return EventStatistics(
      eventCounts: {},
      lastUpdateTime: DateTime.now(),
    );
  }

  EventStatistics copyWith({
    Map<RidingEventType, int>? eventCounts,
    DateTime? lastUpdateTime,
    RidingEvent? lastEvent,
  }) {
    return EventStatistics(
      eventCounts: eventCounts ?? this.eventCounts,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }

  void addEvent(RidingEvent event) {
    eventCounts[event.type] = (eventCounts[event.type] ?? 0) + 1;
  }

  int getTotalEventCount() {
    return eventCounts.values.fold(0, (sum, count) => sum + count);
  }
}
