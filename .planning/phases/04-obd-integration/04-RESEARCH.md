<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **GPS时间戳对齐** - 以GPS为基准，用最近时间点的OBD数据
- **颜色+图标** - 不同事件类型使用不同颜色和图标区分
  - 急刹车: 红色
  - 急加速: 黄色
  - 极端倾角: 紫色
- **详情页底部** - 速度图表在轨迹详情页底部可折叠显示

### Claude's Discretion
- 事件标记的详细交互行为
- 图表的交互功能（缩放、平移）
- 存储模型设计细节

### Deferred Ideas (OUT OF SCOPE)
- 速度热力图显示
- RPM热力图显示
- GPX导出
- 骑行报告功能
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OBD-01 | Track points include synchronized speed data from OBD | GPSPoint needs speed/rpm fields, sync algorithm needed |
| OBD-02 | Track points include synchronized RPM data from OBD | GPSPoint model needs RPM field, storage schema update |
| OBD-03 | User can view speed chart along the track timeline | fl_chart already in use, can reuse TelemetryChartCard pattern |
| EVNT-01 | Map shows markers for hard braking events | RidingEvent model exists, map marker integration needed |
| EVNT-02 | Map shows markers for rapid acceleration events | RidingEvent already detects performanceBurst |
| EVNT-03 | Map shows markers for extreme lean angle events | RidingEvent already detects extremeLean |
| EVNT-04 | Each marker shows event type and timestamp | Marker popup/card design needed |
</phase_requirements>

# Phase 4: OBD Integration - Research

**Researched:** 2026-03-14
**Domain:** GPS+OBD数据同步, 骑行事件地图标记
**Confidence:** HIGH

## Summary

Phase 4 integrates OBD data (speed, RPM) with GPS trajectory recording and displays riding event markers on the map. The existing codebase already has foundational pieces: `GPSPoint` model, `OBDData` provider, `RidingEvent` detection in `RidingStatsProvider`, and `fl_chart` for telemetry charts. This phase requires: (1) extending GPSPoint to include OBD fields, (2) implementing time-based OBD-GPS synchronization, (3) adding event markers to the map widget, and (4) displaying a speed chart at the bottom of the trajectory detail page.

**Primary recommendation:** Extend GPSPoint with OBD fields (speed, rpm), implement nearest-time synchronization during recording, add event markers using flutter_map's Marker API, and reuse the existing fl_chart pattern for the speed chart.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_map | ^7.0.0 | Map display | OpenStreetMap integration, lightweight |
| latlong2 | ^0.9.0 | Coordinate handling | Required by flutter_map |
| fl_chart | ^0.66.0 | Speed/RPM charts | Already in project, cyberpunk styling exists |

### Supporting
| Library | Purpose | When to Use |
|---------|---------|-------------|
| Provider | State management | Already used project-wide |
| sqflite | Local storage | Already used for GPSPoint storage |

**Installation:**
```bash
# No new packages needed - all libraries already in pubspec.yaml
flutter pub get
```

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── models/
│   └── gps_point.dart        # Add OBD fields: obdSpeed, obdRpm
├── services/
│   ├── trajectory_storage_service.dart  # Add OBD fields to insert/query
│   └── obd_sync_service.dart   # NEW: OBD-GPS time sync logic
├── providers/
│   ├── recording_provider.dart  # Modify: add OBD data with GPS points
│   └── trajectory_detail_provider.dart # NEW: Load trajectory + events
├── screens/
│   └── trajectory_detail_screen.dart  # Modify: add event markers, speed chart
└── widgets/
    └── trajectory/
        ├── event_marker.dart     # NEW: Event marker widget
        ├── speed_chart.dart      # NEW: Speed timeline chart
        └── map_widget.dart       # Modify: add markers parameter
