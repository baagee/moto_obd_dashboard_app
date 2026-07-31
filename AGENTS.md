# 项目概述

这是一个 **CYBER-CYCLE OBD Dashboard** - 采用赛博朋克/暗黑风格 UI 的 Flutter 应用，用于显示摩托车 OBD（车载诊断）数据。应用仅在横屏模式下运行，提供沉浸式体验。

## 命令

```bash
# 运行应用（需要连接设备或模拟器）
flutter run

# 构建 debug APK
flutter build apk --debug

# 构建 iOS（需要 macOS）
flutter build ios

# 运行分析/代码检查
flutter analyze

# 运行测试
flutter test

# 清理并重新构建
flutter clean && flutter pub get && flutter build apk --debug
```

## 架构

### 状态管理
- 使用 **Provider**（非 Riverpod 或 Bloc）
- 主要 Provider:
    - `OBDDataProvider` - OBD 数据状态管理
    - `BluetoothProvider` - 蓝牙权限、扫描、连接状态管理（含 OBD 会话管理）
    - `LogProvider` - 业务日志管理
    - `RidingStatsProvider` - 骑行统计（2Hz降频采样、5秒时间窗口、事件检测、GPS轨迹）
    - `RidingRecordProvider` - 骑行记录持久化（SQLite读写、daily_stats聚合）
    - `SettingsProvider` - 全局配置持久化（SharedPreferences）
    - `NavigationProvider` - 页面导航状态

### 项目结构

```
lib/
├── main.dart                        # 应用入口，强制横屏，Provider 配置
├── models/                          # 数据模型（OBDData、RidingEvent、RidingRecord 等）
├── providers/
│   ├── obd_data_provider.dart       # OBD 实时数据（峰值保持、档位计算）
│   ├── bluetooth_provider.dart      # 蓝牙权限、扫描、连接、OBD 会话
│   ├── log_provider.dart            # 业务日志（内存+文件双写）
│   ├── riding_stats_provider.dart   # 骑行统计（采样、事件检测、GPS 轨迹）
│   ├── riding_record_provider.dart  # 骑行记录持久化（SQLite + daily_stats）
│   ├── settings_provider.dart       # 全局配置（SharedPreferences）
│   ├── navigation_provider.dart     # 页面导航状态
│   └── loggable.dart                # 日志回调工厂函数
├── services/
│   ├── bluetooth_service.dart       # 蓝牙权限检测、设置跳转
│   ├── obd_service.dart             # OBD 协议解析、分级轮询
│   ├── database_service.dart        # SQLite 单例（riding_records / waypoints）
│   ├── location_service.dart        # GPS 定位、权限管理
│   ├── geocoding_service.dart       # 逆地理编码（高德 API，WGS-84→GCJ-02）
│   ├── audio_service.dart           # 语音提示播放
│   ├── brightness_service.dart      # 屏幕最低亮度保障
│   ├── log_service.dart             # 日志文件写入和分享
│   └── device_storage_service.dart  # 上次连接设备持久化
├── screens/
│   ├── main_container.dart          # 主容器（PageView + 顶部导航）
│   ├── dashboard_screen.dart        # 主仪表盘
│   ├── record_screen.dart           # 骑行记录列表
│   ├── riding_track_screen.dart     # 骑行轨迹详情
│   ├── logs_screen.dart             # 诊断日志
│   ├── settings_screen.dart         # 设置页面
│   └── bluetooth_scan_screen.dart   # 蓝牙设备扫描
├── utils/
│   ├── gear_util.dart               # 档位计算（GSX8SCalculator + 自适应学习）
│   └── riding_score_calculator.dart # 骑行评分
├── theme/                           # 颜色常量、TextStyles、字体（Orbitron / RobotoMono）
├── constants/
│   └── bluetooth_constants.dart     # 蓝牙相关常量
└── widgets/                         # 所有 UI 组件（仪表、图表、弹窗、按钮等）
```

---

## 代码规范（必须遵守）

### 1. 模型规范 (models/)

#### 数据类风格
- 使用 Dart 类声明，**不使用 `data class` 或 `record`**
- 所有字段使用 `final` 声明，确保不可变性
- 字段使用中文注释说明含义

