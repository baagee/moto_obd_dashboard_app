import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/obd_data.dart';
import '../providers/obd_data_provider.dart';

/// 倾角传感器服务
/// 使用手机加速度计和陀螺仪计算摩托车转弯时的倾角
///
/// 手机放置方式：横屏放在车把上，屏幕上方朝左，下方朝右
class SensorService {
  final OBDDataProvider _obdDataProvider;
  void Function(String source, LogType type, String message)? logCallback;

  SensorService({
    required OBDDataProvider obdDataProvider,
    this.logCallback,
  })  : _obdDataProvider = obdDataProvider;

  // 采样间隔 10Hz = 100ms
  static const int sampleIntervalMs = 20;

  // 互补滤波系数
  static const double alpha = 0.98;

  // 移动平均窗口大小
  static const int movingAverageWindow = 5;

  // 死区滤波阈值（度）
  static const double deadzoneThreshold = 1.0;

  // 定时器
  Timer? _timer;

  // 传感器流订阅
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // 当前传感器值（加速度计 Y 和 Z 用于计算角度，陀螺仪 X 用于积分）
  double _accelY = 0;
  double _accelZ = 0;
  double _gyroX = 0;

  // 融合后的角度（弧度）
  double _fusedAngle = 0;

  // 零点偏移（校准后的角度）
  double _zeroOffset = 0;

  // 移动平均队列
  final List<double> _angleHistory = [];

  // 是否正在运行
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// 启动传感器服务
  void start() {
    if (_isRunning) return;

    _isRunning = true;
    logCallback?.call('Sensor', LogType.info, '倾角传感器服务启动');

    // 启动传感器监听
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: Duration(milliseconds: sampleIntervalMs),
    ).listen(_handleAccelerometer);

    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: Duration(milliseconds: sampleIntervalMs),
    ).listen(_handleGyroscope);

    // 启动定时器进行数据融合
    _timer = Timer.periodic(
      Duration(milliseconds: sampleIntervalMs),
      (_) => _processData(),
    );
  }

  /// 停止传感器服务
  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
  }

  /// 处理加速度计数据
  void _handleAccelerometer(AccelerometerEvent event) {
    // 横屏坐标系转换：
    // 手机横屏放置时，使用 Y 和 Z 轴计算倾角
    // 屏幕上方朝左，下方朝右
    _accelY = event.y;
    _accelZ = event.z;
  }

  /// 处理陀螺仪数据
  void _handleGyroscope(GyroscopeEvent event) {
    // 陀螺仪 X 对应翻滚角速度（左右倾斜）
    _gyroX = event.x;
  }

  /// 处理数据融合
  void _processData() {
    if (!_isRunning) return;

    // 计算加速度计角度（横屏时使用 X 轴）
    // atan2(y, z) 计算绕 X 轴的倾角
    final accelAngle = atan2(_accelY, _accelZ) * 180 / pi;

    // 互补滤波融合加速度计和陀螺仪
    // angle = alpha * (angle + gyro * dt) + (1 - alpha) * accelAngle
    _fusedAngle = alpha * (_fusedAngle + _gyroX * (sampleIntervalMs / 1000)) +
        (1 - alpha) * accelAngle;

    // 应用零点偏移
    double calibratedAngle = _fusedAngle - _zeroOffset;

    // 移动平均滤波
    _angleHistory.add(calibratedAngle);
    if (_angleHistory.length > movingAverageWindow) {
      _angleHistory.removeAt(0);
    }
    final averagedAngle = _angleHistory.reduce((a, b) => a + b) / _angleHistory.length;
    // 死区滤波
    if ((averagedAngle).abs() < deadzoneThreshold) {
      // 在死区内，不更新
      return;
    }

    // 确定方向并输出，限制最大角度为60度
    final int outputAngle = averagedAngle.abs().clamp(0, 60).round();
    final String direction = averagedAngle > 0 ? 'RIGHT' : 'LEFT';
    // logCallback?.call('Sensor', LogType.info, '倾角传感器当前值 $direction：$outputAngle');

    _obdDataProvider.updateLeanAngle(outputAngle, direction);
  }

  /// 零点校准
  /// 调用此方法将当前角度设置为零点
  void calibrate() {
    // 记录当前融合角度作为零点偏移
    _zeroOffset = _fusedAngle;
    // 清空历史数据
    _angleHistory.clear();
    logCallback?.call('Sensor', LogType.info, '倾角零点校准完成');
  }

  /// 释放资源
  void dispose() {
    stop();
  }
}
