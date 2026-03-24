import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/riding_record.dart';

/// GPS 服务 - 负责位置跟踪和轨迹点采集
class GPSService {
  StreamSubscription<Position>? _positionSubscription;
  final void Function(TrackPoint)? onTrackPoint;

  GPSService({this.onTrackPoint});

  /// 检查并请求位置权限
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// 获取当前位置
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// 开始位置跟踪
  void startTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 移动超过5米才更新
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (position.accuracy > 20) return; // 过滤精度过低的数据

      final trackPoint = TrackPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed * 3.6, // m/s 转 km/h
        timestamp: DateTime.now(),
      );
      onTrackPoint?.call(trackPoint);
    });
  }

  /// 停止位置跟踪
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    stopTracking();
  }
}
