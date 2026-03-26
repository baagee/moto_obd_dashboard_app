import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// GPS定位服务
class LocationService {
  /// 检查定位权限
  static Future<bool> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  /// 请求定位权限
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// 请求后台定位权限（Android 10+ / iOS）
  /// 在骑行开始前调用，确保 APP 切后台时 GPS 仍然工作
  static Future<bool> requestBackgroundPermission() async {
    try {
      // 先检查前台定位权限
      final foregroundStatus = await Permission.location.status;
      if (!foregroundStatus.isGranted) {
        final result = await Permission.location.request();
        if (!result.isGranted) return false;
      }

      // Android 10+ 需要单独申请后台定位权限
      final backgroundStatus = await Permission.locationAlways.status;
      if (!backgroundStatus.isGranted) {
        final result = await Permission.locationAlways.request();
        return result.isGranted;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 检查是否有后台定位权限
  static Future<bool> hasBackgroundPermission() async {
    try {
      final status = await Permission.locationAlways.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// 检查定位服务是否开启
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// 获取当前位置
  static Future<Position?> getCurrentPosition() async {
    try {
      // 检查服务
      if (!await isLocationServiceEnabled()) {
        return null;
      }

      // 检查权限
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        final permission = await requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }

      // 获取位置
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取位置更新流（用于持续追踪）
  static Stream<Position> getPositionStream({
    int distanceFilter = 10,  // 米
    Duration? timeLimit,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
      ),
    );
  }
}

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
