# 骑行记录功能设计文档

## 概述

为 CYBER-CYCLE OBD Dashboard 添加骑行记录功能，支持骑行数据持久化存储、统计聚合、事件追溯。

## 需求汇总

### 1. 每次骑行记录数据

| 字段 | 说明 | 单位 |
|------|------|------|
| 开始时间 | 骑行开始时间戳 | - |
| 结束时间 | 骑行结束时间戳 | - |
| 起始地点名称 | 起点位置名称 | - |
| 起始地点坐标 | 起点经纬度 | - |
| 目的地点名称 | 终点位置名称 | - |
| 目的地点坐标 | 终点经纬度 | - |
| 骑行距离 | 本次总骑行距离 | km |
| 平均速度 | 本次平均速度 | km/h |
| 骑行时间 | 本次总时长 | h |
| 最快速度 | 本次最高速度 | km/h |
| 最大左倾角 | 本次最大左倾压弯角度 | ° |
| 最大右倾角 | 本次最大右倾压弯角度 | ° |
| 骑行事件列表 | 本次触发的所有事件 | - |

### 2. 聚合统计数据（今天/近一周/近一月）

| 指标 | 说明 | 单位 |
|------|------|------|
| 骑行距离 | 统计周期内总骑行距离 | km |
| 平均速度 | 统计周期内加权平均速度 | km/h |
| 骑行时间 | 统计周期内总骑行时间 | h |
| 最快速度 | 统计周期内最高速度 | km/h |
| 最大左倾角 | 统计周期内最大左倾角 | ° |
| 最大右倾角 | 统计周期内最大右倾角 | ° |

### 3. 页面交互

- **页面入口**：顶部导航栏 TAB "RECORD"，位于 DASHBOARD 和 LOGS 之间
- **骑行记录列表**：展示时间、地点、距离、均速、极速、左右倾角
- **查看事件**：点击"查看事件"按钮弹出事件列表弹窗
- **左滑删除**：左滑卡片露出红色删除按钮（删除时隐藏"查看事件"按钮）
- **二次确认**：点击删除按钮后弹出确认对话框

## 技术方案

### 1. GPS 定位

**依赖**：`geolocator` 插件

**功能**：
- 骑行开始时记录起点坐标和地名（逆地理编码）
- 骑行过程中持续记录位置（可选，用于轨迹回放）
- 骑行结束时记录终点坐标和地名

**注意**：需要 Android 位置权限（ACCESS_FINE_LOCATION）

### 2. 数据持久化

**依赖**：`sqflite` + `path_provider`

**数据库表设计**：

```sql
-- 骑行记录表
CREATE TABLE riding_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  start_time INTEGER NOT NULL,           -- 毫秒时间戳
  end_time INTEGER,                       -- 毫秒时间戳
  start_latitude REAL,
  start_longitude REAL,
  start_place_name TEXT,                  -- 起点地名
  end_latitude REAL,
  end_longitude REAL,
  end_place_name TEXT,                    -- 终点地名
  distance REAL DEFAULT 0,                -- 骑行距离(km)
  avg_speed REAL DEFAULT 0,               -- 平均速度(km/h)
  duration INTEGER DEFAULT 0,             -- 骑行时长(秒)
  max_speed REAL DEFAULT 0,               -- 最快速度(km/h)
  max_left_lean REAL DEFAULT 0,           -- 最大左倾角(°)
  max_right_lean REAL DEFAULT 0,          -- 最大右倾角(°)
  created_at INTEGER NOT NULL
);

-- 骑行事件表
CREATE TABLE riding_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id INTEGER NOT NULL,             -- 关联骑行记录ID
  type TEXT NOT NULL,                    -- 事件类型
  title TEXT NOT NULL,
  description TEXT,
  trigger_value REAL,
  threshold REAL,
  timestamp INTEGER NOT NULL,            -- 事件触发时间
  additional_data TEXT,                   -- JSON字符串
  FOREIGN KEY (record_id) REFERENCES riding_records(id) ON DELETE CASCADE
);

-- 聚合缓存表（周/月预计算）
CREATE TABLE aggregation_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  period_type TEXT NOT NULL,             -- 'week' / 'month'
  period_key TEXT NOT NULL,             -- '2026-W12' / '2026-03'
  total_distance REAL DEFAULT 0,
  avg_speed REAL DEFAULT 0,
  total_duration INTEGER DEFAULT 0,
  max_speed REAL DEFAULT 0,
  max_left_lean REAL DEFAULT 0,
  max_right_lean REAL DEFAULT 0,
  ride_count INTEGER DEFAULT 0,
  updated_at INTEGER NOT NULL,
  UNIQUE(period_type, period_key)
);

-- 每日聚合表
CREATE TABLE daily_stats (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL UNIQUE,             -- '2026-03-26'
  total_distance REAL DEFAULT 0,
  avg_speed REAL DEFAULT 0,
  total_duration INTEGER DEFAULT 0,
  max_speed REAL DEFAULT 0,
  max_left_lean REAL DEFAULT 0,
  max_right_lean REAL DEFAULT 0,
  ride_count INTEGER DEFAULT 0,
  updated_at INTEGER NOT NULL
);
```

