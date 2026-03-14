import 'package:geolocator/geolocator.dart';
import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';

/// 日出日落时间数据类
class SunriseSunsetTimes {
  /// 日出时间
  final DateTime sunrise;

  /// 日落时间
  final DateTime sunset;

  const SunriseSunsetTimes({
    required this.sunrise,
    required this.sunset,
  });
}

/// 日出日落服务 - 负责获取设备位置并计算日出日落时间
class SunriseSunsetService {
  /// 获取当前位置的日出日落时间
  ///
  /// 返回 [SunriseSunsetTimes] 对象，包含今天日出日落时间
  /// 如果获取位置失败或计算失败，返回 null
  Future<SunriseSunsetTimes?> getSunriseSunsetTimes() async {
    try {
      // 获取当前位置（低精度，10秒超时）
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      // 获取当前时区的 UTC 偏移
      final utcOffset = DateTime.now().timeZoneOffset;

      // 计算今天的日出日落时间
      final result = getSunriseSunset(
        position.latitude,
        position.longitude,
        utcOffset,
        DateTime.now(),
      );

      return SunriseSunsetTimes(
        sunrise: result.sunrise,
        sunset: result.sunset,
      );
    } catch (e) {
      // 权限被拒绝或服务不可用时返回 null
      return null;
    }
  }
}
