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

# 导航算法回归对拍（路线指纹 + 动作队列 + 跳点风险，退出码非 0 即基线被破坏）
dart run tool/verify_navi.dart
dart run tool/verify_navi.dart --project <lon> <lat>   # 投影对拍

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
    - `NaviProvider` - 导航 HUD（高德分享路线解析、动作队列、通栏展开状态机）

### 项目结构

```
lib/
├── main.dart                        # 应用入口，强制横屏，Provider 配置
├── data/
│   └── amap/                        # 高德分享路线数据层（零 Flutter 依赖，可 dart run 对拍）
│       ├── models.dart              # 接口模型 + 容错 JSON 转换（restoration / info）
│       ├── route_analyzer.dart      # 累计里程 / 投影 / 动作队列 / 剩余量 / 底图切片 / 朝向
│       └── share_client.dart        # 短链解析 + 端点 A/B（端点可注入，便于测试）
├── debug/                           # 仅 debug 构建可见的抓包/验证页
├── models/                          # 数据模型（OBDData、RidingEvent、RidingRecord 等）
├── providers/
│   ├── obd_data_provider.dart       # OBD 实时数据（峰值保持、档位计算）
│   ├── bluetooth_provider.dart      # 蓝牙权限、扫描、连接、OBD 会话
│   ├── log_provider.dart            # 业务日志（内存+文件双写）
│   ├── riding_stats_provider.dart   # 骑行统计（采样、事件检测、GPS 轨迹）
│   ├── riding_record_provider.dart  # 骑行记录持久化（SQLite + daily_stats）
│   ├── navi_provider.dart           # 导航 HUD（状态机、GPS 订阅、路线轮询、通栏）
│   ├── settings_provider.dart       # 全局配置（SharedPreferences）
│   ├── navigation_provider.dart     # 页面导航状态
│   └── loggable.dart                # 日志回调工厂函数
├── services/
│   ├── bluetooth_service.dart       # 蓝牙权限检测、设置跳转
│   ├── obd_service.dart             # OBD 协议解析、分级轮询
│   ├── database_service.dart        # SQLite 单例（riding_records / waypoints）
│   ├── location_service.dart        # GPS 定位、权限管理
│   ├── geocoding_service.dart       # 逆地理编码（高德 API，WGS-84→GCJ-02）
│   ├── clipboard_share_watcher.dart # 剪贴板分享短链识别 + 生命周期钩子
│   ├── audio_service.dart           # 语音提示播放
│   ├── brightness_service.dart      # 屏幕最低亮度保障
│   ├── log_service.dart             # 日志文件写入和分享
│   └── device_storage_service.dart  # 上次连接设备持久化
├── screens/
│   ├── main_container.dart          # 主容器（PageView + 顶部导航 + 剪贴板watcher）
│   ├── dashboard_screen.dart        # 主仪表盘（顶部通栏悬浮覆盖 + 三栏）
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
    ├── vehicle_health_card.dart      # 右上横向车辆健康卡：冷却水温 / 进气温度 / 电压（负温、低频 PID 有效性）
    ├── telemetry_chart_card.dart     # 实时趋势组件保留，但不再挂载在驾驶仪表盘（骑行记录未存 RPM 序列）
    ├── track_radar_panel.dart       # 右下角面板：档位 + 轨迹雷达/导航卡切换
    ├── navi_card.dart               # 导航卡 v2：真实路线底图（航向朝上）+ 独立动作条 + 四列指标条
    ├── navi_hud_banner.dart         # 临近路口通栏（多动作序列 + 呼吸 + 侧光）
    └── navi_turn_arrow.dart         # 转向箭头自绘（main_action → 形状/标签）

tool/
└── verify_navi.dart                 # 导航算法离线对拍/回归工具（基线失败退出码 1）

test/
├── fixtures/amap/
│   └── sample-restoration.json      # 真实响应离线样本（随仓库分发，verify_navi 与真实样本断言共用）
└── ...

docs/
└── amap-share-api-reference.md      # 高德分享接口/驾车动作码的**唯一权威**（§2.11 动作表）
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

### 导航 HUD（高德分享路线）· Phase 4

数据链路：

```
剪贴板短链 → param → POST /ws/share/lbs/route/restoration（每 30s）
   → RouteAnalyzer（累计里程 + 投影 + 动作队列）
本机 GPS(WGS-84) → GeocodingService.wgs84ToGcj02() → analyzer.project()
   → 动作队列（导航卡与通栏的唯一数据源）

分享状态心跳（每 15s）→ POST /ws/share/lbs/info（shareInfo.shareStatus）
                      →（给不出结论时）GET /ws/user/route/share/info（data.status）
   → 判到"已停止 / 已结束 / 已过期" → _endSession()（静默收尾回 off，无终态卡）
