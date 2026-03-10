# CYBER-CYCLE OBD Dashboard

赛博朋克风格的 Flutter 摩托车 OBD 仪表盘应用，提供沉浸式横屏 UI，实时显示车辆诊断数据。

## 功能特性

- **实时 OBD 数据监控**：转速、车速、节气门开度、发动机负载、水温、进气温度、MAP、电压
- **蓝牙连接**：支持 ELM327 OBD 设备自动连接与重连
- **骑行事件检测**：极端倾角、急刹车、急加速等事件记录
- **倾角传感器**：实时显示摩托车倾斜角度
- **数据可视化**：fl_chart 折线图展示历史数据
- **诊断日志**：内存+文件双写日志系统
- **事件通知弹窗**：骑行事件触发时显示霓虹风格弹窗并播放语音提醒

## 项目结构

```
lib/
├── main.dart                     # 应用入口，强制横屏模式
├── models/
│   ├── obd_data.dart            # OBD 数据模型
│   ├── bluetooth_device.dart     # 蓝牙设备模型
│   ├── riding_event.dart         # 骑行事件模型
│   └── event_voice_config.dart   # 事件语音配置
├── providers/
│   ├── obd_data_provider.dart   # OBD 数据状态管理
│   ├── bluetooth_provider.dart  # 蓝牙连接管理
│   ├── log_provider.dart        # 业务日志管理
│   ├── riding_stats_provider.dart # 骑行统计
│   ├── sensor_provider.dart     # 倾角传感器
│   └── loggable.dart            # 日志回调工厂
├── services/
│   ├── bluetooth_service.dart   # 蓝牙权限与状态
│   ├── obd_service.dart         # OBD 协议解析
│   ├── log_service.dart         # 日志文件服务
│   ├── sensor_service.dart      # 倾角传感器服务
│   ├── device_storage_service.dart # 设备存储
│   └── audio_service.dart       # 音频播放服务
├── screens/
│   ├── main_container.dart      # 主容器页面
│   ├── dashboard_screen.dart    # 仪表盘视图
│   ├── logs_screen.dart         # 诊断日志视图
│   └── bluetooth_scan_screen.dart # 蓝牙扫描页面
├── theme/
│   └── app_theme.dart           # 赛博朋克主题
├── constants/
│   └── bluetooth_constants.dart # 蓝牙常量
└── widgets/
    ├── speed_gauge_card.dart          # 速度表
    ├── rpm_gauge_card.dart            # 转速表
    ├── combined_gauge_card.dart       # 组合仪表
    ├── speed_gear_card.dart           # 速度+档位
    ├── telemetry_chart_card.dart     # 折线图
    ├── side_stats_panel.dart          # 侧边统计
    ├── diagnostic_logs_panel.dart     # 诊断日志
    ├── riding_events_panel.dart       # 骑行事件
    ├── status_footer.dart             # 底部状态栏
    ├── bluetooth_status_icon.dart      # 蓝牙状态图标
    ├── bluetooth_alert_dialog.dart    # 蓝牙提示弹窗
    ├── cyber_button.dart              # 赛博按钮
    ├── cyber_dialog.dart              # 赛博弹窗
    ├── bluetooth_device_list.dart     # 设备列表
    ├── connected_device_card.dart     # 已连接设备卡片
    ├── top_navigation_bar.dart        # 顶部导航栏
    └── event_notification_dialog.dart # 事件通知弹窗
```

## 技术栈

- **Framework**: Flutter 3.0+
- **Language**: Dart
- **State Management**: Provider
- **Bluetooth**: flutter_blue_plus
- **Charts**: fl_chart
- **Fonts**: Google Fonts (Space Grotesk)
- **Sensors**: sensors_plus
- **Audio**: audioplayers

## 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Android SDK (API 21+)
- 支持蓝牙 4.0 的设备

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
flutter run
```

### 构建 APK

```bash
# Debug 构建
flutter build apk --debug

# Release 构建
flutter build apk --release
```

### 代码检查

```bash
flutter analyze
```

## Android 权限

应用需要以下权限：

- `BLUETOOTH` - 蓝牙通信
- `BLUETOOTH_ADMIN` - 蓝牙管理
- `BLUETOOTH_SCAN` - 设备扫描 (Android 12+)
- `BLUETOOTH_CONNECT` - 设备连接 (Android 12+)
- `ACCESS_FINE_LOCATION` - 位置（蓝牙扫描必需）

## OBD 数据流

```
ELM327 设备 → BluetoothProvider → OBDService → OBDDataProvider → UI
                                    ↓
                              LogProvider (日志)
```

1. **BluetoothProvider** 管理蓝牙连接和 ELM327 初始化
2. **OBDService** 负责协议解析和分级轮询
3. **OBDDataProvider** 维护实时数据和历史数据

### 分级轮询策略

| 优先级 | PID | 参数 | 频率 |
|--------|-----|------|------|
| 高速 | 0D | 车速 | 5Hz |
| 高速 | 0C | 转速 | 5Hz |
| 中速 | 11 | 节气门 | 2Hz |
| 中速 | 0F | 进气温度 | 2Hz |
| 中速 | 04 | 发动机负载 | 2Hz |
| 低速 | 05 | 水温 | 1Hz |
| 低速 | 0B | MAP | 1Hz |
| 低速 | 42 | 电压 | 1Hz |

## 设计系统

### 颜色

- 主背景: `#0A1114` (深黑)
- 主强调色: `#0DA6F2` (霓虹蓝)
- 辅助强调: `#00F2FF` (青色)
- 危险色: `#FF3366` (霓虹红)
- 成功色: `#00FF88` (霓虹绿)

### 组件

- 所有卡片使用赛博朋克风格边框 (`AppTheme.surfaceBorder()`)
- 发光效果通过 `AppTheme.glowShadow()`
- 使用 `CyberButton` 组件确保风格统一

## 架构说明

### Provider 模式

应用使用 Provider 进行状态管理：

- `OBDDataProvider` - OBD 数据
- `BluetoothProvider` - 蓝牙状态
- `LogProvider` - 业务日志
- `RidingStatsProvider` - 骑行统计
- `SensorProvider` - 倾角数据

### 自动重连

- 启动时自动连接上次设备
- 断开后自动重连（最多 2 次）
- 支持 ID 和名称两种匹配方式

## 日志系统

- 内存日志：实时显示在 Logs 页面
- 文件日志：实时写入 `{app_documents}/obd_logs.txt`
- 可通过分享功能导出日志

## 版本

- 当前版本: 1.0.0
- Flutter SDK: >=3.0.0 <4.0.0
