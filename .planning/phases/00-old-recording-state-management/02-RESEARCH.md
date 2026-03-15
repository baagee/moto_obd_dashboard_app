<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **记录入口位置**: 导航栏入口 - 在顶部导航添加轨迹Tab，混合模式，图标+文字显示状态
- **骑行中UI**: 统计+迷你地图，地图优先布局
- **删除确认流程**: 确认对话框，简洁确认
- **历史列表布局**: 简洁列表，包含速度字段（日期、时间、距离、时长、最高速度、平均速度）

### Claude's Discretion
- 具体UI组件实现细节
- 导航Tab图标选择
- 页面路由方式

### Deferred Ideas (OUT OF SCOPE)
- Phase 3 会实现完整地图显示
- Phase 4 会实现 OBD 数据叠加
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GPS-02 | User can start recording a new ride session | Start/stop recording control in RecordingProvider |
| GPS-03 | User can stop recording and save the ride | RecordingProvider manages save flow |
| STOR-02 | User can load and view previously saved rides | TrajectoryStorageService already has getPointsBySession |
| STOR-03 | User can delete unwanted ride records | TrajectoryStorageService deletePointsBySession + delete dialog |
| HIST-01 | User can view list of all past rides | History list screen with Trajectory query |
| HIST-02 | Each ride entry shows date, distance, duration | List item displays Trajectory model fields |
| HIST-03 | User can tap to view any historical ride on map | Navigation to detail screen (Phase 3 handles map display) |
</phase_requirements>

# Phase 2: Recording State Management - Research

**Researched:** 2026-03-14
**Domain:** Flutter state management for ride recording, navigation, and history management
**Confidence:** HIGH

## Summary

Phase 2 focuses on implementing recording state management, navigation entry, and history management. The project already has core infrastructure from Phase 1: `Trajectory` model, `TrajectoryStorageService` with SQLite, `GPSProvider`, and `TrajectoryStatsProvider`. This phase adds recording control (start/stop), navigation tab integration, and history list/detail screens.

**Primary recommendation:** Create a `RecordingProvider` to manage recording state (idle/recording/paused), integrate a new "Trajectory" tab into `MainContainer`'s IndexedStack, and build history screens using the existing storage service.

## Standard Stack

### Core (Already in Project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| provider | ^6.1.1 | State management | Per project CLAUDE.md |
| sqflite | ^2.4.2 | Local storage for trajectories | Already implemented in Phase 1 |
| geolocator | ^14.0.2 | GPS tracking | Already implemented in Phase 1 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| intl | ^0.20.2 | Date/time formatting | Date formatting in history list |
| uuid | ^4.2.1 | Session ID generation | Generate unique session IDs for recordings |

**Installation:**
```bash
flutter pub add intl uuid
```

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── main.dart                     # App entry (already exists)
├── models/
│   ├── trajectory.dart           # Already exists
│   └── gps_point.dart            # Already exists
├── providers/
│   ├── gps_provider.dart        # Phase 1 - GPS state
│   ├── trajectory_stats_provider.dart  # Phase 1 - Stats
│   ├── recording_provider.dart  # NEW - Recording state management
│   └── trajectory_history_provider.dart # NEW - History list state
├── services/
│   ├── trajectory_storage_service.dart # Phase 1 - Already exists
│   └── gps_service.dart         # Phase 1 - Already exists
├── screens/
│   ├── main_container.dart       # Modify - Add trajectory tab
│   ├── trajectory_screen.dart    # NEW - Recording screen (stats + mini map)
│   ├── history_screen.dart       # NEW - History list
│   └── trajectory_detail_screen.dart # NEW - Detail view
└── widgets/
    ├── trajectory/               # NEW - Trajectory-specific widgets
    │   ├── recording_controls.dart
    │   ├── mini_map_widget.dart
    │   ├── history_list_item.dart
    │   └── stats_overlay.dart
    └── top_navigation_bar.dart   # Modify - Add recording indicator
```

### Pattern 1: RecordingProvider State Machine
**What:** Manages ride recording lifecycle states
**When to use:** When user starts/stops/pauses recording
**Example:**
```dart
// Source: Based on existing Provider patterns in project
enum RecordingState { idle, recording, paused }

class RecordingProvider extends ChangeNotifier {
  RecordingState _state = RecordingState.idle;
  Trajectory? _currentTrajectory;
  String? _currentSessionId;

  RecordingState get state => _state;
  bool get isRecording => _state == RecordingState.recording;
  bool get isPaused => _state == RecordingState.paused;

