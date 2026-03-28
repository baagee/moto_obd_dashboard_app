# 骑行轨迹地图功能 — 需求与技术文档

<!-- anchor:overview -->
## 1. 功能概述

为现有骑行记录新增**地图轨迹回放**能力。用户点击骑行记录卡片中的"查看轨迹"按钮，进入全屏地图页面，可以看到：

- 本次骑行路线以**速度热力色**绘制（慢=绿、中=橙、快=红）
- 起点/终点 Marker 标注
- 骑行事件（超速、极限压弯等）在触发坐标处显示 Marker
- 地图下方叠加关键统计数据卡片

---

<!-- anchor:background -->
## 2. 现状分析

### 已有能力（可直接复用）

| 能力 | 文件 | 说明 |
|------|------|------|
| GPS 实时追踪 | `lib/providers/riding_stats_provider.dart` | 已用 `geolocator` 订阅位置流，维护内存 `_gpsTrack` 列表 |
| WGS-84→GCJ-02 转换 | `lib/services/geocoding_service.dart` | `_wgs84ToGcj02()` 静态方法已实现 |
| 骑行事件记录 | `lib/services/database_service.dart` | `riding_events` 表已有 `timestamp`、`trigger_value`、`type` 字段 |
| 逆地理编码 | `lib/services/geocoding_service.dart` | 高德 Web API Key 已配置 |
| 高德地图 Key | `lib/services/geocoding_service.dart` | `_amapKey` 可复用 |

### 核心缺口

**当前 GPS 轨迹点（`_gpsTrack`）仅存内存，骑行结束后丢弃，数据库只保存起点/终点坐标。** 需新增 `riding_waypoints` 表持久化所有轨迹点及速度数据。

---

<!-- anchor:requirements -->
## 3. 功能需求

### 3.1 数据采集（Phase 1）

- **R1**：骑行过程中，每 **2 秒**采集一个 GPS 点（纬度、经度、当时速度），存入 `riding_waypoints` 表
- **R2**：轨迹点与 `riding_records.id` 关联，删除骑行记录时**级联删除**轨迹点
- **R3**：轨迹点过滤：继承现有漂移过滤逻辑
- **R4**：Mock 测试数据生成时同步生成模拟轨迹点（基于两点之间的直线插值 + 轻微偏移）

### 3.2 轨迹展示页面（Phase 2）

- **R5**：骑行记录卡片新增"轨迹"按钮（图标样式），点击打开全屏地图页面
- **R6**：地图使用高德地图 SDK（`amap_flutter_map`），显示标准地图
- **R7**：轨迹以 **Polyline** 展示，速度渐变着色（方案 A，见 §4.5）
- **R8**：起点 Marker（绿色旗子图标）、终点 Marker（红色旗子图标）
- **R9**：骑行事件（极限压弯、高效巡航等）在对应轨迹位置显示 Marker，点击展示事件简介弹窗
- **R10**：地图自动 `fitBounds` 到整条轨迹范围
- **R11**：地图下方固定显示统计摘要卡片（距离、时长、极速、均速）

### 3.3 增强功能（Phase 3，可选）

- **R12**：轨迹下方速度折线图（X 轴时间，Y 轴速度 km/h），使用现有 `fl_chart`

---

<!-- anchor:tech-design -->
## 4. 技术设计

### 4.1 数据库变更

**新增表 `riding_waypoints`**（在 `DatabaseService._onCreate` 中创建）：

```sql
CREATE TABLE riding_waypoints (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id INTEGER NOT NULL,
  latitude  REAL    NOT NULL,   -- WGS-84 纬度
  longitude REAL    NOT NULL,   -- WGS-84 经度
  speed     REAL    DEFAULT 0,  -- 当时速度 km/h（来自 OBD）
  timestamp INTEGER NOT NULL,   -- 毫秒时间戳
  FOREIGN KEY (record_id) REFERENCES riding_records(id) ON DELETE CASCADE
);
CREATE INDEX idx_waypoints_record_id ON riding_waypoints(record_id);
```

**数据库版本迁移**：`_dbVersion` 从 1 → 2，在 `onUpgrade` 中执行建表 SQL。

### 4.2 依赖变更

`pubspec.yaml` 新增：

```yaml
amap_flutter_map: ^3.0.0   # 高德地图展示（不含定位）
```

**不引入** `amap_flutter_location`，GPS 继续使用现有 `geolocator: ^11.0.0`。