```

### Pattern 1: OBD-GPS Time Synchronization
**What:** Match OBD data points to GPS timestamps using nearest-time algorithm
**When to use:** When recording trajectory with OBD connected
**Example:**
```dart
// Source: Implementation pattern
OBDData? findNearestOBDData(DateTime gpsTime, List<OBDData> obdHistory) {
  if (obdHistory.isEmpty) return null;

  OBDData? nearest;
  Duration? minDiff;

  for (final obd in obdHistory) {
    // OBDData timestamp - need to add timestamp field
    final diff = obd.timestamp.difference(gpsTime).abs();
    if (minDiff == null || diff < minDiff) {
      minDiff = diff;
      nearest = obd;
    }
  }

  // Only match if within 2 seconds
  if (minDiff != null && minDiff.inSeconds <= 2) {
    return nearest;
  }
  return null;
}
```

### Pattern 2: Map Event Markers
**What:** Display riding event markers on flutter_map
**When to use:** Showing EVNT-01, EVNT-02, EVNT-03 on trajectory detail map
**Example:**
```dart
// Source: flutter_map documentation
MarkerLayer(
  markers: events.map((event) => Marker(
    point: LatLng(event.latitude, event.longitude),
    width: 40,
    height: 40,
    child: Icon(
      _getEventIcon(event.type),
      color: _getEventColor(event.type),
      size: 24,
    ),
  )).toList(),
)
```

### Pattern 3: Speed Chart with fl_chart
**What:** Display speed timeline chart at bottom of detail page
**When to use:** OBD-03 requirement - speed chart along track timeline
**Example:**
```dart
// Source: Existing TelemetryChartCard pattern in project
LineChart(
  LineChartData(
    gridData: const FlGridData(show: false),
    titlesData: const FlTitlesData(show: false),
    lineBarsData: [
      LineChartBarData(
        spots: points.map((p) => FlSpot(
          p.timestamp.millisecondsSinceEpoch.toDouble(),
          p.obdSpeed?.toDouble() ?? 0,
        )).toList(),
        isCurved: true,
        color: AppTheme.primary,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ),
    ],
  ),
)
```

### Anti-Patterns to Avoid
- **Don't store OBD data separately from GPS points** - Sync at write time, store together for simpler retrieval
- **Don't re-detect events on detail page** - Store detected events with trajectory, display directly

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Map rendering | Custom map | flutter_map + OpenStreetMap | Already integrated in Phase 3 |
| Chart rendering | Custom charts | fl_chart | Already in project, themed |
| Event storage | Separate table | Store events in trajectory JSON | Simpler query, less schema changes |

**Key insight:** OBD-GPS sync is the core algorithm but is straightforward (nearest-time match). No external library needed.

## Common Pitfalls

### Pitfall 1: OBD Data Not Available at GPS Timestamp
**What goes wrong:** GPS records at 2Hz but OBD polls at different rates (5Hz high, 2Hz medium)
**Why it happens:** Timing mismatch between GPS and OBD polling loops
**How to avoid:** Buffer OBD data in memory during recording, sync at write time with 2-second tolerance window
**Warning signs:** null speed/rpm in stored GPSPoints, sync function returns null frequently

### Pitfall 2: Event Markers Without Coordinates
**What goes wrong:** RidingEvents don't have GPS coordinates attached
**Why it happens:** RidingStatsProvider detects events but doesn't capture GPS location
**How to avoid:** Pass GPS location to event detection or store trajectory point index with event
**Warning signs:** Events show on list but not on map

### Pitfall 3: Large Trajectory Data Load
**What goes wrong:** Loading all GPS points with OBD data causes UI lag
**Why it happens:** No pagination or data decimation for chart display
**How to avoid:** Downsample for chart display (every 10th point), load full data only for map polyline
**Warning signs:** 10+ second load time for 1-hour ride

### Pitfall 4: Missing timestamp on OBDData
**What goes wrong:** Cannot match OBD data to GPS timestamps
**Why it happens:** OBDData model doesn't have timestamp field
**How to avoid:** Add `DateTime timestamp` field to OBDData model and set it when OBDService receives data
**Warning signs:** Cannot implement sync algorithm without timestamps

## Code Examples

### Extended GPSPoint with OBD Fields
```dart
// Source: Modified from existing gps_point.dart
class GPSPoint {
  // ... existing fields ...

  // OBD同步数据
  final int? obdSpeed;      // OBD车速 (km/h)
  final int? obdRpm;        // OBD转速 (rpm)

  GPSPoint copyWith({
    // ... existing params ...
    int? obdSpeed,
    int? obdRpm,
  }) {
    return GPSPoint(
      // ... existing assignments ...
      obdSpeed: obdSpeed ?? this.obdSpeed,
      obdRpm: obdRpm ?? this.obdRpm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // ... existing fields ...
      'obd_speed': obdSpeed,
      'obd_rpm': obdRpm,
    };
  }
}
```

### Event Color and Icon Mapping
```dart
// Source: Based on CONTEXT.md decisions
Color getEventColor(RidingEventType type) {
  switch (type) {
    case RidingEventType.performanceBurst: // 急加速
      return const Color(0xFFFFD700); // 黄色
    case RidingEventType.extremeLean: // 极端倾角
      return const Color(0xFF9B59B6); // 紫色
    // 其他事件类型可使用红色作为默认
    default:
      return const Color(0xFFE74C3C); // 红色
  }
}

