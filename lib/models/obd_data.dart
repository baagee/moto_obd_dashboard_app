/// OBD数据模型
class OBDData {
  final int rpm;
  final int speed;
  final int gear;
  final int throttle;
  final int load;
  final int leanAngle;
  final String leanDirection;
  final int pressure;
  final double voltage;
  final int coolantTemp;
  final int intakeTemp;
  final List<int> rpmHistory;
  final List<int> velocityHistory;

  OBDData({
    required this.rpm,
    required this.speed,
    required this.gear,
    required this.throttle,
    required this.load,
    required this.leanAngle,
    required this.leanDirection,
    required this.pressure,
    required this.voltage,
    required this.coolantTemp,
    required this.intakeTemp,
    required this.rpmHistory,
    required this.velocityHistory,
  });

  OBDData copyWith({
    int? rpm,
    int? speed,
    int? gear,
    int? throttle,
    int? load,
    int? leanAngle,
    String? leanDirection,
    int? pressure,
    double? voltage,
    int? coolantTemp,
    int? intakeTemp,
    List<int>? rpmHistory,
    List<int>? velocityHistory,
  }) {
    return OBDData(
      rpm: rpm ?? this.rpm,
      speed: speed ?? this.speed,
      gear: gear ?? this.gear,
      throttle: throttle ?? this.throttle,
      load: load ?? this.load,
      leanAngle: leanAngle ?? this.leanAngle,
      leanDirection: leanDirection ?? this.leanDirection,
      pressure: pressure ?? this.pressure,
      voltage: voltage ?? this.voltage,
      coolantTemp: coolantTemp ?? this.coolantTemp,
      intakeTemp: intakeTemp ?? this.intakeTemp,
      rpmHistory: rpmHistory ?? this.rpmHistory,
      velocityHistory: velocityHistory ?? this.velocityHistory,
    );
  }
}

/// 骑行事件类型
enum EventType {
  warning,
  info,
  success,
}

/// 骑行事件模型
class RidingEvent {
  final EventType type;
  final String title;
  final String message;
  final DateTime timestamp;

  RidingEvent({
    required this.type,
    required this.title,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 诊断日志类型
enum LogType {
  success,
  warning,
  error,
  info,
}

/// 诊断日志模型
class DiagnosticLog {
  final LogType type;
  final String message;
  final DateTime timestamp;

  DiagnosticLog({
    required this.type,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}