### 4.3 新增/修改文件清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `lib/services/database_service.dart` | 修改 | 新增 `riding_waypoints` 表建表、`insertWaypoints()`、`getWaypointsByRecordId()`、`updateRidingRecord()`；`_dbVersion` 升为 2，添加 `onUpgrade` |
| `lib/models/riding_record.dart` | 修改 | 新增 `RidingWaypoint` 数据类（id, recordId, latitude, longitude, speed, timestamp） |
| `lib/providers/riding_stats_provider.dart` | 修改 | 骑行开始时先插入占位记录获取 `_currentRecordId`；新增 `_waypointTimer`（**2秒**）、`_pendingWaypoints`，每 **15** 条分批落库；骑行结束时 `updateRidingRecord()` 补全统计字段 |
| `lib/screens/riding_track_screen.dart` | 新增 | 骑行轨迹全屏地图页面（`StatefulWidget`） |
| `lib/widgets/track_stats_card.dart` | 新增 | 地图下方统计摘要卡片（复用 App 深色主题样式） |
| `lib/screens/record_screen.dart` | 修改 | 骑行记录卡片新增"轨迹"按钮，路由到 `RidingTrackScreen` |
| `lib/services/database_service.dart` | 修改 | `insertMockRidingRecords()` 同步生成模拟轨迹点 |
| `lib/services/geocoding_service.dart` | 修改 | `_wgs84ToGcj02()` 改为公开静态方法 `wgs84ToGcj02()` |

### 4.4 轨迹采集时序（含分批落库）

```
骑行开始 startRide()
  → DatabaseService.insertRidingRecord({ start_time, end_time: null, ... })
  → 拿到 _currentRecordId

骑行中 _waypointTimer 每 **2 秒**
  → 取当前 OBDDataProvider.speed
  → 取 _lastPosition（最新 GPS 点）
  → 若满足过滤条件（距上一点 > 3m），加入 _pendingWaypoints
  → 若 _pendingWaypoints.length >= **15**：
      DatabaseService.insertWaypoints(_currentRecordId, batch)
      _pendingWaypoints.clear()

骑行结束 endRide()
  → 剩余 _pendingWaypoints 落库（尾巴批次）
  → DatabaseService.updateRidingRecord(_currentRecordId, {
      end_time, distance, avg_speed, max_speed,
      start/end 坐标及地名
    })
```

**数据库新增方法：**
- `insertRidingRecord()` 支持 `end_time = null` 的占位写入（已支持，字段可为 null）
- 新增 `updateRidingRecord(int id, Map<String, dynamic> data)` 骑行结束时补全统计字段
- 新增 `insertWaypoints(int recordId, List<Map> waypoints)` 批量插入轨迹点

### 4.5 地图轨迹着色算法（方案 A：逐段 Color.lerp() 渐变）

每两个相邻轨迹点之间绘制一条独立 `Polyline`，颜色由该线段速度值通过 `Color.lerp()` 在三色区间内插值，相邻线段颜色差异极小，视觉呈现连续渐变效果。

**三色区间定义：**

| 速度区间 | 颜色过渡 | 色值 |
|---------|---------|------|
| 0 ~ 40 km/h | 纯绿 | `#00FF85` |
| 40 ~ 80 km/h | 绿 → 橙（线性插值） | `#00FF85` → `#FF8C00` |
| 80 km/h 以上 | 橙 → 红（线性插值，上限 120km/h） | `#FF8C00` → `#FF3B50` |

**核心实现：**

```dart
Color _speedToColor(double speed) {
  if (speed <= 40) {
    return const Color(0xFF00FF85);
  } else if (speed <= 80) {
    final t = (speed - 40) / 40;                          // 0.0 ~ 1.0
    return Color.lerp(const Color(0xFF00FF85), const Color(0xFFFF8C00), t)!;
  } else {
    final t = ((speed - 80) / 40).clamp(0.0, 1.0);        // 0.0 ~ 1.0
    return Color.lerp(const Color(0xFFFF8C00), const Color(0xFFFF3B50), t)!;
  }
}

// 生成逐段渐变 Polyline 列表
List<Polyline> _buildGradientPolylines(List<RidingWaypoint> waypoints) {
  final gcjPoints = waypoints
      .map((w) => GeocodingService.wgs84ToGcj02(w.latitude, w.longitude))
      .toList();

  final polylines = <Polyline>[];
  for (int i = 0; i < waypoints.length - 1; i++) {
    final avgSpeed = (waypoints[i].speed + waypoints[i + 1].speed) / 2;
    polylines.add(Polyline(
      points: [
        LatLng(gcjPoints[i][0], gcjPoints[i][1]),
        LatLng(gcjPoints[i + 1][0], gcjPoints[i + 1][1]),
      ],
      color: _speedToColor(avgSpeed),
      width: 4,
    ));
  }
  return polylines;
}
```

**性能估算：**

| 骑行时长 | 轨迹点数 | Polyline 段数 | 渲染压力 |
|---------|---------|-------------|---------|
| 30 分钟 | 600 | 599 | 无压力 |
| 1 小时 | 1200 | 1199 | 可接受 |
| 2 小时 | 2400 | 2399 | ⚠️ 需抽稀优化 |

### 4.6 事件 Marker 数据源

`riding_events` 表目前无 GPS 坐标字段。方案：