### 3. 聚合查询策略

**混合模式**：
- **日统计**：实时从 `daily_stats` 表查询
- **周/月统计**：从 `aggregation_cache` 表查询预计算结果

**预计算时机**：
- 每次骑行结束时，更新当日统计（`daily_stats`）
- 每周第一天计算上周聚合（`aggregation_cache`）
- 每月第一天计算上月聚合（`aggregation_cache`）

### 4. 数据流

```
骑行开始
    │
    ▼
GPS 记录起点坐标 + 地名
    │
    ▼
OBD 数据采样 + 事件检测（RidingStatsProvider）
    │
    ▼
骑行结束
    │
    ├──► GPS 记录终点坐标 + 地名
    ├──► 计算本次骑行统计
    ├──► 保存 RidingRecord 到 SQLite
    ├──► 保存 RidingEvent 列表到 SQLite
    ├──► 更新 daily_stats 表
    └──► 检查是否需要更新周/月聚合缓存
```

## 页面设计

### 页面布局

```
┌─────────────────────────────────────────────────────────┐
│  CYBER-CYCLE OBD | DASHBOARD | RECORD | LOGS | DEVICES │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [今天] [近一周] [近一月]                                │
│                                                         │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐              │
│  │距离 │ │均速 │ │时间 │ │极速 │ │倾角 │              │
│  │128km│ │45km/h│ │2.8h │ │118km/h│ │38°左│              │
│  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘              │
│                                                         │
│  骑行历史                                               │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │ 2024-03-26 14:30 → 16:45          [查看事件]  │    │
│  │ 科技园区 → 滨江路                               │    │
│  │ 距离:45.2km  均速:52km/h  极速:98km/h  35°左  │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │ 2024-03-25 09:00 → 11:30          [查看事件]  │    │
│  │ 家中 → 山道入口                                │    │
│  │ 距离:83.3km  均速:38km/h  极速:118km/h 38°左  │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 左滑删除状态

```
┌─────────────────────────────────────────────────┐
│  ← 滑动    距离:12.5km  均速:42km/h  极速:65km/h │
│                                    [删除]         │
└─────────────────────────────────────────────────┘
  卡片左滑，右侧露出红色删除按钮
  注意：左滑时"查看事件"按钮被隐藏
```

### 事件列表弹窗

```
┌─────────────────────────────────┐
│     骑行事件列表 · 共3个事件     │
│                                 │
│  ┃ 极限压弯            15:23:45 │
│  ┃ 高速左倾压弯：车速85km/h，    │
│  ┃ 倾角35°              ←粉色   │
│                                 │
│  ┃ 高效巡航            14:55:12 │
│  ┃ 车速稳定在80km/h，         │
│  ┃ 发动机负荷较低      ←橙色   │
│                                 │
│  ┃ 性能爆发            14:32:08 │
│  ┃ 发动机转速高于6300rpm       │
│  ┃ 且车速快速攀升      ←蓝色   │
│                                 │
│         [ 关闭 ]               │
└─────────────────────────────────┘
```

### 删除确认弹窗

```
┌─────────────────────┐
│     确认删除        │
│                     │
│  确定要删除这条     │
│  骑行记录吗？       │
│  删除后无法恢复。   │
│                     │
│  [取消]   [删除]    │
└─────────────────────┘
```

## 文件结构

```
lib/
├── models/
│   └── riding_record.dart          # 骑行记录数据模型
├── providers/
│   ├── riding_record_provider.dart  # 骑行记录状态管理
│   └── location_provider.dart       # GPS定位状态管理
├── services/
│   ├── location_service.dart        # GPS定位服务
│   ├── database_service.dart        # SQLite数据库服务
│   └── geocoding_service.dart       # 逆地理编码服务
├── screens/
│   └── record_screen.dart          # 骑行记录页面
└── widgets/
    ├── stats_summary_card.dart      # 聚合统计卡片
    ├── ride_record_card.dart        # 骑行记录卡片
    ├── ride_event_list_modal.dart    # 事件列表弹窗
    ├── delete_confirm_dialog.dart    # 删除确认弹窗
    └── swipeable_record_card.dart   # 可滑动的记录卡片
```

## 依赖

```yaml
dependencies:
  geolocator: ^11.0.0        # GPS定位
  geocoding: ^2.1.0          # 逆地理编码（坐标转地名）
  sqflite: ^2.3.0            # SQLite数据库
  path_provider: ^2.1.0     # 文件路径
  intl: ^0.19.0              # 日期格式化
```

## 实现步骤

1. 添加依赖并配置权限
2. 实现 DatabaseService（SQLite 封装）
3. 实现 LocationService（GPS 服务）
4. 实现 GeocodingService（坐标转地名）
5. 创建 RidingRecord 模型
6. 创建 RidingRecordProvider（记录状态管理）
7. 修改 MainContainer 添加 RECORD 页面入口
8. 实现 RecordScreen 页面
9. 实现 SwipeableRecordCard（左滑删除）
10. 实现 RideEventListModal（事件列表弹窗）
11. 实现 DeleteConfirmDialog（二次确认）
12. 修改 RidingStatsProvider 骑行结束时保存记录到数据库