```

**位置**用本机 GPS、**不用** info 接口的位置字段（本机 GPS 就是分享者位置，更准、
无上报延迟）；但**"导航是否已停止"只有 info 接口知道**（本机 GPS 永远不知道），
所以状态心跳必须走它。两件事互不冲突。

关键文件与职责：

| 文件 | 职责 |
|---|---|
| `lib/data/amap/*` | 纯 Dart 数据层，**与 JS 参考实现对拍一致，只做加法不改既有逻辑**；`share_client.dart` 另提供**分享状态**探测（行中 POST `share/lbs/info` 的 `shareInfo.shareStatus`、行前 GET `user/route/share/info` 的 `status`） |
| `lib/providers/navi_provider.dart` | 状态机（`off/locating/navigating/deviated/stale`）、路线轮询（带指纹脏检查）、GPS 订阅（含权限自检 / 即时定位 / 等不到定位的超时诊断）、**5Hz 里程平滑（推算-校正）**、**分享状态心跳（跟随高德停止，静默收尾）**、通栏展开状态、限速联动 |
| `lib/data/amap/share_client.dart` | 短链解析 + 路线/状态端点（端点可注入，便于测试）；状态探测业务失败**不抛异常**（`code` 本身就是判据） |
| `lib/services/clipboard_share_watcher.dart` | 回前台读剪贴板短链 → 自动同步（同一条短链只触发一次）；受 `naviAutoSync` 控制 |
| `lib/widgets/navi_card.dart` | 右下角导航卡 v2（活跃态：E1 定位中 / E2 偏离 / stale），`off` 时渲染空 —— **没有"导航已结束"终态卡**，分享失效与"高德那边停了"都静默收尾回默认面板 |
| `lib/widgets/navi_hud_banner.dart` | 临近路口通栏，**展开条件绑定队列而非单个动作**（连续转弯不抖动） |
| `lib/widgets/navi_turn_arrow.dart` | `main_action` **官方枚举 §2.11** → 转向形状与标签（映射表与反退回约束见下；未知码退化为通用箭头，不显示"未知动作(N)"） |

数据层为导航卡底图新增的 API（仅加法，`lib/data/amap/route_analyzer.dart`）：

| API | 用途 |
|---|---|
| `bearingAt(double distance)` | 路线切线朝向（弧度，0=北、顺时针为正），用于"航向朝上"旋转；用切线而非 GPS heading，避免低速（<5 km/h）时朝向冻结 |
| `routeSlice({vehicleDistance, behindMeters, aheadMeters, maxPoints})` | 只截取车辆前后一段里程的 `RouteSlice`（车辆点按里程精确插入；用 `coordCovered` 排除不被 link 引用的孤点） |
| `RouteSlice` | 切片点集 + `vehicleIndex` / `bearing` / `trafficStates` / `fromDistance` / `toDistance` |
| `RouteMarker` / `RouteMarkerKind` | 底图上的红绿灯（`trafficLight`）与限速点（`speedLimit`）标记 |

必须守住的三条不变量：

1. **通栏展开由队列驱动**：存在 `eta < 8s` 的动作即展开，仍有动作在窗口内则保持展开。
   用剩余时间（`distance / max(speedMs, 2)`）而非固定距离，且速度优先取 OBD 车速。
2. **投影前必须做 WGS-84 → GCJ-02 转换**，否则有 100~600m 系统性偏移。
3. **GPS 投影必须带里程先验（连续性约束）**：`NaviProvider` 调
   `analyzer.project(lon, lat, nearDistance: 上次里程 + 车速×Δt)`。
   高德路线常在空间上贴回自己（立交上下匝道 / 主辅路），实测样本里
   **d=6600m 与 d=7480m 只相距 17.5m**；纯"最近边"投影在 9m 级定位误差下就会把
   里程吸到 880m 之后，"下一个动作"随之跳过后面的转弯（实测 d=220↔400 相距 18.2m，
   中间正好隔着 2 个动作）。首次定位 / 定位空档 >60s 时才允许退回全局最近。
   改动此处必须过 `test/data/amap/route_analyzer_test.dart` 的
   「投影歧义 / 连续性约束」组与 `navi_provider_test.dart` 的「投影连续性」组。

导航卡 v2 的三条设计约束（`lib/widgets/navi_card.dart`，改动后必须过
`test/widgets/navi_hud_widgets_test.dart` 的布局断言）：

1. **底图是主体，转向动作不覆盖在地图上**：真实路线用 `gaugeNormal` 实色（3px，带辉光）
   绘制，转向箭头降为地图**下方**独立动作条里的小元素（≈42px），二者不共用同一块矩形。
   高度预算：底图占卡片高度**一半以上**（244px 槽位下 ≈129px）。空间不够时**优先压留白
   （`_gap`）与指标条，不要压底图**。
2. **航向朝上 + fit-to-viewport**：底图按 `routeSlice.bearing` 绕车辆点旋转，再按
   **旋转后包围盒** fit 到画布（四周仅留 8px；`_minVisibleMeters = 80` 兜底，防止极短弯被
   无限放大）；因此车标位置随路线弯曲而变，**不是**固定的 72% 高度锚点。视窗只截取
   "车后 40m + 车前 `naviMapAheadMeters`"，避免把整条路线压成一团；带 8m / ~6° 死区，
   防止底图逐帧抖动。
3. **底部指标不拼接**：剩余里程 / 剩余时间 / 红绿灯 / 总里程 四列**等分（flex
   11:11:8:11）独立渲染**，数值用 `FittedBox(scaleDown)` 兜底，**禁止**再退化成单行
   字符串拼接（会被 ellipsize 截断）。限速牌属于通栏，不在本指标条内。

> 底图与标题行已从 `NaviCard.build` 拆成 `_NaviMap` / `_NaviTitleRow` 两个
> **const + 自 `context.select`** 的子组件：里程平滑 5Hz 通知下，外层每帧重跑只花几何
> 布局，地图（CustomPaint 的路径 / 包围盒 / 标记）只在切片或标记真的变化时才重建。
> 改这两块时保持"const + 自己 select"，别退回成外层 inline。

转向箭头的头部几何（`lib/widgets/navi_turn_arrow.dart`）：三角头由 `_headGeometry()`
统一给出（`len = min(2.8×线宽, 末段 ×0.7)`、`half = len×0.44`，顶角 ≈47°），
**线茎必须在三角头底边处收笔**（`tip - unit × head.len`）——线茎若一路描到 `tip`，
三角头在距尖端 1×头长内的半宽小于线茎半宽，上半段会被整块盖住，顶部于是呈现
"等宽平头矩形 + 两侧斜肩"，完全读不出三角形。`glow` 的模糊只是让这个缺陷更显眼，
不是根因。该不变量由 `test/widgets/navi_turn_arrow_paint_test.dart` 直接读像素守住
（断言"极点极窄、往里迅速变宽"，覆盖直行/未知/斜向/调头/左转/左后方；
调头用例需限定左半区扫描，因为右侧长竖杆会拉低 ink 包围盒）。

**动作码映射必须用官方枚举，禁止几何猜测**（`lib/data/amap/models.dart` 的 `ActionCodes`
与 `lib/widgets/navi_turn_arrow.dart` 的 `naviTurnTypeOf`）：唯一权威是
`docs/amap-share-api-reference.md` §2.11「驾车动作列表」（14 项 0~13）。

| 码 | 含义 | 码 | 含义 |
|---|---|---|---|
| 0 | 无基本导航动作（终点段 → 到达；路段中 → 直行且不显示动作名） | 7 | 左转调头 |
| 1 | 左转 | 8 | 直行 |
| 2 | 右转 | 9 | 靠左 |
| 3 | 向左前方行驶 | 10 | 靠右 |
| 4 | 向右前方行驶 | 11 | 进入环岛 |
| 5 | 向左后方行驶 | 12 | 离开环岛 |
| 6 | 向右后方行驶 | 13 | 减速行驶 |

> ⚠️ 本工程早期版本按几何反推，把 `3` 当直行、`5` 当左前方、`7` 当左后方、`9` 当左转、
> `10` 当直行、`11` 当调头 —— 那版**已被官方枚举推翻**，真机表现就是"高德说向左前方/靠左，
> 本 app 画成直行或硬拐弯"。改动映射必须过
> `test/widgets/navi_turn_arrow_mapping_test.dart`（逐条对拍 + 反退回断言）与
> `route_analyzer_test.dart` 的真实样本断言（17594 左转 / 17625 靠左 / 17676 向右前方行驶）。

设置项（`SettingsProvider`，除 `naviRouteTrafficColor` 外均属 `api` 分组可重置）：
`naviAutoSync`（默认 true）、`naviRouteRefreshSec`（默认 30，钳制 10~120）、
`naviMapAheadMeters`（默认 300，钳制 100~2000）、`naviEtaMode`（`clock`/`duration`，
默认 clock）、`naviRouteTrafficColor`（默认 false）、
`naviShareStatusWatchOn`（默认 true）、`naviShareStatusWatchSec`（默认 15，钳制 5~60）、
`naviStopOnShareEnd`（默认 true）。设置页入口在「第三方服务 → 导航 HUD」，
并提供手动粘贴短链的永久兜底入口（偏离且重规划失败时整卡可点亦复用同一个弹窗）。
数值项的边界在 **getter 与 setter 两处共用同一组常量**（`SettingsProvider` 的
`naviRouteRefreshMinSec` / `naviMapAheadMinMeters` / `naviStatusWatchMinSec` 等），
避免"读时钳、写时不钳"把越界值持久化。`NaviProvider.updateSettings` 由
`main.dart` 的 `ChangeNotifierProxyProvider3` 在 **build 期**调用，因此**不得同步
`notifyListeners()`**：它在视窗里程/路况色/时间制式变化时重算底图切片（否则静止时
改设置底图不刷新），并经 `_notifySoon()` 用微任务补发一次通知（合并同帧多次调用）。

> **必须跟随高德停止（分享状态心跳）**：本机 GPS 只知道"我在哪"，**永远不知道
> 分享者（你自己）在高德里停止了导航** —— 旧版因此会把里程一直投影到那条**已冻结**
> 的旧路线上，拐进别的路甚至回到家，卡片还在报"前方 X 米转弯"。
> 现在每 `naviShareStatusWatchSec`（默认 15s）探测一次，判据是**两个端点、两个
> 不同字段**（见 `amap-user-route-share-info.md` §5.1，两套取值域**不得互套**）：
>
> | 端点 | 方法 | 字段 | 表示结束的值 |
> |---|---|---|---|
> | `/ws/share/lbs/info`（行中，**主判据**） | POST | `data.shareInfo.shareStatus` | `5` / `7`（已停止）、`6`（已结束） |
> | `/ws/user/route/share/info`（行前，复核） | GET | `data.status` | `2` / `3`；顶层 `code = 10001`（已过期） |
>
> 六条不可退让的规则（改动 `_applyStatusVerdict` / `_onStatusProbe` / `_startStatusWatch`
> 必须过 `test/providers/navi_provider_test.dart` 的「分享状态心跳」组）：
> 1. **连续 2 次同向确认才收尾**（`statusConfirmCount`）：状态文档实测过"同一 param
>    落到不同后端节点快照不一致"（差 46 小时），单次判据不足以证明此刻真停了 ——
>    而**误停导航不可恢复**（分享链接是快照，只能重贴）。
> 2. **`unknown` 一律清零计数、什么都不做**：取值不认识 / 字段缺失 / `code = 2/3`
>    （参数问题）都不等于"已结束"。**探测失败（网络异常）也不改状态**。
> 3. `status == 4` 不是结束，是"该改用行中端点"。
> 4. **首次判到停止后，用远短于心跳的间隔复核一次**（`shareEndConfirmDelaySec`，默认 3s，
>    可注入 `confirmProbePeriod`）：第二次确认**不再等满一个心跳周期**，否则前台中途收尾
>    要拖到 15~30s。`_probeInFlight` 是这条的**必要护栏** —— 复核定时器与周期心跳可能
>    同时触发，两次并行返回会把"同一时间点的一次信息"误算成两次独立确认，正好绕过
>    `statusConfirmCount`（所以 `_statusProbeCount++` 必须在互斥**之后**）。
> 5. **`_onStatusProbe` 的 `await` 之后必须校验 `_param` 未变**：`stop()` 不中止 in-flight
>    探测，而重贴短链会立刻拉起新会话 —— 旧 param 的迟到 verdict 会落在新会话上
>    （`strikes=1` 外加一个复核定时器）。同理 `_scheduleConfirmProbe` 必须判 `_suspended`
>    （后台不排复核），`_cancelConfirmProbe` 必须进 `_stopRuntime()` 与 `_suspend()`。
> 6. **`updateSettings` 的心跳重建守卫不得以 `_statusTimer != null` 为条件**：关闭分支会
>    把 `_statusTimer` 置 null，于是"骑行中途关掉再打开"永远重建不起心跳。改用 `wasOn`
>    （更新前的 `_statusWatchOn`）判断，且"关→开"要像 `_resume()` 一样 `probeNow: true`
>    立即补探一次。
>
> `_startStatusWatch(probeNow: true)` 只在**两处**用：`_resume()`（后台期间一次都不探，
> 回前台必须立刻补一次，否则又要从 0 等一个完整周期 ← A 的唯一有效场景）与
> `updateSettings()` 的"关→开"（同理，从盲到明）。**启动（`start()`）传 `false`**：
> 行前自检刚探过，再探是浪费。
>
> **收尾一律静默，没有"导航已结束"卡片**（`_endSession()`）：分享失效 / 该分享已过期 /
> 高德那边停止了导航，三者都全量清零回 `NaviState.off` ⇒ `hasSession == false`
> ⇒ 第三列**直接恢复默认的轨迹雷达卡**，只留一条日志（原因留在 `errorMessage`
> 供粘贴弹窗弹 toast）。**不要**再引入 `expired`/`finished` 这类终态 —— 用户明确
> 要求"导航已结束这种情况直接恢复原来的样子"。
> 关掉 `naviStopOnShareEnd` 则**不收尾**：只把 `shareStoppedHint` 置上（活跃卡标"已停止"）
> 并继续导航（想按这条路骑完的场景）。
>
> **行前自检（刚粘贴就先问一句）**：`start()` 解析出 `param` 后、拉路线**之前**，
> 先用同一套两步求证问"这条分享还在导航吗"（`_shareAlreadyEndedAtStart`）。
> 已结束 ⇒ **直接不建立会话**（状态停在 `off`、不拉路线、`hasSession == false`），
> 卡片**根本不被拉起**，用户留在默认的轨迹雷达面板 —— 而不是先闪一张卡再收掉。
> `start()` 的首个 `notifyListeners()` 因此**推迟到自检之后**：连 `locating` 都不闪一下
> （否则 `hasSession` 会短暂为 true，面板先切到导航卡再切回来）。
> 与心跳共用同一把尺：`statusConfirmCount` 次同向确认、`unknown`/网络失败一律
> fail-open（探不到就照常启动）。两个开关同样管辖：`naviShareStatusWatchOn` 是总闸，
> `naviStopOnShareEnd=false` 时照常启动、只把 `shareStoppedHint` 置上。
> 被拦下时 `lastStartEndedShare == true`，粘贴弹窗据此给 **warning**（不是 error，
> 也不用"解析失败"的措辞）。改动此处必须过 `navi_provider_test.dart` 的「行前自检」组
> 与 `navi_hud_widgets_test.dart` 的三条「静默收尾 / 卡片根本不被拉起」用例
> （E3 分享失效、E4 高德那边停止、粘贴时已结束）。
>
> 真机取证：验证页（设置 → 高级设置 → 高德分享路线解析验证）新增
> **「分享状态探测」** 按钮，两个端点各打一次并把**原始响应逐字**写进日志 ——
> 行前端点至今没有成功样本（状态文档 §8 的空白），跑一次即可回填文档。

回归门禁（改动 `lib/data/amap/` 或 `NaviProvider` 后必须全绿）：

```bash
dart run tool/verify_navi.dart   # 离线样本对拍：distance=27734 links=335 coords=526 segments=21 actions=21
flutter test                     # 含 test/data/amap/、test/providers/navi_provider_test.dart
                                 #   （「分享状态心跳」组覆盖 A/B/P0 五条护栏）、
                                 #   test/widgets/navi_hud_widgets_test.dart、
                                 #   test/widgets/navi_turn_arrow_paint_test.dart 等
```

实测基线（`test/fixtures/amap/sample-restoration.json`，**随仓库分发**，
`tool/verify_navi.dart` 与 `test/data/amap/` 的真实样本断言共用它；**不依赖**
`amap_test01/`（那是被 .gitignore 忽略的 JS 参考实现/抓包工作区））：连续多动作 17594/17625/17676m，在 d=17560m、80km/h 下
ETA 为 1.5 / 2.9 / 5.2 秒——三个动作同时落在 8 秒通栏窗口内。

> **`locating` 必须有话可说**：权限被拒 / 系统定位未开 / 等不到定位 / 定位流出错，
> 四种情况都曾表现为同一句"定位中…"。现在统一经 `NaviGpsIssue` 建模，
> 卡片按原因给实话（缺权限/服务未开时整卡可点直达系统设置），12s 无定位转
> `noFixYet`。会话开始还要先取一次**即时定位**（`distanceFilter: 3` 落到 Android 就是
> `smallestDisplacement`，静止时可能长时间不回调）。
>
> **测试硬性要求**：在测试里构造 `NaviProvider` 必须注入
> `locationGate: () async => LocationPermissionStatus.granted` 和
> `firstFixProvider: () async => null` —— 测试环境没有平台插件，
> `isLocationServiceEnabled()` 返回 false，会被判成"系统定位未开启"并把
> 注入的定位流一起切断（曾导致 19 个用例失败）。

> **偏离态（`deviated`）不是"能重新规划"**：高德分享链接返回的是**分享时刻的快照**，
> 重新拉取只会拿到同一条路线。所以偏离后重拉若指纹未变（`replanFailed`），界面
> **必须**把"重新规划中…"换成实话（「已偏离 540m · 点此重新粘贴短链」+ 整卡可点），
> 重拉节流也从 10s 退到 60s。只有 `offset ≤ 100m` 回到路线才恢复 `navigating`。
> 若真机长期停在偏离态，优先用验证页的「坐标系自检」判断是不是双转换造成的
> ~540m 系统偏移（见 `docs/phase4-navi-hud-plan.md` §10.5/§10.6）。

> **定位采样频率必须显式下传（否则 Android 是 5 秒一帧）**：geolocator 11.x 的
> `LocationSettings` **没有 `intervalDuration`** 字段（`toJson()` 只带
> `accuracy`/`distanceFilter`），Android 端 `LocationOptions.parseArguments`
> 取不到 `timeInterval` 就回退到 **5000ms**，插件再写成
> `setIntervalMillis(5000)` + `setMinUpdateIntervalMillis(5000)`。
> `distanceFilter` 只是 `smallestDisplacement`（最小位移），**只会让回调变少、
> 不会变快** —— 所以"把 distanceFilter 调到 3m"并不能提高频率。
> 60km/h 下 5 秒 = 83 米，实测表现就是**拐过弯了导航卡/通栏还在提示"前方右转"**。
> 现在 `LocationService.getPositionStream` 在 Android 上改用
> `AndroidSettings(intervalDuration: androidFixInterval /* 1s */)`
> （geolocator 已 re-export `AndroidSettings`，无需新增依赖），
> `distanceFilter: 3m` 继续负责拐弯/变道的灵敏度。
> 真机自检看日志里的 **「定位健康度：采样间隔均值 xxx ms / 定位龄期均值 yyy ms」**
> （`NaviProvider.gpsFixIntervalMs` / `gpsFixAgeMs`，累计 5 帧后记一条）——
> 采样间隔期望 ≈1000ms、龄期期望 <500ms，两项都是"为什么看起来有延迟"的直接答案。

> **里程按当前车速平滑推进（推算-校正）**：1Hz 的定位即使修好了，两次定位之间画面
> 仍是"每秒跳 17~33 米"。所以 `NaviProvider` 用 **5Hz 心跳（`smoothTickMs = 200`）
> 按当前车速前推里程**，下一帧实测定位再整体**校正**（误差不累积，且只在一个采样
> 周期内）。心率调频注意 `gpsStaleSeconds = 5` 现在**只控制"推算中"标签**，
> 不再是"是否外推"的开关；同一套心跳在长时间无定位时自然退化为隧道航位推算。
>
> **定位龄期也要补**（不只是采样间隔）：`pos.timestamp` 是**采集时刻**
> （Android = `Location.getTime()`、iOS = `CLLocation.timestamp`，iOS 插件自己也用
> 它算位置有多旧），从"收到时刻"起算就会**一直落后一个龄期** —— 100km/h 下
> 300ms = 8 米、1s = 28 米，这是"进弯了还差几十米"的另一半来源。
> `_compensateFixAge` 在每帧校正之后按 `(now − timestamp) × 车速` 再补一次前推；
> **只用 [0, `maxFixAgeSec`=2.5s] 内的龄期**，超出（时钟偏移/单位错/批处理积压）
> 一律放弃补偿 —— 宁可慢一点，也不能凭空把用户推到弯道之后。
>
> 两条推算路径（心跳平滑、龄期补偿）都走 `_advanceProjection()`，护栏只在这一处：
> 静止不推 / 偏离态不推 / 推算值不参与偏离判定（`measured: false`）。
>
> 另一处相关不变量：`_continuityPrior` 的基准是 **`_measuredDistance`（实测里程）**
> 而不是 `_projection.distance`（含外推量）—— 后者会把"车速 × 定位间隔"算两遍，
> 先验偏前一帧车程，隧道恢复时窗口甚至会把真实位置排除在外。
>
> **测试硬性要求（补充）**：布局/金样本类用例必须注入
> `smoothTickPeriod: const Duration(hours: 1)` 冻结平滑 —— 平滑推进让"剩余 100 米"
> 在 `pump(350ms)` 后变成 96 米，且依赖真实墙钟，会让断言飘。平滑行为本身由
> `navi_provider_test.dart` 的「里程平滑」组用 20ms 心跳覆盖。

## 仪表盘车辆健康卡（实时信息布局）

赛博朋克仪表盘右上角由 `VehicleHealthCard` 代替转速/速度趋势图；右栏仍维持上方 1/3、下方 2/3（轨迹雷达 / 导航卡）。卡片为横向一主两辅：冷却水温、进气温度、控制模块电压。左栏移除重复电压，中央 `CombinedGaugeCard` 和启动自检移除重复的双温度梯形，保留 RPM/速度主仪表。

- OBD PID `0105`、`010F` 按 `A - 40` 解码，合法值包含 `-20°C` 与 `0°C`。**不能按 `≤0` 判无数据。**冷却水温及进气温度明确显示 `°C`，电压显示 `V`；低温状态显示 `COLD`，非 `NO DATA`。`coolantTemperatureRatio()` 仍提供 `-40～120°C` 位置换算，但当前页面不画温区带。
- `OBDDataProvider` 分别跟踪 `hasCoolantTemp` / `hasIntakeTemp` / `hasVoltage`，仅收到本次连接相应 PID 后才显示其读数；断开重置有效性，避免初连时默认零值被误认为真实 `0°C`。电压 `≤0V` 显示缺数。冷却水温仅在本次连接内保留最近 16 次 `0105` 样本用于微趋势（不持久化，断开即清空）。
- 右上卡通过 `context.select` 只监听两项温度、电压、连接状态、PID 有效性及水温样本。横向三块采用与左侧车辆状态相同的暗底块 / 蓝青指标标签 / 实色强调条；水温在高度允许时画真实样本微趋势（`CoolantTrendPainter`，固定最小 8°C 纵轴跨度），狭窄视口自动隐藏图表、优先保留读数。绘图不使用模糊、阴影或持续动画，也不会被高频 RPM/速度通知带着重绘。温度、电压分级是仪表显示提示，不替代骑行事件中可配置的故障阈值。
- `TelemetryChartCard` 源文件保留但不在驾驶仪表盘挂载。现有骑行记录只持久化摘要/轨迹/事件，**没有 RPM 时序数据**；在扩展采样与存储前不能把实时内存历史当作已保存的骑行趋势。
- 蓝牙 OBD 会话初始化成功时 `BluetoothProvider._updateDeviceConnectedStatus()` 同步 `OBDDataProvider.setDeviceConnected(true)`；断开由 `_cleanupConnection()` 的 `resetData()` 同步清零。仅 BLE 连接而 ELM327 初始化未成功时仍为 `NO DATA`。
- 左侧 `SideStatsPanel` 改为三块纵向实色边线数据仪表：油门开度 / 发动机负载用冷青等宽大数字与有色 `%` 单位、细进度条；进气歧管压力以 `kPa` 明确单位并保留最近 30 次 PID 的紧凑柱图。块面沿用右上卡的 `backgroundDark30`、蓝青指标标签和无模糊边线；负载默认正常青，仅 ≥70% 切换警告琥珀色，避免常态误报。矮屏优先保留读数，隐藏细条/压力图；子组件各自订阅 Provider，`pressureHistoryVersion` 仅在 010B 到达或断开时变化，高频 RPM/油门通知不重绘压力图。回归 `flutter test test/widgets/side_stats_panel_test.dart`。
- 仪表盘 P0/P1 字阶由 `AppTheme.dashboardCardTitle`（14px 框架蓝粗体）、`dashboardMetricLabel`（12px 低饱和蓝青）、`dashboardMetricLabelCompact`（11px）、`dashboardStatus`（10px）、`dashboardNaviTitle`（12px 框架蓝）专用样式统一；普通读数使用 `dashboardValue` 冷青色，警告/危险仍使用 `gaugeWarn`/`gaugeDanger`。不改全局 `textPrimary` 与通用 `labelMediumPrimary`，避免波及设置页；不新增模糊/持续动画。左栏、右上与轨迹雷达标题同级；档位栏与导航卡标题因窄栏／状态空间用紧凑样式。导航卡标题行从 14px 加至 18px，地图仍是主块；底部四列保持独立渲染（flex 11:11:8:11），标签 11px、数值 14px 不随卡高等比例缩小，`FittedBox(scaleDown)` 仅作为极窄宽度兜底。改导航字阶必须继续通过 `navi_hud_widgets_test.dart` 的 244px / 196px 地图高度与无溢出断言。
- 回归：`flutter test test/widgets/vehicle_health_card_test.dart`（负温、已连接但 PID 未到、重连清零、横向压缩、无模糊）及 `flutter test`。
- 中央 `CombinedGaugeCard` 的分层顺序是「中心数值 → **进度环** → 刻度线 → 刻度数字（最外）」；**两根指针与中心金属轮毂已移除**（中心不再被指针穿过、也不再需要"指针尖必须落在环带内侧"那套几何）。中心改成"上行转速 / 下行时速"两行读数，中间由**静态层**画的**分栏短横线**隔开（`GaugeGeometry.dividerHalfWidth = ringInner × 0.22`，主体 2px `primary` 55%，两端各一个 3×7 端帽；它只依赖画布尺寸，所以画在静态层、不跟 RPM/速度的每帧通知重绘；它是分栏线**不是刻度线**——共享的 0 刻度在正左方 9 点）。两行**不等号**：时速字号 = 转速 × 1.2（`centerSpeedFontSize`），扫视先落到时速上。半径的唯一真源是 `GaugeGeometry.of(size)`（同文件内，静态层与动态层都从这里取），**禁止**再各自算 `min(w,h)/2 - 10`。画布＝卡盒：`CombinedGaugeCard` **不再套 8px 内边距**（自检浮层同步去掉那层），因为画布每小一圈，环半径（= 半宽 − 冻结预算）与刻度、数字会**一起**变小——这是"整体显小"的第一杠杆（主仪表盘 341×344 卡盒，画布就是 341×344）。进度环外缘本来就贴着画布边缘，所以"刻度/数字放到环外"必然缩径：实测环半径 ≈ 画布半宽的 68%（341×344 主仪表盘 116.4，改前 160.5，缩 ~28%）。**环半径与刻度数字字号彻底解耦**（`GaugeGeometry.of` 两段式推导）：①环位置只用画布尺寸算（`ringRadius = half − 固定参考外圈预算`），改字号**不会**带动环；②环外：刻度数字锚在**刻度线一侧**（保证有缝）——`labelRadius = tickOuter + labelGap(4) + 0.95×字号`，字号由 `f = (half − outerPad − tickOuter − labelGap) / 1.85` 解出（1.85 = 0.95 墨迹内沿 + 0.9 行框外沿），341×344（＝主仪表盘卡盒）上 **13.3px**、真实字墨空档 4.0px。**关键**：数字行是**轴对齐矩形**，横向 3 字符标签（`12k` / `210`）在 30° 附近最贴近圆心，其径向深度按**实测字墨 ≈0.92×字号**（实现取 0.95）——**不要按半行高 0.6×字号留缝**，否则宽标签的行内角会扎进刻度线（真机"位数多了就重叠"的根因，那版实测重叠 −1.8px）。改字号只影响环外的刻度线与数字，环一动不动；想再放大就从刻度线里挪（`tickMajorLen` clamp 上界 6→4 可 +1.5px）或加 `labelGap`；**不要**动环半径去换（这条由几何测试的"环位置只由画布尺寸决定"用例守着）。配套四条：①中心大数字按 **`ringInner × 0.34`** 定标（不是环半径，否则跟着缩到 ~29px），数值与单位用**顺序布局**防撞行；②细刻度与粗刻度**外端对齐**、向内更短；③共享 0 刻度只画一次（RPM/速度刻度列表都不含 0）；④刻度分区色用 `< warn / < danger`（与数值所用 `zoneColor` 的 `<=` 语义不同），别合并。**中心两行字号的上限是上行（转速）的宽度**：它挂在 `center − 0.72×ringInner`，那里圆的半弦只有 ~73px，而 10000–12000 时转速是 **5 位数**——现状 36px 正好卡在这条线上，想再放大就得连位置一起下移（越靠近圆心圆越宽，`−0.30×ringInner` 处半弦约 100px）。别把"刚好放得下"写成像素断言。若要从整体上回收环径：环宽 clamp 上界 27→20（+3.5px），但那会改环、属于设计取舍，不是本条的默认方向。①中心大数字按 **`ringInner × 0.34`** 定标（不是环半径，否则跟着缩到 ~29px），数值与单位用**顺序布局**防撞行；②细刻度与粗刻度**外端对齐**、向内更短；③共享 0 刻度只画一次（RPM/速度刻度列表都不含 0）；④刻度分区色用 `< warn / < danger`（与数值所用 `zoneColor` 的 `<=` 语义不同），别合并。**中心两行字号的上限是上行（转速）的宽度**：它挂在 `center − 0.72×ringInner`，那里圆的半弦只有 ~73px，而 10000–12000 时转速是 **5 位数**——现状 36px 正好卡在这条线上，想再放大就得连位置一起下移（越靠近圆心圆越宽，`−0.30×ringInner` 处半弦约 100px）。别把"刚好放得下"写成像素断言。改这块必须过 `flutter test test/widgets/combined_gauge_geometry_test.dart`（几何不变量 + 像素断言"环带内缘以内**只剩中心分栏线**的墨迹"）与既有 `combined_gauge_card_blur_test.dart`（无 `MaskFilter`；分栏线只用实色描边）。改完想先看一眼效果：`flutter test tool/gauge_preview_test.dart` 会把 341×344 的两层 painter 按 2× 超采样渲成 `test/widgets/gauge_preview_normal.png` 与 `gauge_preview_redline.png`（后者是 12000 转红区 + 5 位转速的极端排版），比真机快。启动自检浮层复用同一套 painter（画布更小 ≈309×312），代码无需改动——指针去掉后自检变成"整圈点亮再熄灭"，比原来更明显。注意 `flutter test` **不加载**打包字体（回退字体 ≈1em/字符，Roboto Mono 是 0.6em），像素/布局断言别写"文字刚好放得下"这类字体敏感项。

## 重要说明

- 项目中使用中文和用户交流
- 每次做完大的功能改动/重构，**必须**更新此文档
- 新增 Provider、Service、Model 必须遵循上述代码规范
- 代码提交前必须运行 `flutter analyze` 确保无 error
- 本文档由代码探索生成，如发现文档与实际实现不一致，请更新本文档