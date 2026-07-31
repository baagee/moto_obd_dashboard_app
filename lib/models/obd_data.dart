/// OBD数据模型
class OBDData {
  final int rpm;
  final int speed;
  final int throttle; // 油门开度
  final int load; // 发动机负载
  final int pressure; // 进气歧管压力MAP
  final double voltage; // 电压
  final int coolantTemp; // 冷却液水温
  final int intakeTemp; // 进气温度
  final int gear; // 档位 (0=空档, 1-6=实际档位)

  OBDData({
    required this.rpm,
    required this.speed,
    required this.gear,
    required this.throttle,
    required this.load,
    required this.pressure,
    required this.voltage,
    required this.coolantTemp,
    required this.intakeTemp,
  });

  OBDData copyWith({
    int? rpm,
    int? speed,
    int? gear,
    int? throttle,
    int? load,
    int? pressure,
    double? voltage,
    int? coolantTemp,
    int? intakeTemp,
  }) {
    return OBDData(
      rpm: rpm ?? this.rpm,
      speed: speed ?? this.speed,
      gear: gear ?? this.gear,
      throttle: throttle ?? this.throttle,
      load: load ?? this.load,
      pressure: pressure ?? this.pressure,
      voltage: voltage ?? this.voltage,
      coolantTemp: coolantTemp ?? this.coolantTemp,
      intakeTemp: intakeTemp ?? this.intakeTemp,
    );
  }
}