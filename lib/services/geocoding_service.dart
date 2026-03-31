import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/obd_data.dart';

/// 逆地理编码服务 - 将坐标转换为地名（高德地图 HTTP API，国内可用）
///
/// 使用方式：
///   API Key 由 SettingsProvider 统一管理，通过 amapKey 参数传入。
///   amapKey 为空时自动降级为坐标显示。
///
/// 注意：高德坐标系为 GCJ-02，GPS 原始坐标为 WGS-84，需先转换
class GeocodingService {
  static const String _source = 'Geocoding';

  /// 根据坐标获取地名（高德逆地理编码）
  ///
  /// [amapKey] 高德 Web 服务 API Key，由调用方从 SettingsProvider 传入；空字符串时降级为坐标显示
  /// [logCallback] 可选日志回调，传入后会输出请求/响应/错误等关键日志
  static Future<String?> getPlaceName(
    double latitude,
    double longitude, {
    String amapKey = '',
    void Function(String source, LogType type, String message)? logCallback,
  }) async {
    final coordStr =
        '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';

    // Key 为空时返回坐标字符串（降级处理）
    if (amapKey.isEmpty) {
      logCallback?.call(
        _source,
        LogType.warning,
        '高德 API Key 未配置，跳过逆地理编码，降级为坐标：$coordStr',
      );
      return _formatCoordinate(latitude, longitude);
    }

    logCallback?.call(
      _source,
      LogType.info,
      '开始逆地理编码，WGS-84 坐标：$coordStr',
    );

    try {
      // WGS-84 → GCJ-02 坐标转换（高德要求 GCJ-02）
      final gcj = _wgs84ToGcj02(latitude, longitude);
      final gcjStr =
          '${gcj[0].toStringAsFixed(6)},${gcj[1].toStringAsFixed(6)}';
      logCallback?.call(
        _source,
        LogType.info,
        'WGS-84→GCJ-02 转换完成：$gcjStr（纬度,经度），发起 HTTP 请求',
      );

      final url = Uri.parse(
        'https://restapi.amap.com/v3/geocode/regeo'
        '?key=$amapKey'
        '&location=${gcj[1]},${gcj[0]}' // 高德格式：经度,纬度
        '&poitype=&radius=100&extensions=all&roadlevel=0',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      logCallback?.call(
        _source,
        LogType.info,
        'HTTP 响应 statusCode=${response.statusCode}，body 长度=${response.body.length}',
      );

      if (response.statusCode != 200) {
        logCallback?.call(
          _source,
          LogType.error,
          '逆地理编码请求失败，statusCode=${response.statusCode}，降级为坐标：$coordStr',
        );
        return _formatCoordinate(latitude, longitude);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final apiStatus = data['status'];
      final apiInfo = data['info'] ?? '';

      if (apiStatus != '1') {
        logCallback?.call(
          _source,
          LogType.error,
          '高德 API 返回错误：status=$apiStatus，info=$apiInfo，降级为坐标：$coordStr',
        );
        return _formatCoordinate(latitude, longitude);
      }

      final regeocode = data['regeocode'] as Map<String, dynamic>?;
      if (regeocode == null) {
        logCallback?.call(
          _source,
          LogType.warning,
          '响应中 regeocode 字段为空，降级为坐标：$coordStr',
        );
        return _formatCoordinate(latitude, longitude);
      }

      // 1. aois 第一条（面状区域，如建筑群/商圈，最语义化）
      final aois = regeocode['aois'] as List<dynamic>?;
      if (aois != null && aois.isNotEmpty) {
        final name = (aois[0] as Map<String, dynamic>)['name'] as String?;
        final distance = double.tryParse(
                ((aois[0] as Map<String, dynamic>)['distance'] ?? '9999')
                    .toString()) ??
            9999;
        if (name != null && name.isNotEmpty && distance < 500) {
          logCallback?.call(
            _source,
            LogType.success,
            '逆地理编码成功（aoi）：$name，距离 ${distance.toStringAsFixed(0)}m，原始坐标：$coordStr',
          );
          return name;
        }
      }

      // 2. pois 第一条（兴趣点，距离 < 300m 才采用，避免取到远处 POI）
      final pois = regeocode['pois'] as List<dynamic>?;
      if (pois != null && pois.isNotEmpty) {
        final name = (pois[0] as Map<String, dynamic>)['name'] as String?;
        final distance = double.tryParse(
                ((pois[0] as Map<String, dynamic>)['distance'] ?? '9999')
                    .toString()) ??
            9999;
        if (name != null && name.isNotEmpty && distance < 300) {
          logCallback?.call(
            _source,
            LogType.success,
            '逆地理编码成功（poi）：$name，距离 ${distance.toStringAsFixed(0)}m，原始坐标：$coordStr',
          );
          return name;
        }
      }

      // 3. roads 第一条 + district（如"海淀区 唐家岭路"）
      final roads = regeocode['roads'] as List<dynamic>?;
      final addressComponent =
          regeocode['addressComponent'] as Map<String, dynamic>?;
      final districtRaw = addressComponent?['district'];
      final district = districtRaw is String ? districtRaw : null;
      if (roads != null && roads.isNotEmpty) {
        final roadName = (roads[0] as Map<String, dynamic>)['name'] as String?;
        if (roadName != null && roadName.isNotEmpty) {
          final prefix =
              (district != null && district.isNotEmpty && district != '[]')
                  ? '$district '
                  : '';
          final result = '$prefix$roadName';
          logCallback?.call(
            _source,
            LogType.success,
            '逆地理编码成功（road）：$result，原始坐标：$coordStr',
          );
          return result;
        }
      }

      // 4. district + township 兜底
      if (addressComponent != null) {
        final parts = <String>[];
        if (district != null && district.isNotEmpty && district != '[]') {
          parts.add(district);
        }
        final townshipRaw = addressComponent['township'];
        final township = townshipRaw is String ? townshipRaw : null;
        if (township != null && township.isNotEmpty && township != '[]') {
          parts.add(township);
        }
        if (parts.isNotEmpty) {
          final result = parts.join(' ');
          logCallback?.call(
            _source,
            LogType.success,
            '逆地理编码成功（district+township）：$result，原始坐标：$coordStr',
          );
          return result;
        }
      }

      logCallback?.call(
        _source,
        LogType.warning,
        '逆地理编码响应中未找到有效地名（aoi/poi/road/district 均不满足条件），降级为坐标：$coordStr',
      );
      return _formatCoordinate(latitude, longitude);
    } on http.ClientException catch (e) {
      logCallback?.call(
        _source,
        LogType.error,
        '逆地理编码网络错误：${e.message}，坐标：$coordStr',
      );
      return _formatCoordinate(latitude, longitude);
    } catch (e) {
      // 网络失败或解析失败，降级为坐标格式
      logCallback?.call(
        _source,
        LogType.error,
        '逆地理编码异常：$e，坐标：$coordStr',
      );
      return _formatCoordinate(latitude, longitude);
    }
  }

  /// 坐标降级显示（无网络或未配置 Key 时）
  static String _formatCoordinate(double lat, double lng) {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// WGS-84 转 GCJ-02（火星坐标）
  /// 高德/腾讯地图使用 GCJ-02 坐标系，GPS 原始数据是 WGS-84
  /// 返回 [lat, lng] GCJ-02 坐标
  static List<double> wgs84ToGcj02(double lat, double lng) {
    return _wgs84ToGcj02(lat, lng);
  }

  static List<double> _wgs84ToGcj02(double lat, double lng) {
    const a = 6378245.0;
    const ee = 0.00669342162296594323;

    double dLat = _transformLat(lng - 105.0, lat - 35.0);
    double dLng = _transformLng(lng - 105.0, lat - 35.0);

    final radLat = lat / 180.0 * math.pi;
    final sinRad = math.sin(radLat);
    final sin2Rad = sinRad * sinRad;
    double magic = 1 -
        ee *
            (1 - ee) *
            (1 - ee) *
            (radLat.abs() < 0.00001 ? 1 : (1 - ee * sin2Rad));
    if (magic < 0.0000001) magic = 0.0000001;
    final sqrtMagic = math.sqrt(magic);
    dLat = dLat * 180.0 / ((a * (1 - ee)) / (magic * sqrtMagic) * math.pi);
    dLng = dLng * 180.0 / (a / sqrtMagic * math.cos(radLat) * math.pi);

    return [lat + dLat, lng + dLng];
  }

  static double _transformLat(double x, double y) {
    double ret = -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret += (160.0 * math.sin(y / 12.0 * math.pi) +
            320 * math.sin(y * math.pi / 30.0)) *
        2.0 /
        3.0;
    return ret;
  }

  static double _transformLng(double x, double y) {
    double ret = 300.0 +
        x +
        2.0 * y +
        0.1 * x * x +
        0.1 * x * y +
        0.1 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret += (150.0 * math.sin(x / 12.0 * math.pi) +
            300.0 * math.sin(x / 30.0 * math.pi)) *
        2.0 /
        3.0;
    return ret;
  }
}
