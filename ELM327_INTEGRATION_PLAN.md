# ELM327 OBD 蓝牙改造方案

> 生成日期: 2026-03-03

## 需求确认

| 项目 | 选择 |
|------|------|
| 目标平台 | Android |
| 连接方式 | 蓝牙 BLE |
| 数据需求 | 基础数据 + 温度电压 |
| 倾斜角度 | 手机陀螺仪传感器 |
| 档位 | 从 RPM/速度计算推导 |
| 模拟数据 | 保留，可切换模式 |
| 实现范围 | 完整实现 |

---

## 改造清单

### 1. 依赖添加 (`pubspec.yaml`)

```yaml
dependencies:
  flutter_blue_plus: ^1.32.0    # BLE 连接
  permission_handler: ^11.0.0   # Android 权限
  sensors_plus: ^4.0.0          # 手机陀螺仪
```

### 2. 新增文件

| 文件路径 | 说明 |
|----------|------|
| `lib/services/bluetooth_service.dart` | BLE 扫描、连接、状态管理 |
| `lib/services/obd_service.dart` | ELM327 命令发送、PID 数据解析 |
| `lib/models/elm327_device.dart` | ELM327 设备模型 |
| `lib/screens/device_scan_screen.dart` | 蓝牙设备扫描 UI |

### 3. 修改文件

| 文件路径 | 改动内容 |
|----------|----------|
| `lib/providers/obd_data_provider.dart` | 添加数据源切换逻辑，集成 OBD 服务和陀螺仪 |
| `lib/widgets/top_navigation_bar.dart` | 实现 "LINK VEHICLE" 按钮跳转到扫描页 |
| `lib/widgets/status_footer.dart` | 显示真实连接状态（蓝牙、OBD） |
| `lib/main.dart` | 初始化蓝牙服务 |
| `android/app/src/main/AndroidManifest.xml` | 添加蓝牙+位置权限 |

---

## 数据支持详情

| 数据 | 来源 | PID/方法 | 备注 |
|------|------|----------|------|
| RPM | ELM327 | PID 0C | 引擎转速 |
| 速度 | ELM327 | PID 0D | km/h |
| 档位 | 计算 | RPM/速度速比算法 | 需校准参数 |
| 油门位置 | ELM327 | PID 11 | 节气门开度 % |
| 发动机负载 | ELM327 | PID 04 | % |
| 冷却液温度 | ELM327 | PID 05 | °C |
| 进气温度 | ELM327 | PID 0F | °C |
| 电池电压 | ELM327 | AT RV | V |
| 倾斜角度 | 手机传感器 | sensors_plus | 加速度计+陀螺仪 |

---

## 实现步骤

### 步骤 1: 权限配置

在 `android/app/src/main/AndroidManifest.xml` 添加:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### 步骤 2: 蓝牙服务 (`lib/services/bluetooth_service.dart`)

核心功能:
- 扫描附近 BLE 设备
- 连接/断开 ELM327 设备
- 发现服务和特征值
- 管理连接状态

### 步骤 3: OBD 服务 (`lib/services/obd_service.dart`)

核心功能:
- ELM327 初始化 (AT 命令)
  - `ATZ` - 重置
  - `ATE0` - 关闭回显
  - `ATL0` - 关闭换行
  - `ATSP0` - 自动协议
- PID 数据请求和解析
- 周期性数据轮询

### 步骤 4: 传感器集成

使用 `sensors_plus` 获取倾斜角度:

```dart
import 'package:sensors_plus/sensors_plus.dart';

// 加速度计监听
accelerometerEvents.listen((event) {
  // 计算倾斜角度
  double roll = atan2(event.y, event.z) * 180 / pi;
  double pitch = atan2(event.x, event.z) * 180 / pi;
});
```

### 步骤 5: Provider 改造

在 `OBDDataProvider` 中添加:

```dart
enum DataSource { simulation, real }

class OBDDataProvider extends ChangeNotifier {
  DataSource _dataSource = DataSource.simulation;
  BluetoothService? _bluetoothService;
  OBDService? _obdService;

  void switchDataSource(DataSource source) {
    _dataSource = source;
    // 切换数据源逻辑
  }
}
```

### 步骤 6: 档位计算算法

```dart
int calculateGear(int rpm, int speed) {
  if (speed < 5) return 0; // 停止状态

  double ratio = rpm / speed;

  // 典型摩托车速比 (需要根据实际车型校准)
  if (ratio > 150) return 1;
  if (ratio > 110) return 2;
  if (ratio > 85) return 3;
  if (ratio > 65) return 4;
  if (ratio > 50) return 5;
  return 6;
}
```

### 步骤 7: 设备扫描 UI

创建 `DeviceScanScreen`:
- 显示扫描中的 BLE 设备列表
- 显示设备名称和信号强度
- 连接按钮
- 连接状态指示

### 步骤 8: 状态显示

修改 `StatusFooter` 显示:
- 蓝牙连接状态
- OBD 设备状态
- 数据更新状态

---

## 注意事项

1. **ELM327 BLE 特征值**
   - 通常使用 Nordic UART Service (NUS)
   - Service UUID: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
   - RX: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
   - TX: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`

2. **权限处理**
   - Android 12+ 需要运行时请求蓝牙权限
   - 位置权限用于 BLE 扫描

3. **错误处理**
   - 连接超时处理
   - 断线重连机制
   - 数据异常过滤

4. **性能优化**
   - 数据轮询间隔建议 500ms-1000ms
   - 避免频繁 UI 刷新

---

## 参考资源

- [ELM327 命令参考](https://www.elmelectronics.com/wp-content/uploads/2016/07/ELM327DS.pdf)
- [OBD-II PID 列表](https://en.wikipedia.org/wiki/OBD-II_PIDs)
- [flutter_blue_plus 文档](https://pub.dev/packages/flutter_blue_plus)
- [sensors_plus 文档](https://pub.dev/packages/sensors_plus)