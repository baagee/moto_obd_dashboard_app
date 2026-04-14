# CYBER-CYCLE OBD Dashboard

<div align="center">

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/platform-Android-green.svg)
![License](https://img.shields.io/badge/license-MIT-orange.svg)

**赛博朋克风格的 Flutter 摩托车 OBD 仪表盘应用**

提供沉浸式横屏 UI，实时显示车辆诊断数据，并记录骑行轨迹和事件

[功能特性](#功能特性) • [技术架构](#技术架构) • [快速开始](#快速开始) • [文档](#文档)

</div>

---

## 📱 应用截图

### 主仪表盘
- **实时数据显示**：转速、速度、档位、倾角等
- **赛博朋克风格**：霓虹发光效果、半透明玻璃拟态
- **自检动画**：冷启动时 1.5 秒仪表自检效果

### 骑行记录
- **自动记录**：启动时自动开始记录骑行数据
- **地图轨迹**：使用 OpenStreetMap 显示骑行路线
- **统计分析**：距离、时间、平均速度、最高速度、最大倾角等

### 事件检测
- **智能识别**：极限压弯、换挡建议、温度异常等 11 种事件类型
- **语音提醒**：可配置的语音播报功能
- **霓虹弹窗**：实时显示骑行事件通知

---

## ✨ 功能特性

### 核心功能

#### 🚀 实时 OBD 数据监控
- **高频数据** (5Hz)：转速 (RPM)、车速 (Speed)
- **中频数据** (2Hz)：节气门开度、进气温度、发动机负载
- **低频数据** (1Hz)：水温、MAP、电池电压
- **分级轮询策略**：根据数据重要性优化轮询频率

#### 📡 蓝牙连接管理
- **自动连接**：启动时自动连接上次配对的 ELM327 设备
- **智能重连**：断线后自动重连（最多 2 次）
- **双匹配模式**：支持设备 ID 和名称两种匹配方式
- **连接状态监控**：实时显示蓝牙和 OBD 连接状态

#### 🏍️ 骑行数据采集
- **GPS 轨迹**：实时记录骑行路径坐标点
- **传感器数据**：手机陀螺仪检测倾斜角度 (66Hz 高频)
- **自动记录**：启动时自动开始，停止时自动保存
- **逆地理编码**：自动获取起点和终点地名
- **数据库持久化**：SQLite 存储骑行记录和事件

#### 🎯 事件智能检测

支持 11 种骑行事件类型：

| 事件类型 | 触发条件 | 说明 |
|---------|---------|------|
| **极限压弯** | 速度 > 60km/h 且倾角 > 35° | 高速大倾角转弯 |
| **建议升档** | 转速 > 设定阈值 | 可配置无冷却时间提醒 |
| **建议降档** | 转速 < 设定阈值 | 可配置无冷却时间提醒 |
| **性能爆发** | 节气门 > 85% 且负载 > 80% | 激进驾驶 |
| **高效巡航** | 速度稳定、节气门稳定 | 经济驾驶 |
| **引擎过热** | 水温 > 100°C | 温度预警 |
| **电压异常** | 电压 < 12V 或 > 15V | 电气系统异常 |
| **长途骑行** | 持续时间 > 60 分钟 | 疲劳提醒 |
| **高负荷** | 发动机负载 > 80% 持续时间 | 发动机保护 |
| **引擎预热** | 水温 < 60°C 且已运行 > 3 分钟 | 预热提醒 |
| **低温风险** | 进气温度 < 5°C | 低温预警 |

#### 📊 数据可视化
- **折线图**：fl_chart 实现的历史数据趋势图
- **自适应 Y 轴**：根据设置动态调整刻度范围
- **实时更新**：流畅的数据曲线动画

#### 🎨 UI/UX 特性
- **强制横屏**：专为骑行场景优化的横屏布局
- **赛博朋克风格**：霓虹发光、玻璃拟态、几何图形
- **响应式设计**：自适应不同屏幕尺寸
- **四角装饰**：12px 统一长度的赛博朋克边角装饰
- **性能优化**：使用 `context.select` 避免不必要的重建

#### 🔧 高级功能
- **诊断日志系统**：内存 + 文件双写，支持日志导出
- **档位推算**：基于 RPM/速度比计算当前档位
- **倾角过滤**：Z 轴过滤算法减少车把转动干扰
- **设置持久化**：SharedPreferences 存储用户配置
- **权限管理**：蓝牙、定位、存储权限动态申请

---

## 🏗️ 技术架构

### 技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| **Flutter** | 3.0+ | 跨平台 UI 框架 |
| **Dart** | 3.0+ | 编程语言 |
| **Provider** | 6.1.1 | 状态管理 |
| **flutter_blue_plus** | 1.32.0 | 蓝牙 BLE 通信 |
| **fl_chart** | 0.66.0 | 数据图表 |
| **sqflite** | 2.3.0 | SQLite 数据库 |
| **geolocator** | 11.0.0 | GPS 定位 |
| **flutter_map** | 8.2.2 | 地图显示 (OpenStreetMap) |
| **sensors_plus** | 4.0.0 | 手机传感器 (陀螺仪) |
| **audioplayers** | 6.0.0 | 语音播报 |
| **google_fonts** | 6.1.0 | Space Grotesk 字体 |

### 项目架构

```
lib/
├── main.dart                           # 应用入口，强制横屏模式
├── constants/                          # 常量定义
│   └── bluetooth_constants.dart        # 蓝牙常量
├── models/                             # 数据模型
│   ├── obd_data.dart                   # OBD 数据模型
│   ├── bluetooth_device.dart           # 蓝牙设备模型
│   ├── riding_event.dart               # 骑行事件模型 (11 种类型)
│   ├── riding_record.dart              # 骑行记录模型
│   └── event_voice_config.dart         # 事件语音配置
├── providers/                          # 状态管理 (Provider 模式)
│   ├── obd_data_provider.dart          # OBD 数据状态
│   ├── bluetooth_provider.dart         # 蓝牙连接管理
│   ├── log_provider.dart               # 业务日志管理
│   ├── riding_stats_provider.dart      # 骑行统计与事件检测
│   ├── riding_record_provider.dart     # 骑行记录管理
│   ├── sensor_provider.dart            # 倾角传感器
│   ├── settings_provider.dart          # 应用设置
│   ├── navigation_provider.dart        # 导航状态
│   └── loggable.dart                   # 日志回调工厂
├── services/                           # 业务服务层
│   ├── bluetooth_service.dart          # 蓝牙权限与状态管理
│   ├── obd_service.dart                # ELM327 协议解析与轮询
│   ├── log_service.dart                # 日志文件服务
│   ├── sensor_service.dart             # 倾角传感器服务
│   ├── audio_service.dart              # 语音播报服务
│   ├── database_service.dart           # SQLite 数据库
│   ├── location_service.dart           # GPS 定位服务
│   ├── geocoding_service.dart          # 逆地理编码
│   └── device_storage_service.dart     # 设备持久化存储
├── screens/                            # 页面
│   ├── main_container.dart             # 主容器 (PageView 管理)
│   ├── dashboard_screen.dart           # 仪表盘页面
│   ├── record_screen.dart              # 骑行记录列表
│   ├── riding_track_screen.dart        # 骑行轨迹详情
│   ├── logs_screen.dart                # 诊断日志页面
│   ├── settings_screen.dart            # 设置页面
│   └── bluetooth_scan_screen.dart      # 蓝牙扫描页面
├── widgets/                            # UI 组件
│   ├── combined_gauge_card.dart        # 组合仪表卡片
│   ├── speed_gear_card.dart            # 速度+档位卡片
│   ├── telemetry_chart_card.dart       # 遥测数据折线图
│   ├── side_stats_panel.dart           # 侧边统计面板
│   ├── gear_display_panel.dart         # 档位显示面板
│   ├── riding_events_panel.dart        # 骑行事件面板
│   ├── riding_event_item.dart          # 事件列表项
│   ├── swipeable_record_card.dart      # 可滑动记录卡片
│   ├── track_stats_card.dart           # 轨迹统计卡片
│   ├── speed_chart.dart                # 速度折线图
│   ├── stats_summary_card.dart         # 统计摘要卡片
│   ├── diagnostic_logs_panel.dart      # 诊断日志面板
│   ├── bluetooth_status_icon.dart      # 蓝牙状态图标
│   ├── bluetooth_alert_dialog.dart     # 蓝牙提示弹窗
│   ├── location_alert_dialog.dart      # 定位权限弹窗
│   ├── event_notification_dialog.dart  # 事件通知弹窗
│   ├── bluetooth_device_list.dart      # 蓝牙设备列表
│   ├── connected_device_card.dart      # 已连接设备卡片
│   ├── top_navigation_bar.dart         # 顶部导航栏
│   ├── cyber_button.dart               # 赛博按钮组件
│   ├── cyber_dialog.dart               # 赛博对话框
│   ├── cyber_toast.dart                # 赛博提示框
│   ├── cyber_grid_background.dart      # 网格背景
│   ├── self_check_overlay.dart         # 自检动画遮罩
│   ├── ride_event_list_modal.dart      # 事件列表模态框
│   └── settings/                       # 设置相关组件
│       ├── settings_fields.dart        # 设置字段组件
│       └── panels/                     # 设置面板
│           ├── vehicle_settings_panel.dart     # 车辆设置
│           ├── display_settings_panel.dart     # 显示设置
│           ├── bluetooth_settings_panel.dart   # 蓝牙设置
│           ├── events_settings_panel.dart      # 事件设置
│           ├── api_settings_panel.dart         # API 设置
│           └── advanced_settings_panel.dart    # 高级设置
├── utils/                              # 工具类
│   └── gear_util.dart                  # 档位推算工具
└── theme/                              # 主题
    └── app_theme.dart                  # 赛博朋克主题定义
```

### 数据流架构

#### OBD 数据流
```
ELM327 设备
    ↓ (蓝牙 BLE)
BluetoothProvider (连接管理)
    ↓
OBDService (协议解析 + 分级轮询)
    ↓
OBDDataProvider (数据状态)
    ↓
UI 组件 (仪表盘、图表)
    ↓
LogProvider (日志记录)
```

#### 骑行记录流
```
启动检测 → RidingRecordProvider.startNewRecord()
    ↓
GPS 定位 + OBD 数据 + 传感器数据
    ↓
RidingStatsProvider (数据采样 2Hz + 事件检测)
    ↓
DatabaseService (SQLite 持久化)
    ↓
停止检测 → RidingRecordProvider.endRiding()
    ↓
GeocodingService (逆地理编码)
```

#### 事件检测流
```
RidingStatsProvider (采样 2Hz)
    ↓
_detectEvents() (11 种事件规则)
    ↓
事件冷却判断 (可配置)
    ↓
_addEvent() → notifyListeners()
    ↓
MainContainer 监听 → EventNotificationDialog
    ↓
AudioService (语音播报)
```

### Provider 架构

| Provider | 职责 | 依赖 |
|----------|------|------|
| **OBDDataProvider** | OBD 数据状态管理 | OBDService |
| **BluetoothProvider** | 蓝牙连接管理 | BluetoothService, OBDService |
| **RidingStatsProvider** | 骑行统计与事件检测 | OBDDataProvider, AudioService |
| **RidingRecordProvider** | 骑行记录管理 | DatabaseService, LocationService |
| **SensorProvider** | 倾角传感器数据 | SensorService |
| **SettingsProvider** | 应用设置管理 | SharedPreferences |
| **LogProvider** | 日志管理 | LogService |
| **NavigationProvider** | 页面导航状态 | - |

---

## 🚀 快速开始

### 环境要求

- **Flutter SDK**: >= 3.0.0
- **Dart SDK**: >= 3.0.0
- **Android SDK**: API 21+ (Android 5.0)
- **硬件要求**:
  - 支持蓝牙 4.0+ 的 Android 设备
  - ELM327 蓝牙 OBD 适配器
  - 支持陀螺仪的手机

### 安装步骤

1. **克隆项目**
```bash
git clone https://github.com/baagee/moto_obd_dashboard_app.git
cd moto_obd_dashboard_app
```

2. **安装依赖**
```bash
flutter pub get
```

3. **配置 Android 权限**

项目已配置以下权限（无需手动修改）：
- `BLUETOOTH` / `BLUETOOTH_ADMIN` (Android ≤ 11)
- `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (Android ≥ 12)
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`
- `INTERNET` (OpenStreetMap)
- `WRITE_EXTERNAL_STORAGE` (日志导出)

4. **运行应用**
```bash
# 连接设备或启动模拟器
flutter run

# 或使用提供的脚本
bash run.sh
```

5. **构建 APK**
```bash
# Debug 版本
bash debug_apk.sh

# Release 版本
bash apk.sh
```

### 首次使用

1. **连接 OBD 设备**
   - 启动应用后，点击顶部导航栏的 "LINK VEHICLE" 按钮
   - 扫描并选择 ELM327 蓝牙设备 (通常名称包含 "OBDII" 或 "ELM327")
   - 连接成功后设备信息会自动保存，下次启动自动连接

2. **授权权限**
   - 首次启动时会请求蓝牙、定位、存储权限
   - 蓝牙和定位权限对于应用功能至关重要，请务必授权

3. **开始骑行**
   - 连接 OBD 设备后，仪表盘会实时显示车辆数据
   - 应用会自动开始记录骑行轨迹和事件
   - 切换到 "Record" 页面查看历史骑行记录

4. **配置设置**
   - 切换到 "Settings" 页面
   - 配置换挡提醒阈值、事件语音播报、地图服务等
   - 设置会自动保存

---

## 📖 文档

### 核心文档

- **[DESIGN_STYLE_GUIDE.md](DESIGN_STYLE_GUIDE.md)** - 赛博朋克 UI 设计规范
  - 色彩系统、圆角规范、间距规范
  - 组件设计模式、动画效果
  - 四角装饰绘制规范

- **[ELM327_INTEGRATION_PLAN.md](ELM327_INTEGRATION_PLAN.md)** - ELM327 集成方案
  - OBD 协议详解
  - 分级轮询策略
  - PID 数据解析

- **[CLAUDE.md](CLAUDE.md)** - 开发日志与决策记录
  - 架构演进历史
  - 技术选型原因
  - 已知问题和解决方案

### 功能文档

- **[docs/feature/settings_page_requirements.md](docs/feature/settings_page_requirements.md)** - 设置页面需求文档
- **[docs/feature/settings_page_technical_design.md](docs/feature/settings_page_technical_design.md)** - 设置页面技术设计
- **[docs/feature/settings_configurable_params.md](docs/feature/settings_configurable_params.md)** - 可配置参数说明
- **[docs/feature/riding_track_map.md](docs/feature/riding_track_map.md)** - 骑行轨迹地图功能
- **[docs/feature/Record.MD](docs/feature/Record.MD)** - 骑行记录功能说明

### 优化文档

- **docs/optimization/** - 性能优化记录
- **docs/review/** - 代码审查记录
- **docs/superpowers/** - 高级功能文档

---

## ⚙️ 配置说明

### 车辆设置

在 Settings → Vehicle 中配置：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| **车辆名称** | 显示在界面上的车辆昵称 | KAWASAKI ER-6N |
| **排量** | 发动机排量 (cc) | 649 |
| **缸数** | 发动机气缸数 | 2 |
| **总档位数** | 变速箱档位数 | 6 |
| **车辆类型** | 跑车/街车/巡航等 | 运动街车 |

### 显示设置

| 参数 | 说明 | 默认值 |
|------|------|--------|
| **最大转速** | 转速表最大刻度 (RPM) | 13000 |
| **最大速度** | 速度表最大刻度 (km/h) | 250 |
| **温度单位** | 摄氏度 (°C) / 华氏度 (°F) | °C |

### 事件设置

可配置 11 种事件的：
- **是否启用** - 开关事件检测
- **冷却时间** - 两次相同事件触发的最小间隔 (0-300 秒)
- **语音播报** - 是否语音提醒

特殊事件：
- **建议升档/降档** - 支持无冷却时间 (0 秒)，实现实时换挡提醒

### API 设置

| 参数 | 说明 | 默认值 |
|------|------|--------|
| **高德地图 Key** | 逆地理编码服务 | - |
| **备用 Key** | 高德 API 备用密钥 | - |

### 蓝牙设置

| 参数 | 说明 | 默认值 |
|------|------|--------|
| **自动连接** | 启动时自动连接上次设备 | 启用 |
| **最大重连次数** | 断线后重连次数 | 2 |

---

## 🎨 设计系统

### 色彩系统

| 名称　　　　　　　　| 色值　　　| 用途　　　　　　　　　　 |
| ---------------------| -----------| --------------------------|
| **Primary**　　　　 | `#0DA6F2` | 主强调色、边框、激活状态 |
| **Accent Cyan**　　 | `#00F2FF` | 高亮数据、渐变终点　　　 |
| **Accent Green**　　| `#00E676` | 成功状态、正常连接　　　 |
| **Accent Orange**　 | `#FFAB40` | 警告、温度数据　　　　　 |
| **Accent Red**　　　| `#FF4D4D` | 错误、危险状态　　　　　 |
| **Background Dark** | `#0A1114` | 主背景　　　　　　　　　 |
| **Surface**　　　　 | `#162229` | 卡片背景、面板背景　　　 |
| **Text Primary**　　| `#FFFFFF` | 主要数据、标题　　　　　 |
| **Text Secondary**　| `#9CA3AF` | 次要标签、说明文字　　　 |
| **Text Muted**　　　| `#6B7280` | 小标签、时间戳　　　　　 |

### 字体

- **主字体**: Space Grotesk (Google Fonts)
- **代码字体**: Courier / Monospace

### 圆角规范

| 元素 | 圆角值 |
|------|--------|
| 卡片容器 | `12px` |
| 按钮 | `8px` |
| 输入框 | `8px` |
| 进度条 | `6px` / `3px` (内部) |
| 日志项 | `4px` |

### 发光效果

```dart
// 边框发光
BoxShadow(
  color: AppTheme.primary.withOpacity(0.3),
  blurRadius: 8,
  spreadRadius: 0,
)

// 文字发光
Shadow(
  color: AppTheme.accentCyan.withOpacity(0.5),
  blurRadius: 4,
)
```

---

## 🔧 开发指南

### 添加新事件类型

1. **在 `models/riding_event.dart` 中添加枚举**:
```dart
enum RidingEventType {
  // ... 现有事件
  myNewEvent, // 新事件
}
```

2. **添加显示名称映射**:
```dart
String getEventTypeDisplayName(RidingEventType type) {
  switch (type) {
    // ...
    case RidingEventType.myNewEvent:
      return '我的新事件';
  }
}
```

3. **在 `providers/riding_stats_provider.dart` 实现检测逻辑**:
```dart
void _detectEvents() {
  // ...
  
  // 新事件检测
  if (_shouldDetectEvent(RidingEventType.myNewEvent) &&
      _checkCondition()) {
    _addEvent(RidingEventType.myNewEvent, ...);
  }
}
```

4. **在 `widgets/settings/panels/events_settings_panel.dart` 添加配置项**

### 修改 OBD 轮询频率

在 `services/obd_service.dart` 中修改：
```dart
static const Duration highFreqInterval = Duration(milliseconds: 200); // 5Hz
static const Duration midFreqInterval = Duration(milliseconds: 500);  // 2Hz
static const Duration lowFreqInterval = Duration(seconds: 1);         // 1Hz
```

### 自定义主题颜色

在 `theme/app_theme.dart` 中修改：
```dart
static const Color primary = Color(0xFF0DA6F2);
static const Color accentCyan = Color(0xFF00F2FF);
// ...
```

---

## 🐛 已知问题

### 1. 骑行结束后 APP 操作卡顿
**原因**: 隐藏的 Dashboard 页面持续被高频传感器更新驱动重建，叠加记录页的全量刷新导致卡顿。

**解决方案**: 部分组件已使用 `context.select` 优化，避免 66Hz 倾角更新触发重建。TelemetryChartCard 仍需优化。

**相关文档**: [Thread 3o9xem4vf4bg1dn71rod](docs/review/performance_investigation.md)

### 2. 倾角传感器受车把转动影响
**现状**: 手机传感器安装在车把上，车把转动会影响倾角测量准确性。

**临时方案**: 已实现 Z 轴过滤算法，可减少部分干扰。

**完美方案**: 将传感器固定在车架上（需硬件改造）。

**相关文档**: [Thread 07xyp3rv5561rzpuvqu4](docs/optimization/sensor_calibration.md)

### 3. GPS 定位精度问题
**现象**: 在隧道、高楼区域 GPS 信号弱，轨迹可能出现漂移。

**建议**: 确保手机有良好的 GPS 信号接收条件。

---

## 🚧 Roadmap

### 已完成功能
- ✅ ELM327 蓝牙连接与 OBD 协议解析
- ✅ 实时数据监控与分级轮询
- ✅ 骑行记录与轨迹地图
- ✅ 11 种骑行事件检测
- ✅ 语音播报功能
- ✅ 设置页面与参数配置
- ✅ 档位推算算法
- ✅ 倾角传感器集成
- ✅ 赛博朋克 UI 风格
- ✅ 自检动画效果
- ✅ 日志系统与导出
- ✅ 换挡提醒无冷却时间配置

### 计划中功能
- 🔲 TPMS 胎压监测集成 (铁将军 MT 3W 逆向工程)
- 🔲 数据导出与分享功能增强
- 🔲 骑行数据云同步
- 🔲 多车辆配置管理
- 🔲 主题颜色自定义
- 🔲 iOS 平台支持

---

## 📊 性能优化

### 已实施优化

1. **Provider 选择性监听**
   - 使用 `context.select` 避免不必要的组件重建
   - Dashboard 组件避免 66Hz 倾角更新触发全量刷新

2. **定时器管理**
   - OBD 轮询定时器在断开连接时彻底 cancel
   - 避免空转定时器导致主线程卡顿

3. **状态保持**
   - PageView 使用 `AutomaticKeepAliveClientMixin` 保持页面状态
   - 避免页面切换时重复重建

4. **数据采样降频**
   - 骑行统计采样从实时降为 2Hz (500ms 间隔)
   - 减少事件检测计算频率

5. **数据库优化**
   - 异步批量操作
   - 自动清理孤立记录 (5 分钟前的空记录)

---

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 开发流程

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- 遵循 Dart 官方代码风格
- 使用 `flutter analyze` 检查代码
- 为新功能添加注释文档
- 保持赛博朋克 UI 风格一致性

---

## 📄 License

本项目采用 MIT License - 详见 [LICENSE](LICENSE) 文件

---

## 🙏 致谢

- [Flutter](https://flutter.dev/) - 强大的跨平台 UI 框架
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) - 稳定的蓝牙库
- [fl_chart](https://pub.dev/packages/fl_chart) - 优雅的图表库
- [OpenStreetMap](https://www.openstreetmap.org/) - 开源地图服务
- [Google Fonts](https://fonts.google.com/) - Space Grotesk 字体
- ELM327 开源社区 - OBD 协议文档

---

## 📧 联系方式

- **项目地址**: https://github.com/baagee/moto_obd_dashboard_app
- **问题反馈**: [GitHub Issues](https://github.com/baagee/moto_obd_dashboard_app/issues)

---

<div align="center">

**Made with ❤️ for Motorcycle Enthusiasts**

[⬆ 回到顶部](#cyber-cycle-obd-dashboard)

</div>