  Future<void> startRecording() async {
    _currentSessionId = uuid.v4();
    _currentTrajectory = Trajectory(
      id: _currentSessionId,
      sessionId: _currentSessionId,
      startTime: DateTime.now(),
      status: TrajectoryStatus.recording,
    );
    _state = RecordingState.recording;
    notifyListeners();
  }

  Future<void> stopRecording() async {
    _currentTrajectory = _currentTrajectory?.copyWith(
      endTime: DateTime.now(),
      status: TrajectoryStatus.completed,
    );
    // Save to storage
    await _storageService.saveTrajectory(_currentTrajectory!);
    _state = RecordingState.idle;
    notifyListeners();
  }
}
```

### Pattern 2: Navigation Tab Integration
**What:** Add trajectory tab to existing MainContainer with IndexedStack
**When to use:** Adding new navigation entry
**Example:**
```dart
// Source: Based on existing MainContainer pattern
enum NavigationTab { dashboard, logs, trajectory, bluetooth }

class MainContainer extends StatefulWidget {
  // ... existing code ...
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const LogsScreen(),
    const TrajectoryScreen(),  // NEW
    const BluetoothScanScreen(),
  ];
}
```

### Pattern 3: History List with TrajectoryHistoryProvider
**What:** Load and display historical trajectories
**When to use:** When viewing past ride records
**Example:**
```dart
class TrajectoryHistoryProvider extends ChangeNotifier {
  List<Trajectory> _history = [];
  bool _isLoading = false;