IconData getEventIcon(RidingEventType type) {
  switch (type) {
    case RidingEventType.performanceBurst:
      return Icons.bolt; // 急加速
    case RidingEventType.extremeLean:
      return Icons.rotate_right; // 倾角
    default:
      return Icons.warning; // 默认警告
  }
}
```

### Recording Provider Integration
```dart
// Source: Modify recording_provider.dart addGpsPoint method
void addGpsPoint(GPSPoint point, {OBDData? currentOBD}) {
  if (_state != RecordingState.recording) {
    return;
  }

  // Sync OBD data if available
  final syncedPoint = currentOBD != null
      ? point.copyWith(
          obdSpeed: currentOBD.speed,
          obdRpm: currentOBD.rpm,
        )
      : point;

  _recordedPoints.add(syncedPoint);
  _storageService.insertPoint(syncedPoint);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| GPS-only trajectory | GPS+OBD synchronized | Phase 4 | Richer telemetry display |
| Events in list only | Events as map markers | Phase 4 | Visual riding analysis |
| No OBD in history | Historical OBD data accessible | Phase 4 | End-of-ride reports possible |

**Deprecated/outdated:**
- GPS-only speed display: Replaced by OBD speed (more accurate than GPS speed)
- Manual event marking: Replaced by automatic detection in RidingStatsProvider

## Open Questions

1. **OBD数据缓冲策略**
   - What we know: OBD polls at different rates, GPS at 2Hz
   - What's unclear: How long to keep OBD history buffer? Memory constraints on mobile
   - Recommendation: Keep 10-second rolling buffer, oldest-first eviction

2. **事件与轨迹点关联方式**
   - What we know: RidingEvents have timestamp but no coordinates
   - What's unclear: Should events store coordinates at detection time, or query by timestamp later?
   - Recommendation: Store coordinates at detection time (more reliable, less computation at display)

3. **图表数据下采样**
   - What we know: 1-hour ride = 7200 GPS points (2Hz)
   - What's unclear: Optimal downsampling for chart display?
   - Recommendation: Show max 200 points per chart, use max value in each time bucket

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter test |
| Config file | None — default |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --reporter expanded` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OBD-01 | GPSPoint includes speed from OBD | unit | `flutter test test/models/gps_point_test.dart` | needs creation |
| OBD-02 | GPSPoint includes RPM from OBD | unit | `flutter test test/models/gps_point_test.dart` | needs creation |
| OBD-03 | Speed chart displays in detail page | widget | `flutter test test/screens/trajectory_detail_test.dart` | needs creation |
| EVNT-01 | Hard braking markers on map | widget | `flutter test test/widgets/trajectory/event_marker_test.dart` | needs creation |
| EVNT-02 | Acceleration markers on map | widget | `flutter test test/widgets/trajectory/event_marker_test.dart` | needs creation |
| EVNT-03 | Lean angle markers on map | widget | `flutter test test/widgets/trajectory/event_marker_test.dart` | needs creation |
| EVNT-04 | Marker shows type and timestamp | widget | `flutter test test/widgets/trajectory/event_marker_test.dart` | needs creation |

### Sampling Rate
- **Per task commit:** `flutter test` (runs all tests)
- **Per wave merge:** `flutter test --reporter expanded`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/models/gps_point_test.dart` — covers OBD-01, OBD-02
- [ ] `test/widgets/trajectory/event_marker_test.dart` — covers EVNT-01, EVNT-02, EVNT-03, EVNT-04
- [ ] `test/screens/trajectory_detail_test.dart` — covers OBD-03
- [ ] `test/services/obd_sync_service_test.dart` — covers sync algorithm

## Sources

### Primary (HIGH confidence)
- flutter_map documentation - MarkerLayer usage
- fl_chart documentation - LineChart configuration
- Existing project code: TelemetryChartCard, GPSPoint, RidingEvent

### Secondary (MEDIUM confidence)
- Community patterns for GPS-OBD synchronization in vehicle tracking

### Tertiary (LOW confidence)
- None required - sufficient project-specific context

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in project
- Architecture: HIGH - Clear patterns from existing codebase
- Pitfalls: HIGH - Identified through codebase analysis

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (30 days - stable domain)
