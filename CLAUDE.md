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
  - `OBDDataProvider` - OBD 数据和骑行事件
  - `BluetoothProvider` - 蓝牙状态管理
  - `LogProvider` - 业务日志管理

### 项目结构

```
lib/
├── main.dart                     # 应用入口，强制横屏模式，Provider 配置
├── models/
│   └── obd_data.dart            # OBDData、RidingEvent、DiagnosticLog 模型
├── providers/
│   ├── obd_data_provider.dart   # OBD 数据和骑行事件状态管理
│   ├── bluetooth_provider.dart    # 蓝牙权限和连接状态管理
│   └── log_provider.dart         # 业务日志管理
├── services/
│   ├── bluetooth_service.dart     # 蓝牙权限检测和设置跳转
│   └── log_service.dart          # 日志文件实时写入和分享
├── screens/
│   ├── main_container.dart        # 带顶部导航栏的导航容器
│   ├── dashboard_screen.dart      # 主仪表盘视图
│   └── logs_screen.dart          # 诊断日志视图
├── theme/
│   └── app_theme.dart            # 颜色、TextStyles、BoxDecorations
└── widgets/
    ├── speed_gauge_card.dart          # 圆形速度表
    ├── rpm_gauge_card.dart           # 带渐变的转速表
    ├── combined_gauge_card.dart      # 多仪表组合显示
    ├── speed_gear_card.dart         # 速度+档位显示
    ├── telemetry_chart_card.dart     # fl_chart 折线图
    ├── side_stats_panel.dart        # 侧边统计面板
    ├── diagnostic_logs_panel.dart   # 日志条目
    ├── riding_events_panel.dart     # 事件列表
    ├── status_footer.dart           # 底部状态栏
    ├── top_navigation_bar.dart      # 导航（在 main_container 中）
    ├── bluetooth_status_icon.dart   # 蓝牙状态图标
    ├── bluetooth_alert_dialog.dart  # 蓝牙提示弹窗
    └── cyber_button.dart            # 赛博朋克风格通用按钮
```

### 设计系统
- 详见 `DESIGN_STYLE_GUIDE.md`
- 赛博朋克主题：深色背景 (#0A1114)，霓虹强调色 (#0DA6F2, #00F2FF)
- 使用 Space Grotesk 字体（Google Fonts）
- 所有卡片样式通过 `AppTheme.surfaceBorder()`，发光效果通过 `AppTheme.glowShadow()`

### 关键模式
- 通过模型的 `copyWith()` 方法实现不可变性
- `AppTheme` 中的 const 优化 TextStyles
- 使用 `Consumer<Provider>` 监听 widgets 中的状态变化
- 更新历史数据时始终创建新的列表实例（避免修改现有列表）

### 外部依赖
- `provider: ^6.1.1` - 状态管理
- `google_fonts: ^6.1.0` - Space Grotesk 字体
- `fl_chart: ^0.66.0` - 遥测数据折线图
- `cupertino_icons: ^1.0.6` - Material 图标
- `permission_handler: ^11.0.0` - 权限管理
- `flutter_blue_plus: ^1.32.0` - 蓝牙连接
- `android_intent_plus: ^4.0.2` - Android Intent
- `share_plus: ^7.0.0` - 文件分享
- `path_provider: ^2.1.0` - 文件路径

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
- 日志文件路径：`/data/data/{package}/files/obd_logs.txt`
- 分享日志直接分享已存在的文件

### 按钮组件
- 所有按钮使用 `CyberButton` 组件（赛博朋克风格）
- 支持 4 种类型：primary、secondary、danger、success
- 位置：`lib/widgets/cyber_button.dart`

### 蓝牙模块
- 权限检测在应用启动时执行
- 蓝牙状态通过 `BluetoothProvider` 管理
- 关键方法：
  - `initialize()` - 初始化并检测蓝牙状态
  - `requestPermission()` - 请求蓝牙权限
  - `openSettings()` - 打开系统设置

## Android 配置

### 权限
蓝牙相关权限在 `android/app/src/main/AndroidManifest.xml` 中配置：
- BLUETOOTH
- BLUETOOTH_ADMIN
- BLUETOOTH_SCAN
- BLUETOOTH_CONNECT
- ACCESS_FINE_LOCATION

### 已知警告
构建时会出现来自 `android_intent_plus` 插件的 Java 版本警告，这是第三方插件的问题，不影响功能，可以忽略。

## 重要说明
- 项目中使用中文和用户交流
- 每次做完大的功能改动/重构，都要更新此文档
- 应用强制横屏方向并隐藏系统 UI 以获得沉浸式体验
