/// OBD数据模型
class OBDData {
  final int rpm;
  final int speed;
  final int throttle;// 油门开度
  final int load;//发动机负载
  final String leanDirection;// 压弯方向，左右
  final int pressure; // 进气歧管压力MAP
  final double voltage; // 电压
  final int coolantTemp; // 冷却液水温
  final int intakeTemp; // 进气温度

  final List<int> rpmHistory;
  final List<int> velocityHistory;
  final int leanAngle; // 压弯倾角

  // final int gear;// 档位


  OBDData({
    required this.rpm,
    required this.speed,
    // required this.gear,
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
    // int? gear,
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
      // gear: gear ?? this.gear,
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
  error,
  warning,
  info,
}

/// 诊断日志模型
class DiagnosticLog {
  final LogType type;
  final String message;
  final DateTime timestamp;
  final String source; // 日志来源

  DiagnosticLog({
    required this.type,
    required this.message,
    required this.source,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}