```dart
class OBDData {
  final int rpm;
  final int speed;
  final int throttle; // 油门开度
  final int load;     // 发动机负载
}
```

#### copyWith 方法
- **必须手动实现** `copyWith` 方法（不使用 freezed 等代码生成工具）
- 参数全部可选，使用 `类型?` 命名参数
- 返回新实例，内部使用 `??` 运算符保持原值

```dart
OBDData copyWith({
  int? rpm,
  int? speed,
  int? throttle,
}) {
  return OBDData(
    rpm: rpm ?? this.rpm,
    speed: speed ?? this.speed,
    throttle: throttle ?? this.throttle,
  );
}
```

#### 枚举定义
- 枚举成员使用 **camelCase 命名风格**（项目实际惯例）
- 枚举放在模型文件末尾或单独文件

```dart
enum RidingEventType {
  performanceBurst,   // 急加速
  efficientCruising,  // 高效巡航
  extremeLean,       // 极端倾角
  gearShiftUp,       // 换挡
}
```

---

### 2. 服务层规范 (services/)

#### 构造函数参数设计
- 使用命名参数 + `required` 关键字进行依赖注入
- 回调函数使用可选参数 `void Function(...)?`

```dart
class OBDService {
  final OBDDataProvider _obdDataProvider;
  void Function(String source, LogType type, String message)? logCallback;

  OBDService({
    required OBDDataProvider obdDataProvider,
    this.logCallback,
  })  : _obdDataProvider = obdDataProvider;
}
```

#### 常量定义
- 服务内部使用的常量使用 `static const` 或 `static final`
- 分级轮询使用常量列表定义 PID

```dart
static const List<String> highFreqPids = ['010D', '010C'];
static const List<String> mediumFreqPids = ['0111', '010F', '010B'];
```

---

### 3. 常量管理 (constants/)

#### 常量类规范
- 使用私有构造 `ClassName._()` 防止实例化
- 使用 `static const` 定义常量值
- 添加详细文档注释说明用途

```dart
class BluetoothConstants {
  BluetoothConstants._();

  /// 蓝牙设备扫描超时时间
  static const Duration scanTimeout = Duration(seconds: 4);

  /// 最大重连次数
  static const int maxReconnectAttempts = 2;
}
```

---

### 4. Provider 规范 (providers/)

#### Provider 结构
- 继承 `ChangeNotifier`
- 私有字段以下划线 `_` 开头
- 使用 getter 暴露状态（不使用直接字段访问）

```dart
class BluetoothProvider extends ChangeNotifier {
  app_bluetooth.BluetoothPermissionStatus _permissionStatus = ...;
  bool _isBluetoothOn = false;

  // Getter - 暴露状态
  app_bluetooth.BluetoothPermissionStatus get permissionStatus => _permissionStatus;
  bool get isBluetoothOn => _isBluetoothOn;
}
```

#### 依赖注入
- 构造函数接收依赖（如 `OBDDataProvider`, `LogProvider`）
- 使用 `late final` 或工厂函数初始化回调

```dart
BluetoothProvider({
  required OBDDataProvider obdDataProvider,
  required LogProvider logProvider,
})  : _obdDataProvider = obdDataProvider {
  // 使用 createLogger 工厂函数初始化日志回调
  _logCallback = createLogger(logProvider);
}
```

#### 初始化方法
- 提供 `initialize()` 方法进行异步初始化
- 在方法内部处理状态检测、订阅设置
- 初始化前检查是否已初始化（避免重复初始化）

```dart
Future<void> initialize() async {
  if (_isInitialized) return;
  // ... 初始化逻辑
}
```

#### 日志回调
- 使用 `createLogger(logProvider)` 工厂函数创建日志回调
- 不要直接赋值 lambda 表达式

```dart
// 正确
_logCallback = createLogger(logProvider);

// 错误 - 不要这样做
_logCallback = (source, type, message) => logProvider.addLog(source, type, message);
```

---

### 5. Widget 组件规范 (widgets/)

#### 命名约定
- 类名使用 PascalCase（如 `CyberButton`, `SpeedGaugeCard`）
- 文件名使用小写下划线（如 `cyber_button.dart`）