**方案 A（推荐，零成本）**：通过事件 `timestamp` 在 `riding_waypoints` 中找最近时间点的坐标。GPS 信号中断或无匹配轨迹点时，**不展示该 Marker**（静默忽略）。

```dart
// 伪代码
final eventTs = event.timestamp;
if (waypoints.isEmpty) return null; // 无轨迹点时跳过
final nearest = waypoints.reduce((a, b) =>
  (a.timestamp - eventTs).abs() < (b.timestamp - eventTs).abs() ? a : b);
// nearest 存在则返回坐标，否则 return null 不绘制 Marker
```

**方案 B**：`riding_events` 表新增 `latitude`、`longitude` 字段，事件触发时直接记录坐标（改动较大，暂不采用）。

### 4.7 长途骑行优化 — 渲染点抽稀

地图缩放级别低时无需全量渲染所有轨迹点，按缩放级别动态降采样：

```dart
List<RidingWaypoint> _sampleWaypoints(List<RidingWaypoint> all, double zoom) {
  int step;
  if (zoom < 10)       step = 20;   // 低缩放：约 120 段
  else if (zoom < 15)  step = 5;    // 中缩放：约 480 段
  else                 step = 1;    // 高缩放：全量

  final result = <RidingWaypoint>[];
  for (int i = 0; i < all.length; i += step) result.add(all[i]);
  if (all.last != result.last) result.add(all.last); // 确保包含终点
  return result;
}
```

在 `RidingTrackScreen` 监听地图 `onCameraMove` 回调，根据当前缩放级别 `setState` 重建 Polyline 列表。

### 4.8 长途骑行优化 — 坐标转换说明

`GeocodingService._wgs84ToGcj02()` 已存在，需将其改为公开静态方法 `wgs84ToGcj02()`，供 `RidingTrackScreen` 批量调用。

---

<!-- anchor:impl-phases -->
## 5. 实施阶段

### Phase 1 — 数据层（预计 1-2 天）

1. `DatabaseService`：`_dbVersion` → 2，新增 `onUpgrade`，建 `riding_waypoints` 表，新增 `insertWaypoints()`、`getWaypointsByRecordId()`、`updateRidingRecord()`
2. `RidingRecord` 模型：新增 `RidingWaypoint` 数据类
3. `GeocodingService`：`_wgs84ToGcj02()` 改为公开方法 `wgs84ToGcj02()`
4. `RidingStatsProvider`：骑行开始时先插入占位记录；新增 `_waypointTimer`（**2秒**）、`_pendingWaypoints`，每 **15** 条分批落库；骑行结束时 `updateRidingRecord()` 补全所有统计字段
5. `insertMockRidingRecords()`：为每条 mock 记录生成模拟轨迹点（两点直线插值 + 随机偏移）

### Phase 2 — 展示层（预计 2-3 天）

1. 安装 `amap_flutter_map`，配置 Android/iOS Key（复用 `geocoding_service.dart` 中的 `_amapKey`）
2. 新建 `RidingTrackScreen`：加载轨迹点 → 坐标系转换 → 按缩放级别抽稀 → 生成渐变 Polyline → 起终点 Marker → fitBounds → 监听 `onCameraMove` 动态重采样
3. 新建 `TrackStatsCard`：底部统计摘要（距离/时长/极速/均速）
4. `record_screen.dart`：骑行卡片新增"轨迹"按钮，判断轨迹点数量 ≥ 2 才可点击

### Phase 3 — 增强（可选，后续迭代）

- `fl_chart` 速度折线图（复用现有依赖）

---

<!-- anchor:risks -->
## 6. 风险与注意事项

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| `amap_flutter_map` 最后更新 2021 年，可能与新版 Flutter/Gradle 不兼容 | 构建失败 | 提前验证 Demo 可构建；备选方案：`flutter_map`（OSM，无需 Key）+ 高德瓦片地址 |
| 数据库版本升级未正确处理旧设备 | 数据丢失 | `onUpgrade` 只执行 `CREATE TABLE IF NOT EXISTS`，不删除旧数据 |
| 轨迹点每次骑行 300-2400 条，长期使用后存储膨胀 | 存储空间 | 每条记录约 40 字节 × 600 点 = 24KB，100 次骑行 ≈ 2.4MB，可接受；后续可加清理策略 |
| 高德 API Key 硬编码在源码中 | 安全风险（现有问题，非本次新增）| 建议抽取到 `.env` 或混淆；本次不在范围内 |
| 骑行中 `_waypointTimer` 频率与 GPS 实际更新频率不同步 | 轨迹点坐标重复 | 记录点时检查与上一个点距离 > 5m 才存储，避免静止时积累重复点 |
| App 被系统回收导致轨迹数据丢失 | 长途骑行数据丢失 | 分批落库（每 **15** 点写一次 DB，2秒间隔），最多丢失约 **30 秒**数据 |
