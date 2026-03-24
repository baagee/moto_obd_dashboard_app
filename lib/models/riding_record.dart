import 'package:latlong2/latlong.dart';
import 'riding_event.dart';

/// 骑行记录模型
class RidingRecord {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double distance;         // 里程 (km)
  final Duration duration;       // 时长
  final double maxSpeed;         // 最高速度 (km/h)
  final double avgSpeed;         // 平均速度 (km/h)
  final int maxLeanLeft;        // 左倾最大角度
  final int maxLeanRight;       // 右倾最大角度
  final Map<RidingEventType, int> eventCounts;  // 事件统计
  final List<TrackPoint> trackPoints;          // GPS轨迹点
  final bool isCompleted;        // 是否已完成

  RidingRecord({
    required this.id,
    required this.startTime,
    this.endTime,
    this.distance = 0,
    this.duration = Duration.zero,
    this.maxSpeed = 0,
    this.avgSpeed = 0,
    this.maxLeanLeft = 0,
    this.maxLeanRight = 0,
    this.eventCounts = const {},
    this.trackPoints = const [],
    this.isCompleted = false,
  });

  RidingRecord copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    double? distance,
    Duration? duration,
    double? maxSpeed,
    double? avgSpeed,
    int? maxLeanLeft,
    int? maxLeanRight,
    Map<RidingEventType, int>? eventCounts,
    List<TrackPoint>? trackPoints,
    bool? isCompleted,
  }) {
    return RidingRecord(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      maxLeanLeft: maxLeanLeft ?? this.maxLeanLeft,
      maxLeanRight: maxLeanRight ?? this.maxLeanRight,
      eventCounts: eventCounts ?? this.eventCounts,
      trackPoints: trackPoints ?? this.trackPoints,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// 计算平均速度
  double calculateAvgSpeed() {
    if (duration.inMinutes == 0) return 0;
    return (distance / duration.inMinutes) * 60;
  }
}

/// 轨迹点模型
class TrackPoint {
  final double latitude;
  final double longitude;
  final double speed;       // 对应速度 (km/h)
  final DateTime timestamp;

  TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.timestamp,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'speed': speed,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
    latitude: json['latitude'] as double,
    longitude: json['longitude'] as double,
    speed: json['speed'] as double,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