  List<Trajectory> get history => _history;
  bool get isLoading => _isLoading;

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    // Use TrajectoryStorageService to query all completed trajectories
    // Note: Need to add method to query all trajectories (not just points)
    _history = await _storageService.getAllTrajectories();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteTrajectory(String id) async {
    await _storageService.deletePointsBySession(id);
    _history.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
```

### Anti-Patterns to Avoid
- **Don't store recording state in GPSProvider**: Recording is a separate concern from GPS location tracking. Use dedicated RecordingProvider.
- **Don't load all trajectory points in history list**: Only load trajectory metadata (id, date, distance, duration). Load points lazily when viewing detail.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Session ID | Custom UUID generation | `uuid` package | Standard, tested UUID v4 |
| Date formatting | Manual DateTime formatting | `intl` package | Handles localization, multiple formats |
| State persistence | SharedPreferences for recording state | In-memory only (recording is short-lived) | Recording state doesn't need persistence across app restarts |

**Key insight:** Recording is a short-lived session (minutes to hours). No need to persist recording state. History data is already stored in SQLite via TrajectoryStorageService.

## Common Pitfalls

### Pitfall 1: Recording State Not Reset on App Kill
**What goes wrong:** If app is killed during recording, trajectory remains in "recording" state
**Why it happens:** Recording state is in-memory only
**How to avoid:** On app start, check for any "recording" status trajectories in storage and mark them as "completed" or offer to resume/delete
**Warning signs:** Multiple trajectories with "recording" status in database

### Pitfall 2: Memory Buildup During Recording
**What goes wrong:** Recording for long periods accumulates too many GPS points in memory
**Why it happens:** Points are collected at 2Hz (7200 points/hour)
**How to avoid:** Batch-insert points to SQLite every 30 seconds, don't keep all points in memory
**Warning signs:** App becomes sluggish during long recordings

### Pitfall 3: Mini Map Performance
**What goes wrong:** Mini map widget rebuilds too frequently
**Why it happens:** Every GPS update triggers full widget rebuild
**How to avoid:** Use `const` for static elements, separate map widget from stats overlay, use `Selector` instead of `Consumer` for GPS updates
**Warning signs:** Dropped frames during recording

## Code Examples

### Recording Control Button (CyberButton Style)
```dart
// Source: Based on existing CyberButton pattern
class RecordingControls extends StatelessWidget {
  final RecordingState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state == RecordingState.idle)
          CyberButton.primary(
            text: '开始记录',
            onPressed: onStart,
            icon: Icons.play_arrow,
          ),
        if (state == RecordingState.recording) ...[
          CyberButton.secondary(
            text: '暂停',
            onPressed: onPause,
            icon: Icons.pause,
          ),
          const SizedBox(width: 16),
          CyberButton.danger(
            text: '停止',
            onPressed: onStop,
            icon: Icons.stop,
          ),
        ],
      ],
    );
  }
}
```

### History List Item (Cyberpunk Style)
```dart
// Source: Based on existing theme patterns
class HistoryListItem extends StatelessWidget {
  final Trajectory trajectory;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppTheme.surfaceBorder(),
      child: ListTile(
        onTap: onTap,
        title: Text(
          _formatDate(trajectory.startTime),
          style: AppTheme.textStyles.valueMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatDuration(trajectory.duration)} | ${_formatDistance(trajectory.totalDistance)}',
              style: AppTheme.textStyles.labelSmall.copyWith(
                color: AppTheme.colors.textSecondary,
              ),
            ),
            Text(
              '最高: ${trajectory.maxSpeed.toStringAsFixed(1)} km/h | 平均: ${trajectory.avgSpeed.toStringAsFixed(1)} km/h',
              style: AppTheme.textStyles.labelSmall.copyWith(
                color: AppTheme.colors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.colors.danger),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
```

### Delete Confirmation Dialog
```dart
Future<bool> _showDeleteConfirmation(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.colors.surface,
      title: Text(
        '确认删除',
        style: AppTheme.textStyles.headingMedium,
      ),
      content: Text(
        '确定要删除这条轨迹记录吗？此操作无法撤销。',
        style: AppTheme.textStyles.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.colors.danger,
          ),
          child: const Text('确认删除'),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual SQLite queries | Using TrajectoryStorageService wrapper | Phase 1 | Cleaner API, testable |
| In-memory state only | Recording state in dedicated Provider | Phase 2 | Proper separation of concerns |
| No history management | TrajectoryHistoryProvider | Phase 2 | Consistent state management pattern |

**Deprecated/outdated:**
- None relevant to this phase

## Open Questions

1. **How to query all trajectories (not just points)?**
   - What we know: TrajectoryStorageService stores trajectories but doesn't have a "getAll" method yet
   - What's unclear: Need to add a trajectories table or store in same table with null session_id
   - Recommendation: Add trajectories table to SQLite schema, add `getAllTrajectories()` and `saveTrajectory()` methods

2. **Mini map implementation details**
   - What we know: Phase 3 will implement full map with flutter_map
   - What's unclear: Should mini map use same library or a lighter solution?
   - Recommendation: Use flutter_map for consistency (Phase 3 anyway), just with smaller size

3. **GPS + OBD timestamp sync (Phase 4)**
   - What we know: OBD data comes at different rates than GPS
   - What's unclear: How to align timestamps for visualization?
   - Recommendation: Defer to Phase 4 research - store raw timestamps for both sources

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none - uses default |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --reporter expanded` |

### Phase Requirements Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GPS-02 | Start recording | Unit | `flutter test test/providers/recording_provider_test.dart` | Need to create |
| GPS-03 | Stop and save | Unit | `flutter test test/providers/recording_provider_test.dart` | Need to create |
| STOR-02 | Load history | Unit | `flutter test test/providers/history_provider_test.dart` | Need to create |
| STOR-03 | Delete trajectory | Unit | `flutter test test/providers/history_provider_test.dart` | Need to create |
| HIST-01 | View history list | Widget | `flutter test test/screens/history_screen_test.dart` | Need to create |
| HIST-02 | List shows details | Widget | `flutter test test/widgets/history_list_item_test.dart` | Need to create |
| HIST-03 | Navigate to detail | Widget | `flutter test test/screens/trajectory_detail_test.dart` | Need to create |

### Wave 0 Gaps
- [ ] `test/providers/recording_provider_test.dart` - covers GPS-02, GPS-03
- [ ] `test/providers/history_provider_test.dart` - covers STOR-02, STOR-03
- [ ] `test/widgets/history_list_item_test.dart` - covers HIST-02
- [ ] `test/screens/history_screen_test.dart` - covers HIST-01
- [ ] `lib/services/trajectory_storage_service.dart` - needs `getAllTrajectories()` and `saveTrajectory()` methods added

*(Note: Phase 1 completed, but storage service needs additional methods for this phase)*

## Sources

### Primary (HIGH confidence)
- Project existing code: `lib/models/trajectory.dart`, `lib/services/trajectory_storage_service.dart`
- CLAUDE.md project instructions: Provider pattern, CyberButton usage

### Secondary (MEDIUM confidence)
- Flutter Provider documentation: ChangeNotifierProvider patterns
- intl package documentation: Date formatting

### Tertiary (LOW confidence)
- None needed - this is UI/state management based on existing project patterns

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH - Using existing project dependencies (provider, sqflite) with minor additions (intl, uuid)
- Architecture: HIGH - Follows exact patterns from CLAUDE.md (Provider, Consumer, StatelessWidget)
- Pitfalls: MEDIUM - Based on general mobile development experience, specific Flutter pitfalls verified

**Research date:** 2026-03-14
**Valid until:** 90 days (stable Flutter patterns)
