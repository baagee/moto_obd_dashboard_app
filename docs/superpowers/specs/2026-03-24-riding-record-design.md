# 骑行记录页面设计方案

## 1. 概述

为 CYBER-CYCLE OBD Dashboard 新增骑行记录功能模块，记录真实 GPS 轨迹与 OBD 数据统计，支持本地持久化存储与历史查看。

## 2. 功能需求

### 2.1 骑行记录 Tab

- 顶部导航新增「骑行记录」Tab，切换到独立页面
- 页面结构：`RidingHistoryScreen`（历史列表）

### 2.2 自动开始/停止逻辑

- **开始条件**：蓝牙设备连接成功 → 启动 GPS 跟踪 → 创建新记录
- **停止条件**：蓝牙断开连接 → 自动保存记录 → 停止 GPS 跟踪
- 无需用户手动操作

### 2.3 骑行记录页（实时）

- 实时地图显示（Flutter Map + OpenStreetMap），跟随当前位置
- 显示指标（精简统计）：
  - 当前速度
  - 骑行时长
  - 里程
  - 最高速度（实时更新）
  - 平均速度（实时更新）
- 事件统计（骑行中小计）：
  - 极限压弯次数
  - 性能爆发次数

### 2.4 历史记录列表

- 每条记录显示完整信息卡：
  - 日期和时间
  - 总里程、总时长
  - 最高速度、平均速度
  - 事件统计（极限压弯次数、性能爆发次数等）
  - 缩略轨迹图（Polyline 预览）
- 支持点击查看详情

## 3. 数据模型

### 3.1 RidingRecord（骑行记录）

```dart
class RidingRecord {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double distance;         // 里程 (km)
  final Duration duration;       // 时长
  final double maxSpeed;         // 最高速度 (km/h)
  final double avgSpeed;         // 平均速度 (km/h)
  final Map<RidingEventType, int> eventCounts;  // 事件统计
  final List<TrackPoint> trackPoints;          // GPS轨迹点
  final bool isCompleted;        // 是否已完成
}
```

### 3.2 TrackPoint（轨迹点）

```dart
class TrackPoint {
  final double latitude;
  final double longitude;
  final double speed;       // 对应速度 (km/h)
  final DateTime timestamp;
}
```

## 4. 技术方案

### 4.1 依赖包

| 功能 | 包 | 说明 |
|------|-----|------|
| GPS 定位 | `geolocator` | 获取经纬度、位置跟踪 |
| 地图 | `flutter_map` | OpenStreetMap 地图 |
| 地图瓦片 | `latlong2` | 经纬度计算 |
| 本地存储 | `hive` + `hive_flutter` | 轻量级 NoSQL 数据库 |

### 4.2 权限

- `ACCESS_FINE_LOCATION` - 精确位置（已有）
- `ACCESS_COARSE_LOCATION` - 模糊位置
- 地图瓦片离线缓存（可选优化）

### 4.3 核心服务

```
RidingRecordService
├── startTracking()       // 开始记录（创建新记录，启动GPS采样）
├── stopTracking()        // 停止记录（保存数据，停止GPS）
├── addTrackPoint()       // 添加轨迹点
├── updateStats()         // 更新实时统计
└── getRecords()          // 获取历史记录列表
```

### 4.4 Provider

```
RidingRecordProvider (ChangeNotifier)
├── _currentRecord        // 当前骑行记录
├── _isTracking           // 是否正在记录
├── _trackPoints          // 当前轨迹点
├── _maxSpeed, _avgSpeed  // 实时统计
├── startRide()           // 蓝牙连接时调用
├── endRide()             // 蓝牙断开时调用
└── saveRecord()          // 保存到 Hive
```

## 5. 页面结构

### 5.1 MainContainer 修改

```dart
// 新增页面
final List<Widget> _pages = const [
  DashboardScreen(),
  LogsScreen(),
  BluetoothScanScreen(),
  RidingHistoryScreen(),  // 新增
];
```

### 5.2 RidingHistoryScreen

- AppBar 标题：「骑行记录」
- 状态：
  - **空闲状态**：显示历史记录列表（EmptyState 若无记录）
  - **骑行中**：自动跳转至 RidingRecordScreen
- 列表项：RidingRecordCard

### 5.3 RidingRecordScreen

- 全屏地图（占据主要区域）
- 底部悬浮统计面板（半透明背景）：
  - 当前速度（大字体）
  - 骑行时长 | 里程
  - 最高/平均速度
- 右上角：事件统计图标（显示本次骑行事件数）

### 5.4 缩略轨迹图

- 在 RidingRecordCard 中显示小尺寸 Polyline
- 使用 `flutter_map` 的 `MiniMap` 或自定义 `CustomPaint`

## 6. 实现计划

### Phase 1: 数据层
- 新增 `RidingRecord` 和 `TrackPoint` 模型
- 创建 `RidingRecordProvider`
- 配置 Hive 存储

### Phase 2: GPS 服务
- 集成 `geolocator`
- 创建 GPS 跟踪逻辑
- 实现位置采样与过滤

### Phase 3: UI 层
- 新增 `RidingHistoryScreen`
- 新增 `RidingRecordScreen`
- 集成 `flutter_map`

### Phase 4: 自动流程
- 蓝牙连接/断开自动开始/停止记录
- 数据持久化与历史加载

## 7. 已知约束

- GPS 在室内或信号弱区域可能无法获取位置
- 首次使用需要用户授权位置权限
- 地图瓦片需要网络连接（可缓存优化）
