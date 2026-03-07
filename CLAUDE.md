# CLAUDE.md

本文档为 Claude Code (claude.ai/code) 在本项目中工作时提供指导。

## 项目概述

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
  - `RidingStatsProvider` - 骑行统计（2Hz降频采样、5秒时间窗口、事件检测）

### 项目结构

```
lib/
├── main.dart                     # 应用入口，强制横屏模式，Provider 配置
├── models/
│   ├── obd_data.dart            # OBDData、RidingEvent、DiagnosticLog 模型
│   └── bluetooth_device.dart     # BluetoothDeviceModel、DeviceConnectionStatus 模型
├── providers/
│   ├── obd_data_provider.dart   # OBD 数据状态管理（实时数据更新、历史数据）
│   ├── bluetooth_provider.dart  # 蓝牙权限、扫描、连接、ELM327初始化、OBD轮询
│   ├── log_provider.dart        # 业务日志管理（内存+文件双写）
│   └── riding_stats_provider.dart # 骑行统计（2Hz降频采样、时间窗口事件检测）
├── services/
│   ├── bluetooth_service.dart   # 蓝牙权限检测、状态检测、设置跳转
│   ├── obd_service.dart         # OBD 协议解析、分级轮询、通知处理
│   ├── log_service.dart        # 日志文件实时写入和分享
│   └── device_storage_service.dart # 设备信息持久化存储
├── screens/
│   ├── main_container.dart     # 主容器（含顶部导航栏 + IndexedStack 页面管理）
│   ├── dashboard_screen.dart    # 主仪表盘视图
│   ├── logs_screen.dart        # 诊断日志视图
│   └── bluetooth_scan_screen.dart # 蓝牙设备扫描页面
├── theme/
│   └── app_theme.dart          # 颜色常量、TextStyles、BoxDecorations
└── widgets/
    ├── speed_gauge_card.dart          # 圆形速度表
    ├── rpm_gauge_card.dart           # 带渐变的转速表
    ├── combined_gauge_card.dart      # 多仪表组合显示
    ├── speed_gear_card.dart          # 速度+档位显示
    ├── telemetry_chart_card.dart    # fl_chart 折线图
    ├── side_stats_panel.dart        # 侧边统计面板
    ├── diagnostic_logs_panel.dart   # 日志条目列表
    ├── riding_events_panel.dart     # 骑行事件列表
    ├── status_footer.dart           # 底部状态栏
    ├── bluetooth_status_icon.dart   # 蓝牙状态图标
    ├── bluetooth_alert_dialog.dart # 蓝牙提示弹窗（权限/关闭）
    ├── cyber_button.dart           # 赛博朋克风格通用按钮
    ├── bluetooth_device_list.dart  # 蓝牙设备扫描列表
    └── connected_device_card.dart   # 已连接设备详情卡片
```

### 设计系统
- 赛博朋克主题：深色背景 (#0A1114)，霓虹强调色 (#0DA6F2, #00F2FF)
- 使用 Space Grotesk 字体（Google Fonts）
- 所有卡片样式通过 `AppTheme.surfaceBorder()`，发光效果通过 `AppTheme.glowShadow()`
- 预定义透明度颜色（如 `primary20`, `primary30`）和 TextStyles（`labelSmall`, `valueMedium` 等）

### 关键模式
- 通过模型的 `copyWith()` 方法实现不可变性
- `AppTheme` 中的 const 优化 TextStyles
- 使用 `Consumer<Provider>` 监听 widgets 中的状态变化
- 更新历史数据时始终创建新的列表实例（避免修改现有列表）

### 外部依赖

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  google_fonts: ^6.1.0
  fl_chart: ^0.66.0
  provider: ^6.1.1
  permission_handler: ^11.0.0
  flutter_blue_plus: ^1.32.0
  android_intent_plus: ^4.0.2
  share_plus: ^7.0.0
  path_provider: ^2.1.0
```

## Flutter Expert 技能

本项目在 `.agents/skills/flutter-expert/SKILL.md` 中有自定义技能。主要约束：
- 尽可能使用 const 构造函数
- 使用 Consumer/ConsumerWidget 进行状态管理（非 StatefulWidget）
- 不要在 build() 方法中构建 widgets
- 不要使用 setState 管理应用级状态

## 重要规范

### 日志系统
- 使用 `LogProvider` 统一管理业务日志
- 每次 `addLog()` 会同时写入内存和实时写入文件
- 日志文件路径：`{app_documents}/obd_logs.txt`
- 分享日志直接分享已存在的文件

### 按钮组件
- 所有按钮使用 `CyberButton` 组件（赛博朋克风格）
- 支持 4 种类型：primary、secondary、danger、success

### 蓝牙模块
- 权限检测在应用启动时执行
- 蓝牙状态通过 `BluetoothProvider` 管理
- 关键方法：
  - `initialize()` - 初始化并检测蓝牙状态，自动重连上次设备
  - `startScan()` - 扫描蓝牙设备（6秒超时）
  - `connectToDevice()` - 连接设备并启动 OBD 会话
  - `requestPermission()` - 请求蓝牙权限
  - `openSettings()` - 打开系统设置
- 设备优先级：OBD > ELM > 诊断工具 > 其他

### OBD 数据流

1. **BluetoothProvider** 管理蓝牙连接和 ELM327 初始化
2. **OBDService** 负责：
   - OBD 协议解析（PID 0C=转速, 0D=车速, 05=水温, 11=节气门, 0F=进气温度, 0B=MAP, 04=负载, 42=电压）
   - 分级轮询（高速 PID 5Hz，中速 PID 2Hz，低速 PID 1Hz）
3. **OBDDataProvider** 接收实时数据并维护历史数据

### 自动重连机制
- 应用启动时自动尝试连接上次设备
- 连接断开后自动重连（最多 2 次）
- 支持 ID 匹配和名称匹配两种方式

## Android 配置

### 权限
蓝牙相关权限在 `android/app/src/main/AndroidManifest.xml` 中配置：
- BLUETOOTH
- BLUETOOTH_ADMIN
- BLUETOOTH_SCAN (Android 12+)
- BLUETOOTH_CONNECT (Android 12+)
- ACCESS_FINE_LOCATION

### 已知警告
构建时会出现来自 `android_intent_plus` 插件的 Java 版本警告，这是第三方插件的问题，不影响功能，可以忽略。

## 重要说明
- 项目中使用中文和用户交流
- 每次做完大的功能改动/重构，都要更新此文档
- 应用强制横屏方向并隐藏系统 UI 以获得沉浸式体验
