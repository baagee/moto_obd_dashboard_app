import 'dart:convert';
import 'package:http/http.dart' as http;

/// 逆地理编码服务 - 将坐标转换为地名（高德地图 HTTP API，国内可用）
///
/// 使用方式：
///   1. 在 https://lbs.amap.com/ 注册开发者账号，申请 Web 服务 API Key
///   2. 将 _amapKey 替换为你的 Key
///
/// 注意：高德坐标系为 GCJ-02，GPS 原始坐标为 WGS-84，需先转换
class GeocodingService {
  /// 高德 Web 服务 API Key（需替换为实际 Key）
  /// 申请地址：https://lbs.amap.com/dev/key/app
  /// https://lbs.amap.com/api/webservice/guide/api/georegeo
  static const String _amapKey = '99d4e91045213ccda8ebee56a8061eb2';

  /// 根据坐标获取地名（高德逆地理编码）
  static Future<String?> getPlaceName(double latitude, double longitude) async {
    // 未配置 Key 时返回坐标字符串（降级处理）
    if (_amapKey == 'YOUR_AMAP_WEB_API_KEY') {
      return _formatCoordinate(latitude, longitude);
    }

    try {
      // WGS-84 → GCJ-02 坐标转换（高德要求 GCJ-02）
      final gcj = _wgs84ToGcj02(latitude, longitude);

      final url = Uri.parse(
        'https://restapi.amap.com/v3/geocode/regeo'
        '?key=$_amapKey'
        '&location=${gcj[1]},${gcj[0]}'  // 高德格式：经度,纬度
        '&poitype=&radius=100&extensions=base&roadlevel=0',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return _formatCoordinate(latitude, longitude);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != '1') return _formatCoordinate(latitude, longitude);

      final regeocode = data['regeocode'] as Map<String, dynamic>?;
      final addressComponent = regeocode?['addressComponent'] as Map<String, dynamic>?;

      if (addressComponent == null) return _formatCoordinate(latitude, longitude);

      // 组合地址：区 + 街道/乡镇
      final parts = <String>[];

      final district = addressComponent['district'] as String?;
      if (district != null && district.isNotEmpty && district != '[]') {
        parts.add(district);
      }

      // 优先用 streetNumber（精确到街道），没有则用 township（乡镇）
      final streetNumber = addressComponent['streetNumber'] as Map<String, dynamic>?;
      final street = streetNumber?['street'] as String?;
      if (street != null && street.isNotEmpty && street != '[]') {
        parts.add(street);
      } else {
        final township = addressComponent['township'] as String?;
        if (township != null && township.isNotEmpty && township != '[]') {
          parts.add(township);
        }
      }

      return parts.isNotEmpty ? parts.join(' ') : _formatCoordinate(latitude, longitude);
    } catch (e) {
      // 网络失败或解析失败，降级为坐标格式
      return _formatCoordinate(latitude, longitude);
    }
  }

  /// 坐标降级显示（无网络或未配置 Key 时）
  static String _formatCoordinate(double lat, double lng) {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// WGS-84 转 GCJ-02（火星坐标）
  /// 高德/腾讯地图使用 GCJ-02 坐标系，GPS 原始数据是 WGS-84
  static List<double> _wgs84ToGcj02(double lat, double lng) {
    const a = 6378245.0;
    const ee = 0.00669342162296594323;

    double dLat = _transformLat(lng - 105.0, lat - 35.0);
    double dLng = _transformLng(lng - 105.0, lat - 35.0);

    final radLat = lat / 180.0 * 3.14159265358979324;
    double magic = 1 - ee * (1 - ee) * (1 - ee) * (radLat.abs() < 0.00001
        ? 1
        : (1 - ee * _sin2(radLat)));
    magic = magic < 0.0000001 ? 0.0000001 : magic;
    final sqrtMagic = magic < 0 ? 0.0 : (magic < 0.0001 ? 0.01 : _mySqrt(magic));
    dLat = dLat * 180.0 / ((a * (1 - ee)) / (magic * sqrtMagic) * 3.14159265358979324);
    dLng = dLng * 180.0 / (a / sqrtMagic * _myCos(radLat) * 3.14159265358979324);

    return [lat + dLat, lng + dLng];
  }

  static double _transformLat(double x, double y) {
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * _mySqrt(x.abs());
    ret += (20.0 * _mySin(6.0 * x * 3.14159265358979324) + 20.0 * _mySin(2.0 * x * 3.14159265358979324)) * 2.0 / 3.0;
    ret += (20.0 * _mySin(y * 3.14159265358979324) + 40.0 * _mySin(y / 3.0 * 3.14159265358979324)) * 2.0 / 3.0;
    ret += (160.0 * _mySin(y / 12.0 * 3.14159265358979324) + 320 * _mySin(y * 3.14159265358979324 / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  static double _transformLng(double x, double y) {
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * _mySqrt(x.abs());
    ret += (20.0 * _mySin(6.0 * x * 3.14159265358979324) + 20.0 * _mySin(2.0 * x * 3.14159265358979324)) * 2.0 / 3.0;
    ret += (20.0 * _mySin(x * 3.14159265358979324) + 40.0 * _mySin(x / 3.0 * 3.14159265358979324)) * 2.0 / 3.0;
    ret += (150.0 * _mySin(x / 12.0 * 3.14159265358979324) + 300.0 * _mySin(x / 30.0 * 3.14159265358979324)) * 2.0 / 3.0;
    return ret;
  }

  static double _sin2(double x) => _mySin(x) * _mySin(x);
  static double _mySin(double x) {
    double result = 0;
    double term = x;
    int sign = 1;
    for (int i = 1; i <= 10; i++) {
      result += sign * term;
      term *= x * x / ((2 * i) * (2 * i + 1));
      sign = -sign;
    }
    return result;
  }
  static double _myCos(double x) => _mySin(x + 1.5707963267948966);
  static double _mySqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 20; i++) r = (r + x / r) / 2;
    return r;
  }
}