#### 参数设计
- 必选参数使用 `required` 关键字
- 可选参数提供默认值
- 支持命名构造函数实现工厂方法

```dart
class CyberButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CyberButtonType type;
  final double? width;

  const CyberButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = CyberButtonType.primary,
    this.width,
  });

  // 命名工厂构造函数
  const CyberButton.primary({
    super.key,
    required this.text,
    this.onPressed,
  }) : type = CyberButtonType.primary;
}
```

#### 组件类型选择
- 优先使用 `StatelessWidget` + `Consumer` 模式
- **禁止**在 `build()` 方法中构建复杂 widgets
- 所有自定义组件使用 `const` 构造函数

```dart
// 正确 - 分离复杂布局
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildHeader() => ...;  // 分离为独立方法
  Widget _buildContent() => ...;
}
```

---

### 6. Theme 样式规范 (theme/)

#### 颜色常量
- 使用 `static const Color` 定义颜色值
- **必须**预定义透明度变体（避免重复 `withOpacity` 调用）

```dart
static const Color primary = Color(0xFF0DA6F2);
static const Color primary60 = Color(0x990DA6F2); // 0.6 opacity
static const Color primary30 = Color(0x4D0DA6F2); // 0.3 opacity
static const Color primary20 = Color(0x330DA6F2); // 0.2 opacity
```

#### 仪表盘语义色
- 仪表数据相关颜色（进度/指针/刻度/中心值）**必须**使用语义色，不直接使用 accent 色：
    - `gaugeNormal` 霓虹青 - 正常区（RPM/速度共用）
    - `gaugeWarn` 琥珀 - 警告区
    - `gaugeDanger` 红 - 危险区
- `primary` 蓝仅用于 UI 框架层（导航、边框、按钮、背景纹理）

#### 字体规范
- 拉丁字母/数字使用 `AppFonts`（`lib/theme/app_fonts.dart`）：
    - `AppFonts.displayStyle()` Orbitron - 仪表大数字/标题
    - `AppFonts.monoStyle()` Roboto Mono - 刻度数字/数据值（等宽防跳字）
- 中文标签不指定 fontFamily，走 Space Grotesk/系统回退链
- 字体文件打包在 `assets/fonts/`（pubspec 已注册），不使用 google_fonts 运行时下载

#### TextStyle 规范
- 使用 `static const TextStyle` 预定义样式
- 使用命名风格：`labelSmall`, `valueMedium`, `headingLarge` 等

#### 装饰器工厂方法
- 提供 `surfaceBorder()`, `glowShadow()` 等工厂方法
- 支持可选参数配置

---

## 重要规范

### 日志系统
- 使用 `LogProvider` 统一管理业务日志
- 每次 `addLog()` 会同时写入内存和实时写入文件
- 日志文件路径：`{app_documents}/obd_logs.txt`
- 分享日志直接分享已存在的文件
- 日志回调使用 `createLogger(logProvider)` 创建

### 按钮组件
- 所有按钮使用 `CyberButton` 组件（赛博朋克风格）
- 支持 4 种类型：primary、secondary、danger、success

### 蓝牙模块
- 权限检测在应用启动时执行
- 蓝牙状态通过 `BluetoothProvider` 管理
- 关键方法：
    - `initialize()` - 初始化并检测蓝牙状态，自动重连上次设备
    - `startScan()` - 扫描蓝牙设备（超时时长由 SettingsProvider.scanTimeoutSeconds 配置，默认 3s）
    - `connectToDevice()` - 连接设备并启动 OBD 会话
    - `requestPermission()` - 请求蓝牙权限
    - `openSettings()` - 打开系统设置
- 设备优先级：OBD > ELM > 诊断工具 > 其他

## 重要说明

- 项目中使用中文和用户交流
- 每次做完大的功能改动/重构，**必须**更新此文档
- 应用强制横屏方向并隐藏系统 UI 以获得沉浸式体验
- 新增 Provider、Service、Model 必须遵循上述代码规范
- 代码提交前必须运行 `flutter analyze` 确保无 error
- 本文档由代码探索生成，如发现文档与实际实现不一致，请更新本文档