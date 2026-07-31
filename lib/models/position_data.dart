import 'package:geolocator/geolocator.dart';

/// 位置数据模型（兼容 geolocator）
class PositionData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime timestamp;

  PositionData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.timestamp,
  });

  factory PositionData.fromGeolocator(Position position) {
    return PositionData(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      timestamp: position.timestamp,
    );
  }
}
