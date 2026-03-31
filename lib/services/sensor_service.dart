import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/obd_data.dart';
import '../providers/obd_data_provider.dart';
import '../providers/settings_provider.dart';

/// 倾角传感器服务
/// 使用手机加速度计和陀螺仪计算摩托车转弯时的倾角
///
/// 手机放置方式：横屏放在车把上，屏幕上方朝左，下方朝右
class SensorService {
  final OBDDataProvider _obdDataProvider;
  SettingsProvider? _settings;
  void Function(String source, LogType type, String message)? logCallback;

  SensorService({
    required OBDDataProvider obdDataProvider,
    this.logCallback,
    SettingsProvider? settings,
  })  : _obdDataProvider = obdDataProvider,
        _settings = settings;

  /// 更新 SettingsProvider 引用；settings 变更时由 SensorProvider 调用
  void updateSettings(SettingsProvider? settings) {
    _settings = settings;
    // 滤波参数变更后清空历史，避免用旧参数数据影响新参数计算
    _angleHistory.clear();
  }

  // 采样间隔 15ms ≈ 66Hz
  static const int sampleIntervalMs = 15;

  // 滤波参数 getter：有 SettingsProvider 时从中读取，否则使用硬编码默认值
  double get _alpha => _settings?.sensorAlpha ?? 0.98;
  int get _movingAverageWindow => _settings?.movingAverageWindow ?? 5;
  double get _deadzoneThreshold => _settings?.deadzoneThreshold ?? 1.0;

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
    // codeflicker-fix: OPT-Issue-10/omvh7ni7j93qpiynr7sw
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: sampleIntervalMs),
    ).listen(_handleAccelerometer);

    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: sampleIntervalMs),
    ).listen(_handleGyroscope);

    // 启动定时器进行数据融合
    _timer = Timer.periodic(
      const Duration(milliseconds: sampleIntervalMs),
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

    final alpha = _alpha;
    final window = _movingAverageWindow;
    final deadzone = _deadzoneThreshold;

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
    if (_angleHistory.length > window) {
      _angleHistory.removeAt(0);
    }
    final averagedAngle =
        _angleHistory.reduce((a, b) => a + b) / _angleHistory.length;
    // 死区滤波
    if ((averagedAngle).abs() < deadzone) {
      // 在死区内，不更新
      return;
    }

    // 确定方向并输出，限制最大角度为60度
    final int outputAngle = averagedAngle.abs().clamp(0, 60).round();
    final String direction =
        averagedAngle == 0 ? 'NONE' : (averagedAngle > 0 ? 'RIGHT' : 'LEFT');
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
