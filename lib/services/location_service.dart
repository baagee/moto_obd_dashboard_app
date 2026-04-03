import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/obd_data.dart';

/// 定位权限检查结果
enum LocationPermissionStatus {
  granted, // 已授权（前台）
  deniedForever, // 永久拒绝，需引导去设置页
  denied, // 被拒绝（可再次请求）
  serviceDisabled, // 系统定位服务未开启
}

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

  /// APP 启动时检查并请求前台定位权限（与蓝牙权限检查时机一致）
  ///
  /// 返回 [LocationPermissionStatus] 供调用方决定是否弹窗提示：
  /// - [LocationPermissionStatus.granted] — 已有权限，无需弹窗
  /// - [LocationPermissionStatus.serviceDisabled] — 系统定位服务关闭，引导开启
  /// - [LocationPermissionStatus.deniedForever] — 永久拒绝，引导去设置
  /// - [LocationPermissionStatus.denied] — 被拒绝（用户手动点拒绝），提示说明
  static Future<LocationPermissionStatus> checkAndRequestOnLaunch() async {
    try {
      // 1. 检查系统定位服务是否开启
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      // 2. 检查当前权限状态
      var permission = await Geolocator.checkPermission();

      // 3. 未请求过则发起请求
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationPermissionStatus.deniedForever;
      }

      if (permission == LocationPermission.denied) {
        return LocationPermissionStatus.denied;
      }

      // whileInUse 或 always 均视为已授权
      return LocationPermissionStatus.granted;
    } catch (e) {
      return LocationPermissionStatus.denied;
    }
  }

  /// 打开系统设置页（引导用户手动开启定位权限）
  static Future<void> openSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// 请求后台定位权限（Android 10+ / iOS）
  /// 在骑行开始前调用，确保 APP 切后台时 GPS 仍然工作
  ///
  /// [logCallback] 可选日志回调，传入后输出每个分支的权限状态
  static Future<bool> requestBackgroundPermission({
    void Function(String source, LogType type, String message)? logCallback,
  }) async {
    try {
      // 先检查前台定位权限
      final foregroundStatus = await Permission.location.status;
      if (!foregroundStatus.isGranted) {
        final result = await Permission.location.request();
        if (!result.isGranted) {
          logCallback?.call('GPS', LogType.error, '前台定位权限被拒绝，后台权限无法申请');
          return false;
        }
      }

      // Android 10+ 需要单独申请后台定位权限
      final backgroundStatus = await Permission.locationAlways.status;
      if (!backgroundStatus.isGranted) {
        final result = await Permission.locationAlways.request();
        if (!result.isGranted) {
          logCallback?.call('GPS', LogType.warning, '后台定位权限被拒绝，切换到后台时 GPS 追踪可能暂停');
        }
        return result.isGranted;
      }

      return true;
    } catch (e) {
      logCallback?.call('GPS', LogType.error, '请求后台定位权限异常: $e');
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
  ///
  /// [logCallback] 可选日志回调，传入后输出定位各阶段状态和失败原因
  static Future<Position?> getCurrentPosition({
    void Function(String source, LogType type, String message)? logCallback,
  }) async {
    try {
      // 检查服务
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        logCallback?.call('GPS', LogType.warning, '系统定位服务未开启，无法获取位置');
        return null;
      }

      // 检查权限
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        final permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          logCallback?.call('GPS', LogType.error, '定位权限被拒绝，无法获取位置');
          return null;
        }
        if (permission == LocationPermission.deniedForever) {
          logCallback?.call('GPS', LogType.error, '定位权限被永久拒绝，请前往系统设置授权');
          return null;
        }
      }

      // 获取位置
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      logCallback?.call('GPS', LogType.error, '获取 GPS 位置异常: $e');
      return null;
    }
  }

  /// 获取位置更新流（用于持续追踪）
  static Stream<Position> getPositionStream({
    int distanceFilter = 10, // 米
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
