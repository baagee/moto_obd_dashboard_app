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
```

## 架构

### 状态管理
- 使用 **Provider**（非 Riverpod 或 Bloc）- 见 `lib/providers/obd_data_provider.dart`
- `OBDDataProvider` 继承自 `ChangeNotifier`，管理所有 OBD 数据、事件和诊断日志
- 定时器生成模拟的 OBD 数据更新（速度、RPM、档位、温度等）

### 项目结构

```
lib/
├── main.dart                 # 应用入口，强制横屏模式，Provider 配置
├── models/
│   └── obd_data.dart         # OBDData、RidingEvent、DiagnosticLog 模型
├── providers/
│   └── obd_data_provider.dart # 主要状态管理
├── screens/
│   ├── main_container.dart   # 带顶部导航栏的导航容器
│   ├── dashboard_screen.dart # 主仪表盘视图
│   └── logs_screen.dart      # 诊断日志视图
├── theme/
│   └── app_theme.dart        # 颜色、TextStyles、BoxDecorations
└── widgets/
    ├── speed_gauge_card.dart     # 圆形速度表
    ├── rpm_gauge_card.dart      # 带渐变的转速表
    ├── combined_gauge_card.dart  # 多仪表组合显示
    ├── speed_gear_card.dart     # 速度+档位显示
    ├── telemetry_chart_card.dart # fl_chart 折线图
    ├── side_stats_panel.dart    # 侧边统计面板
    ├── diagnostic_logs_panel.dart # 日志条目
    ├── riding_events_panel.dart # 事件列表
    ├── status_footer.dart       # 底部状态栏
    └── top_navigation_bar.dart  # 导航（在 main_container 中）
```

### 设计系统
- 详见 `DESIGN_STYLE_GUIDE.md`
- 赛博朋克主题：深色背景 (#0A1114)，霓虹强调色 (#0DA6F2, #00F2FF)
- 使用 Space Grotesk 字体（Google Fonts）
- 所有卡片样式通过 `AppTheme.surfaceBorder()`，发光效果通过 `AppTheme.glowShadow()`

### 关键模式
- 通过模型的 `copyWith()` 方法实现不可变性
- `AppTheme` 中的 const 优化 TextStyles
- 使用 `Consumer<OBDDataProvider>` 监听 widgets 中的状态变化
- 更新历史数据时始终创建新的列表实例（避免修改现有列表）

### 外部依赖
- `provider: ^6.1.1` - 状态管理
- `google_fonts: ^6.1.0` - Space Grotesk 字体
- `fl_chart: ^0.66.0` - 遥测数据折线图
- `cupertino_icons: ^1.0.6` - Material 图标

## Flutter Expert 技能

本项目在 `.agents/skills/flutter-expert/SKILL.md` 中有自定义技能。主要约束：
- 尽可能使用 const 构造函数
- 使用 Consumer/ConsumerWidget 进行状态管理（非 StatefulWidget）
- 不要在 build() 方法中构建 widgets
- 不要使用 setState 管理应用级状态

## 重要说明
- 项目中使用中文和用户交流
- 应用强制横屏方向并隐藏系统 UI 以获得沉浸式体验
- 当前数据为模拟数据（provider 中的随机生成）- 已准备好按照 `ELM327_INTEGRATION_PLAN.md` 进行 ELM327 OBD 集成
- 两个主要导航标签：DASHBOARD 和 LOGS（SETTINGS 为占位符）
