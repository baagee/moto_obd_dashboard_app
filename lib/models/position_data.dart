import 'package:geolocator/geolocator.dart';

/// 位置数据模型（兼容 geolocator）
class PositionData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime timestamp;
  final double? accuracy; // GPS 水平精度（米），值越小越准，来自 GPS 硬件自报

  PositionData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.timestamp,
    this.accuracy,
  });

  factory PositionData.fromGeolocator(Position position) {
    return PositionData(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy, // geolocator Position 已提供，直接透传
    );
  }
}
