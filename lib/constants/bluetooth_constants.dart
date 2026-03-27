/// 蓝牙与 OBD 相关时间配置常量
///
/// 本文件集中管理蓝牙扫描、连接、重连以及 OBD 数据轮询的时序配置
class BluetoothConstants {
  BluetoothConstants._();

  // ==================== 蓝牙扫描相关 ====================

  /// 蓝牙设备扫描超时时间
  /// 超过此时间后停止扫描，扫描过程中发现的所有设备将展示给用户
  static const Duration scanTimeout = Duration(seconds: 3);

  /// 自动重连前等待扫描发现设备的时间
  /// 连接断开后等待扫描找到目标设备的时间，确保设备在可见范围内
  static const Duration scanWaitTimeout = Duration(milliseconds: 3300);

  // ==================== 蓝牙连接相关 ====================

  /// 蓝牙设备连接超时时间
  /// 发起连接请求后超过此时间未成功建立连接则视为连接失败
  static const Duration connectionTimeout = Duration(seconds: 2);

  /// ELM327 单条 AT 命令响应超时时间（响应驱动模式的兜底）
  static const Duration obdCommandResponseTimeout = Duration(milliseconds: 500);

  /// ATZ 复位命令响应超时时间（复位比普通命令慢）
  static const Duration elm327ResetResponseTimeout = Duration(milliseconds: 1000);

  // ==================== 自动重连相关 ====================

  /// 最大自动重连次数
  /// 连接断开后尝试自动重连的最大次数，达到次数后停止重连并提示用户
  static const int maxReconnectAttempts = 2;

  /// 自动重连重试间隔
  /// 每次重连尝试失败后等待再重试的时间间隔
  static const Duration reconnectRetryInterval = Duration(milliseconds: 500);

  // ==================== OBD 数据轮询相关 ====================

  /// 轮询定时器基础间隔（毫秒）
  /// OBD 数据轮询的基准时间单元，所有 PID 按此间隔触发检查
  static const int pollingBaseIntervalMs = 50;

  /// 高速 PID 轮询间隔（毫秒）
  /// 高速数据的车速、转速等 PID 的发送间隔，约14Hz
  static const int highSpeedPollingIntervalMs = 50;

  /// 中速 PID 轮询间隔（毫秒）
  /// 中速数据的节气门、进气温度、进气歧管压力等 PID 的发送间隔，约4Hz
  static const int mediumSpeedPollingIntervalMs = 200;

  /// 低速 PID 轮询间隔（毫秒）
  /// 低速数据的水温、负载、电压等 PID 的发送间隔，2Hz
  static const int lowSpeedPollingIntervalMs = 500;
}
