# 设置页面技术设计方案

> 版本：v1.0
> 日期：2026-03-30
> 关联需求：[设置页面需求文档](./settings_page_requirements.md)
> 关联分析：[设置功能可配置参数全量梳理](./settings_configurable_params.md)

---

## 1. 整体设计目标

将散落在 `gear_util.dart`、`bluetooth_constants.dart`、`obd_service.dart`、`sensor_service.dart`、`riding_stats_provider.dart`、`geocoding_service.dart`、`combined_gauge_card.dart` 等源文件中的硬编码参数全部提取，由 `SettingsProvider` 统一管理，持久化至 `SharedPreferences`，运行时动态读取。

---

## 2. 整体架构

```
┌─────────────────────────────────────────────────────────────────────┐
│  main.dart                                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  MultiProvider                                                │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │  SettingsProvider (新增)                              │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │  其他 Providers（BluetoothProvider、RidingStats 等）  │   │  │
│  │  │  → 通过 ChangeNotifierProxyProvider 注入              │   │  │
│  │  │    SettingsProvider 读取参数                           │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
        ↓ context.read<SettingsProvider>()
┌────────────────────┐   ┌───────────────────────────────┐
│  SettingsScreen    │   │  SettingsProvider              │
│  (新增)            │←→│  - load() / save()              │
│  - 左侧导航列      │   │  - 6 组参数 getter/setter       │
│  - 右侧内容区      │   │  - SharedPreferences 读写       │
└────────────────────┘   └───────────────────────────────┘
                                      ↓ 运行时注入
              ┌────────────────────────────────────────────┐
              │  各消费方                                    │
              │  GearUtil         ← vehicle 组              │
              │  BluetoothProvider ← bluetooth 组           │
              │  OBDService       ← bluetooth / vehicle 组  │
              │  RidingStats      ← events / advanced 组    │
              │  SensorService    ← advanced 组             │
              │  GeocodingService ← api 组                  │
              │  CombinedGaugeCard ← display 组             │
              └────────────────────────────────────────────┘
```

---

## 3. 文件结构

新增/修改文件清单如下：

```
lib/
├── providers/
│   └── settings_provider.dart          ← 【新建】核心 Provider
├── screens/
│   └── settings_screen.dart            ← 【新建】设置页面
├── widgets/settings/                   ← 【新建目录】设置页子 Widget
│   ├── settings_nav_item.dart          ← 左侧导航单项
│   ├── settings_section_header.dart    ← 分组标题 + 分割线
│   ├── settings_field_row.dart         ← 单字段行（标签 + 说明 + 输入）
│   ├── settings_slider_field.dart      ← Slider 类型字段
│   ├── settings_number_field.dart      ← 数字输入框类型字段
│   ├── settings_radio_field.dart       ← Radio 单选类型字段
│   ├── settings_toggle_field.dart      ← Toggle 开关类型字段
│   ├── settings_password_field.dart    ← 密码输入框类型字段
│   └── panels/                         ← 各分组内容面板
│       ├── vehicle_settings_panel.dart
│       ├── bluetooth_settings_panel.dart
│       ├── events_settings_panel.dart
│       ├── display_settings_panel.dart
│       ├── api_settings_panel.dart
│       └── advanced_settings_panel.dart
├── utils/
│   └── gear_util.dart                  ← 【修改】静态常量改为从 SettingsProvider 读取
├── constants/
│   └── bluetooth_constants.dart        ← 【修改】静态常量改为从 SettingsProvider 读取
├── services/
│   ├── obd_service.dart                ← 【修改】车速修正系数动态读取
│   ├── sensor_service.dart             ← 【修改】传感器参数动态读取
│   └── geocoding_service.dart          ← 【修改】API Key 动态读取
└── main.dart                           ← 【修改】注册 SettingsProvider；注入下游
```

---

## 4. SettingsProvider 设计

### 4.1 类结构

```dart
// lib/providers/settings_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  /// 在 main() 中、runApp() 之前 await 调用
  /// 完成后 _prefs 保证就绪，runApp 执行时首帧即可读取正确持久化值
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // 不调用 notifyListeners()：此时 Widget 树尚未构建，无需通知
  }

  // ===== 通用读写辅助 =====
  // 注意：_prefs 使用 late 非空声明，init() 在 runApp 前已 await 完成，调用时保证就绪
  double _getDouble(String key, double def) => _prefs.getDouble(key) ?? def;
  int    _getInt   (String key, int    def) => _prefs.getInt   (key) ?? def;
  bool   _getBool  (String key, bool   def) => _prefs.getBool  (key) ?? def;
  String _getString(String key, String def) => _prefs.getString(key) ?? def;

  Future<void> _setDouble(String key, double v) async { await _prefs.setDouble(key, v); notifyListeners(); }
  Future<void> _setInt   (String key, int    v) async { await _prefs.setInt   (key, v); notifyListeners(); }
  Future<void> _setBool  (String key, bool   v) async { await _prefs.setBool  (key, v); notifyListeners(); }
  Future<void> _setString(String key, String v) async { await _prefs.setString(key, v); notifyListeners(); }

  // ===== 车辆参数 =====
  // ... (见 4.2 节)

  // ===== 蓝牙连接 =====
  // ... (见 4.3 节)

  // ===== 骑行事件 =====
  // ... (见 4.4 节)

  // ===== 仪表盘显示 =====
  // ... (见 4.5 节)

  // ===== 第三方服务 =====
  // ... (见 4.6 节)

  // ===== 高级设置 =====
  // ... (见 4.7 节)

  // ===== 重置 =====
  Future<void> resetGroup(String group) async { ... }
  Future<void> resetAll() async { ... }
}
```

### 4.2 车辆参数组 getter/setter

| getter | key | 默认值 | 类型 |
|--------|-----|--------|------|
| `primaryRatio` | `settings_vehicle_primaryRatio` | `1.675` | double |
| `finalRatio` | `settings_vehicle_finalRatio` | `2.764` | double |
| `tireCircumference` | `settings_vehicle_tireCircumference` | `1.97857` | double |
| `gearRatio(int n)` | `settings_vehicle_gearRatio_$n` | `[3.071,2.200,1.700,1.416,1.230,1.107][n-1]` | double |
| `speedCorrectionFactor` | `settings_vehicle_speedCorrectionFactor` | `1.08` | double |
| `neutralSpeedThreshold` | `settings_vehicle_neutralSpeedThreshold` | `3` | int |
| `neutralRpmThreshold` | `settings_vehicle_neutralRpmThreshold` | `1200` | int |

```dart
// 齿轮比默认值表
static const List<double> _defaultGearRatios = [3.071, 2.200, 1.700, 1.416, 1.230, 1.107];

List<double> get gearRatios =>
    List.generate(6, (i) => _getDouble('settings_vehicle_gearRatio_${i+1}', _defaultGearRatios[i]));

Future<void> setGearRatio(int gear, double value) =>
    _setDouble('settings_vehicle_gearRatio_$gear', value);
```

### 4.3 蓝牙参数组 getter/setter

| getter | key | 默认值 | 类型 |
|--------|-----|--------|------|
| `scanTimeoutSeconds` | `settings_bluetooth_scanTimeout` | `3` | int |
| `minRssi` | `settings_bluetooth_minRssi` | `-90` | int |
| `connectionTimeoutSeconds` | `settings_bluetooth_connectionTimeout` | `2` | int |
| `elm327InitWaitMs` | `settings_bluetooth_elm327InitWait` | `1000` | int |
| `highSpeedPidIntervalMs` | `settings_bluetooth_highSpeedPidInterval` | `50` | int |
| `mediumSpeedPidIntervalMs` | `settings_bluetooth_mediumSpeedPidInterval` | `200` | int |
| `lowSpeedPidIntervalMs` | `settings_bluetooth_lowSpeedPidInterval` | `500` | int |

> `scanWaitTimeout` 和 `connectWaitCallbackTimeout` 保持联动计算：`scanWaitTimeout = scanTimeoutSeconds * 1000 + 100`，无需独立配置。

### 4.4 骑行事件组 getter/setter

```dart
// 通用冷却（秒）
int get globalCooldownSeconds => _getInt('settings_events_globalCooldown', 30);

// 各事件开关 + 阈值
bool get performanceBurstEnabled => _getBool('settings_events_performanceBurst_enabled', true);
int  get performanceBurstRpm     => _getInt ('settings_events_performanceBurst_rpmThreshold', 6300);

bool   get engineOverheatEnabled   => ...;
int    get engineOverheatTemp      => ...;

bool   get voltageAnomalyEnabled   => ...;
double get voltageAnomalyLow       => ...;  // 11.5
double get voltageAnomalyHigh      => ...;  // 15.3

bool   get highLoadEnabled         => ...;
int    get highLoadThreshold       => ...;  // 70 (%)

bool   get longRidingEnabled       => ...;
double get longRidingDurationHours => ...;  // 1.0
int    get longRidingCooldownSeconds => ...; // 1200

bool   get efficientCruisingEnabled => ...;
int    get efficientCruisingSpeedMin => ...; // 70
int    get efficientCruisingSpeedMax => ...; // 100
int    get efficientCruisingLoadMax  => ...; // 30
int    get efficientCruisingCooldown => ...; // 300

bool   get engineWarmupEnabled    => ...;
int    get engineWarmupTemp       => ...; // 70
int    get engineWarmupRpmMax     => ...; // 6000

bool   get coldRiskEnabled        => ...;
int    get coldRiskTemp           => ...; // 5
int    get coldRiskSpeedMin       => ...; // 40
int    get coldRiskCooldown       => ...; // 120

bool   get extremeLeanEnabled     => ...;
int    get extremeLeanSpeedMin    => ...; // 60
int    get extremeLeanAngleMin    => ...; // 20
int    get extremeLeanCooldown    => ...; // 60
```

### 4.5 仪表盘显示组 getter/setter

```dart
int get maxRpm         => _getInt('settings_display_maxRpm',         12000);
int get warnRpm        => _getInt('settings_display_warnRpm',         7000);
int get dangerRpm      => _getInt('settings_display_dangerRpm',       9000);
int get maxSpeed       => _getInt('settings_display_maxSpeed',          240);
int get warnSpeed      => _getInt('settings_display_warnSpeed',         120);
int get dangerSpeed    => _getInt('settings_display_dangerSpeed',       180);
int get flashThreshold => _getInt('settings_display_flashThreshold',   100);
int get maxCoolantTemp    => _getInt('settings_display_maxCoolantTemp',  120);
int get coolantWarnTemp   => _getInt('settings_display_coolantWarnTemp', 100);
int get maxIntakeTemp     => _getInt('settings_display_maxIntakeTemp',    80);
int get intakeWarnTemp    => _getInt('settings_display_intakeWarnTemp',   50);
```

### 4.6 第三方服务组 getter/setter

```dart
String get amapKey => _getString('settings_api_amapKey', '');
Future<void> setAmapKey(String v) => _setString('settings_api_amapKey', v);
```

### 4.7 高级设置组 getter/setter

```dart
double get sensorAlpha         => _getDouble('settings_advanced_sensorAlpha',         0.98);
int    get movingAverageWindow => _getInt   ('settings_advanced_movingAverageWindow',    5);
double get deadzoneThreshold   => _getDouble('settings_advanced_deadzoneThreshold',     1.0);
double get minMoveDistance     => _getDouble('settings_advanced_minMoveDistance',        3.0);
int    get maxGpsGapSeconds    => _getInt   ('settings_advanced_maxGpsGapSeconds',       30);
int    get minRidingDistance   => _getInt   ('settings_advanced_minRidingDistance',      20);
int    get maxEventHistory     => _getInt   ('settings_advanced_maxEventHistory',        100);
```

### 4.8 批量重置实现

```dart
static const Map<String, List<String>> _groupKeys = {
  'vehicle': [
    'settings_vehicle_primaryRatio',
    'settings_vehicle_finalRatio',
    'settings_vehicle_tireCircumference',
    'settings_vehicle_gearRatio_1',
    // ... gearRatio_2~6
    'settings_vehicle_speedCorrectionFactor',
    'settings_vehicle_neutralSpeedThreshold',
    'settings_vehicle_neutralRpmThreshold',
  ],
  'bluetooth': [ /* ... */ ],
  'events':    [ /* ... */ ],
  'display':   [ /* ... */ ],
  'api':       [ /* ... */ ],
  'advanced':  [ /* ... */ ],
};

Future<void> resetGroup(String group) async {
  final keys = _groupKeys[group] ?? [];
  for (final key in keys) {
    await _prefs.remove(key);  // _prefs 为 late 非空，init() 在 runApp 前已 await，此处无需 ?.
  }
  notifyListeners();
}

Future<void> resetAll() async {
  await _prefs.clear();  // 同上，late 非空，直接调用
  notifyListeners();
}
```

---

## 5. 入口：顶部导航栏改造

与现有菜单（DASHBOARD / RECORDS / LOGS / DEVICES）保持完全一致的交互方式，在 DEVICES 前新增 **SETTINGS** 菜单项，点击后切换到设置页面（`SettingsScreen`），无需单独的关闭按钮或弹窗覆盖。

### 5.1 TopNavigationBar 无需改动

`TopNavigationBar` 通过 `navItems` 数组渲染菜单项，只需在调用处增加一个字符串即可，无需修改组件本身。

### 5.2 MainContainer 改造

**① `_pages` 列表新增 `SettingsScreen`（SETTINGS 排在 DEVICES 前）：**

```dart
// main_container.dart
final List<Widget> _pages = const [
  DashboardScreen(),   // index 0 → DASHBOARD
  RecordScreen(),      // index 1 → RECORDS
  LogsScreen(),        // index 2 → LOGS
  SettingsScreen(),    // index 3 → SETTINGS  ← 新增
  BluetoothScanScreen(), // index 4 → DEVICES
];
```

**② `navItems` 新增 'SETTINGS'：**

```dart
TopNavigationBar(
  currentIndex: currentIndex,
  onNavigate: _navigateTo,
  onLinkVehiclePressed: _navigateToBluetoothScan,
  isConnected: isConnected,
  deviceName: deviceName,
  navItems: const ['DASHBOARD', 'RECORDS', 'LOGS', 'SETTINGS', 'DEVICES'],  // ← 新增
);
```

**③ `_navigateToBluetoothScan` 更新索引：**

```dart
void _navigateToBluetoothScan() {
  _navigateTo(_pages.length - 1);  // DEVICES 始终为最后一项，无需改动
}
```

> `SettingsScreen` 作为普通 `PageView` 子页面接入，顶部导航栏、蓝牙状态图标均保持可见，与其他页面切换体验完全一致。设置页面内部**不需要**顶部标题栏或关闭按钮。

---

## 6. 设置页面 UI 实现

### 6.1 页面结构

`SettingsScreen` 作为 `PageView` 的普通子页面，顶部共用 `TopNavigationBar`，自身只需渲染左右分栏内容，不需要标题栏和关闭按钮。

### 6.2 整体骨架结构

```dart
// lib/screens/settings_screen.dart

class SettingsScreen extends StatefulWidget { ... }

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  // 6 个分组配置
  static const List<_NavEntry> _navEntries = [
    _NavEntry(icon: '🚗', label: '车辆参数'),
    _NavEntry(icon: '📡', label: '蓝牙连接'),
    _NavEntry(icon: '🔔', label: '骑行事件'),
    _NavEntry(icon: '📊', label: '仪表盘'),
    _NavEntry(icon: '🔑', label: '第三方'),
    _NavEntry(icon: '⚙️', label: '高级设置'),
  ];

  @override
  Widget build(BuildContext context) {
    // 直接返回左右分栏，不需要外层 Scaffold（已由 MainContainer 提供）
    return Row(
      children: [
        // 左侧导航列 flex: 2
        Expanded(
          flex: 2,
          child: _buildNavColumn(),
        ),
        // 竖向分隔线
        Container(
          width: 1,
          color: AppTheme.primary.withOpacity(0.15),
        ),
        // 右侧内容区 flex: 8
        Expanded(
          flex: 8,
          child: _buildContentPanel(),
        ),
      ],
    );
  }
}
```

### 6.3 左侧导航列

```dart
Widget _buildNavColumn() {
  return Container(
    color: AppTheme.surface.withOpacity(0.6),
    child: ListView.builder(
      itemCount: _navEntries.length,
      itemBuilder: (context, i) => SettingsNavItem(
        icon: _navEntries[i].icon,
        label: _navEntries[i].label,
        isSelected: _selectedIndex == i,
        onTap: () => setState(() => _selectedIndex = i),
      ),
    ),
  );
}
```

**`SettingsNavItem`** 选中态样式：
- 背景：`AppTheme.primary.withOpacity(0.12)`
- 左侧竖条：`Container(width: 3, color: AppTheme.primary)`
- 文字颜色：选中 `AppTheme.primary`，未选中 `AppTheme.textSecondary`

### 6.4 右侧内容区

```dart
Widget _buildContentPanel() {
  // 使用 IndexedStack 保留各面板滚动位置
  return IndexedStack(
    index: _selectedIndex,
    children: const [
      VehicleSettingsPanel(),
      BluetoothSettingsPanel(),
      EventsSettingsPanel(),
      DisplaySettingsPanel(),
      ApiSettingsPanel(),
      AdvancedSettingsPanel(),
    ],
  );
}
```

> **说明**：`IndexedStack` 比每次切换重建 Widget 节省资源，且能保持各面板的滚动位置。

### 6.5 各面板通用结构

所有面板继承相同模式：

```dart
// 以 VehicleSettingsPanel 为例
// 注意：项目使用 package:provider，不是 riverpod，故用标准 StatefulWidget
class VehicleSettingsPanel extends StatefulWidget {
  const VehicleSettingsPanel({super.key});

  @override
  State<VehicleSettingsPanel> createState() => _VehicleSettingsPanelState();
}

class _VehicleSettingsPanelState extends State<VehicleSettingsPanel> {
  // 本地临时值（保存前不写入 SharedPreferences）
  late Map<String, dynamic> _draft;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  void _loadDraft() {
    final s = context.read<SettingsProvider>();
    _draft = {
      'primaryRatio': s.primaryRatio,
      'finalRatio': s.finalRatio,
      // ...
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPanelHeader(context, '🚗 车辆参数'),  // 标题 + 重置本组
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildContent(),
          ),
        ),
        _buildSaveBar(),  // 底部保存按钮
      ],
    );
  }
}
```

### 6.6 面板 Header（标题 + 重置本组）

```dart
Widget _buildPanelHeader(BuildContext context, String title) {
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
      ),
    ),
    child: Row(
      children: [
        Text(title, style: AppTheme.titleMedium),
        const Spacer(),
        CyberButton.secondary(
          text: '重置本组',
          height: 26,
          fontSize: 11,
          onPressed: () => _confirmResetGroup(context),
        ),
      ],
    ),
  );
}

void _confirmResetGroup(BuildContext context) {
  CyberDialog.show(
    context: context,
    title: '重置确认',
    icon: Icons.refresh,
    accentColor: AppTheme.accentOrange,
    content: const Text('将把本组所有参数恢复为默认值，是否继续？'),
    actions: [
      CyberButton.secondary(text: '取消', onPressed: () => Navigator.pop(context)),
      const SizedBox(width: 8),
      CyberButton.danger(
        text: '确认重置',
        onPressed: () {
          context.read<SettingsProvider>().resetGroup('vehicle');
          _loadDraft();
          setState(() {});
          Navigator.pop(context);
        },
      ),
    ],
  );
}
```

### 6.7 通用字段 Widget

#### SettingsNumberField（数字输入框）

```dart
class SettingsNumberField extends StatelessWidget {
  final String label;
  final String? hint;        // 说明文字（浅灰色）
  final String? unit;
  final double currentValue;
  final double? minValue;
  final double? maxValue;
  final int decimalPlaces;
  final ValueChanged<double> onChanged;

  // ...

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelMedium),
        if (hint != null) _buildHintBox(hint!),
        Row(
          children: [
            Text('默认: ${_defaultText()}', style: AppTheme.labelSmall),
            const Spacer(),
            _buildNumberInput(),   // TextFormField + 增减箭头
            if (unit != null) Text(' $unit', style: AppTheme.labelMedium),
          ],
        ),
      ],
    );
  }
}
```

输入框样式对齐赛博朋克风格：

```dart
Widget _buildNumberInput() {
  return Container(
    width: 100,
    height: 32,
    decoration: BoxDecoration(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextFormField(
            style: const TextStyle(color: Colors.white, fontSize: 12),
            keyboardType: TextInputType.number,
            // ...
          ),
        ),
        Column(
          children: [
            _ArrowButton(Icons.keyboard_arrow_up, onTap: _increment),
            _ArrowButton(Icons.keyboard_arrow_down, onTap: _decrement),
          ],
        ),
      ],
    ),
  );
}
```

#### SettingsSliderField（Slider）

```dart
class SettingsSliderField extends StatelessWidget {
  final String label;
  final String? hint;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) valueFormatter;  // e.g. (v) => '${v.toInt()}s'
  final ValueChanged<double> onChanged;
  // ...
}
```

Slider 样式定制：

```dart
SliderTheme(
  data: SliderTheme.of(context).copyWith(
    activeTrackColor: AppTheme.primary,
    inactiveTrackColor: AppTheme.primary.withOpacity(0.2),
    thumbColor: AppTheme.primary,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    overlayColor: AppTheme.primary.withOpacity(0.2),
  ),
  child: Slider(value: value, min: min, max: max, onChanged: onChanged),
)
```

#### SettingsToggleField（开关）

```dart
// 使用 Switch 配合赛博朋克样式
Switch(
  value: value,
  activeColor: AppTheme.primary,
  onChanged: onChanged,
)
```

#### SettingsRadioField（单选）

```dart
// 水平排列 Radio 选项
Wrap(
  spacing: 12,
  children: options.map((opt) =>
    GestureDetector(
      onTap: () => onChanged(opt.value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio(value: opt.value, groupValue: currentValue, onChanged: onChanged),
          Text(opt.label, style: AppTheme.labelMedium),
        ],
      ),
    )
  ).toList(),
)
```

#### SettingsPasswordField（密码输入框）

```dart
class SettingsPasswordField extends StatefulWidget { ... }

class _SettingsPasswordFieldState extends State<SettingsPasswordField> {
  bool _obscure = true;

  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            color: AppTheme.textSecondary,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ],
    );
  }
}
```

### 6.8 底部保存按钮

```dart
Widget _buildSaveBar() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CyberButton.primary(
          text: '保 存',
          width: 120,
          height: 36,
          icon: Icons.save_outlined,
          onPressed: _onSave,
        ),
      ],
    ),
  );
}

Future<void> _onSave() async {
  final s = context.read<SettingsProvider>();
  // 逐一调用 setter 写入 SharedPreferences
  await s.setPrimaryRatio(_draft['primaryRatio']);
  // ...
  // 显示保存成功提示
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('设置已保存'),
        backgroundColor: AppTheme.accentGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
```

> **设计决策**：面板采用「草稿模式」，用户修改字段只更新本地 `_draft` Map，点击「保存」才批量写入 `SettingsProvider`→`SharedPreferences`。这样可以取消放弃修改，也避免每次输入都触发 `notifyListeners` 导致全局 rebuild。

---

## 7. 各消费方改造方案

### 7.1 GearUtil（gear_util.dart）

当前 `GSX8SCalculator` 使用静态常量，`calculateGear` 为静态方法。改造方案：

**方案A（推荐）**：将 `GSX8SCalculator` 静态参数改为从外部注入的配置对象。

```dart
class GearConfig {
  final double primaryRatio;
  final double finalRatio;
  final double tireCircumference;
  final List<double> gearRatios;
  final int neutralSpeedThreshold;
  final int neutralRpmThreshold;

  const GearConfig({
    required this.primaryRatio,
    required this.finalRatio,
    required this.tireCircumference,
    required this.gearRatios,
    required this.neutralSpeedThreshold,
    required this.neutralRpmThreshold,
  });

  factory GearConfig.fromSettings(SettingsProvider s) => GearConfig(
    primaryRatio: s.primaryRatio,
    finalRatio: s.finalRatio,
    tireCircumference: s.tireCircumference,
    gearRatios: s.gearRatios,
    neutralSpeedThreshold: s.neutralSpeedThreshold,
    neutralRpmThreshold: s.neutralRpmThreshold,
  );

  // 默认（GSX-8S）
  static const GearConfig defaults = GearConfig(
    primaryRatio: 1.675,
    finalRatio: 2.764,
    tireCircumference: 1.97857,
    gearRatios: [3.071, 2.200, 1.700, 1.416, 1.230, 1.107],
    neutralSpeedThreshold: 3,
    neutralRpmThreshold: 1200,
  );

  /// 根据当前配置计算各档位理论传动比（实例方法，随参数动态生成）
  /// 原 GSX8SCalculator._theoreticalTotals 为 static final，在类加载时固定，
  /// 无法响应 GearConfig 注入。改为此处按需计算，每次 calculateGear 调用时传入。
  List<double> get theoreticalTotals =>
      gearRatios.map((g) => primaryRatio * g * finalRatio).toList();
}

class GSX8SCalculator {
  static int calculateGear(int rpm, int speed, {int? throttle, int? load, GearConfig config = GearConfig.defaults}) {
    // ⚠️ 使用 config.theoreticalTotals 替代原来的静态 _theoreticalTotals
    // 这保证了参数变更后档位计算立即使用最新传动比，不受 static final 缓存影响
    final theoreticalTotals = config.theoreticalTotals;
    // 使用 config.primaryRatio / config.tireCircumference 替代原静态常量
    // 使用 config.neutralSpeedThreshold / config.neutralRpmThreshold 替代原静态常量
    // 原代码中所有引用 _theoreticalTotals 的地方改为引用局部变量 theoreticalTotals
    // ...
  }
}
```

调用处（`obd_service.dart` 或 `obd_data_provider.dart`）改为：

```dart
final config = GearConfig.fromSettings(context.read<SettingsProvider>());
final gear = GSX8SCalculator.calculateGear(rpm, speed, config: config);
```

### 7.2 BluetoothConstants → SettingsProvider

`BluetoothConstants` 中的静态常量在 `bluetooth_provider.dart` 中引用。改造方式：

在 `BluetoothProvider` 构造函数中注入 `SettingsProvider`，将常量引用替换为 `_settings.scanTimeoutSeconds` 等 getter 调用。

`BluetoothConstants` 文件保留，仅用于存放「不需要动态配置的」常量（如 `scanWaitTimeout` 联动计算值、`connectWaitCallbackTimeout`）：

```dart
// 保留联动计算，不再硬编码：
Duration get scanWaitTimeout => Duration(milliseconds: scanTimeoutSeconds * 1000 + 100);
Duration get connectWaitCallbackTimeout => Duration(milliseconds: connectionTimeoutSeconds * 1000 + 100);
```

`main.dart` 中 `BluetoothProvider` 改造：

```dart
ChangeNotifierProxyProvider4<OBDDataProvider, LogProvider, AudioService, SettingsProvider,
    BluetoothProvider>(
  create: (context) => BluetoothProvider(
    obdDataProvider: context.read<OBDDataProvider>(),
    logProvider: context.read<LogProvider>(),
    audioService: context.read<AudioService>(),
    settings: context.read<SettingsProvider>(),
  ),
  // ...
)
```

### 7.3 OBDService 车速修正系数

`lib/services/obd_service.dart` 第 124 行：

```dart
// 改前
speed = (speed * 1.08).toInt();

// 改后（OBDService 构造时注入 SettingsProvider）
speed = (speed * _settings.speedCorrectionFactor).toInt();
```

### 7.4 SensorService 传感器参数

`SensorService` 的 `alpha`、`movingAverageWindow`、`deadzoneThreshold` 改为从 `SettingsProvider` 读取：

```dart
class SensorService {
  final SettingsProvider _settings;

  // 不再 static const，改为 getter
  double get alpha => _settings.sensorAlpha;
  int get movingAverageWindow => _settings.movingAverageWindow;
  double get deadzoneThreshold => _settings.deadzoneThreshold;

  // 传感器参数变化后需要重新初始化滤波器状态（清空 _angleHistory 等）
  void onSettingsChanged() {
    _angleHistory.clear();
  }
}
```

`SettingsProvider.notifyListeners()` 触发时，`SensorProvider` 监听并调用 `_service.onSettingsChanged()`。

### 7.5 GeocodingService API Key

```dart
// 改前
static const String _amapKey = '99d4e91045213ccda8ebee56a8061eb2';

// 改后（静态方法改为实例方法，或通过参数传入）
// 方案：在调用 GeocodingService.getPlaceName() 时从 SettingsProvider 传入 key
static Future<String?> getPlaceName(
  double latitude,
  double longitude, {
  String amapKey = '',
  void Function(...)? logCallback,
}) async {
  if (amapKey.isEmpty) {
    return _formatCoordinate(latitude, longitude); // 降级显示坐标
  }
  // 使用传入的 amapKey 发起请求
}
```

`RidingStatsProvider` 调用处：

```dart
final key = _settingsProvider?.amapKey ?? '';
final place = await GeocodingService.getPlaceName(lat, lng, amapKey: key);
```

### 7.6 CombinedGaugeCard 量程参数

`combined_gauge_card.dart` 中的量程参数当前以构造函数参数形式传入。调用链：

- `DashboardScreen` → `CombinedGaugeCard(maxRpm: ..., warnRpm: ..., ...)`

改造方式：`DashboardScreen` 使用 `context.watch<SettingsProvider>()` 读取最新值，传给 `CombinedGaugeCard`：

```dart
// dashboard_screen.dart
final settings = context.watch<SettingsProvider>();

CombinedGaugeCard(
  maxRpm: settings.maxRpm,
  warnRpm: settings.warnRpm,
  dangerRpm: settings.dangerRpm,
  maxSpeed: settings.maxSpeed,
  warnSpeed: settings.warnSpeed,
  dangerSpeed: settings.dangerSpeed,
  flashThreshold: settings.flashThreshold,
  maxCoolantTemp: settings.maxCoolantTemp,
  coolantWarnTemp: settings.coolantWarnTemp,
  maxIntakeTemp: settings.maxIntakeTemp,
  intakeWarnTemp: settings.intakeWarnTemp,
)
```

### 7.7 RidingStatsProvider 事件阈值

```dart
// 改造前（硬编码）
static const Duration eventCooldown = Duration(seconds: 30);

// 改造后（动态读取）
Duration get _eventCooldown => Duration(seconds: _settings.globalCooldownSeconds);

// 检测方法示例
void _checkPerformanceBurst() {
  if (!_settings.performanceBurstEnabled) return;
  final threshold = _settings.performanceBurstRpm.toDouble();
  // ...
}
```

---

## 8. main.dart Provider 注册顺序

采用**方案 A：`runApp` 前 `await` 初始化**，在 `main()` 中预先完成 `SharedPreferences` 加载，`runApp` 执行时 `_prefs` 已就绪，首帧即可读到正确的持久化值，完全消除参数窗口期与 UI 闪烁问题。

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ① 在 runApp 之前完成 SharedPreferences 初始化
  // SharedPreferences.getInstance() 在真机上通常 < 20ms，不会造成可感知的启动延迟
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  // 强制横屏
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 隐藏系统 UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    MultiProvider(
      providers: [
        // ① SettingsProvider：注入已初始化的实例（_prefs 已就绪）
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
        ),
        // ② 基础 Providers
        ChangeNotifierProvider<OBDDataProvider>(...),
        ChangeNotifierProvider<LogProvider>(...),
        ChangeNotifierProvider<NavigationProvider>(...),
        // ③ 依赖 SettingsProvider 的 ProxyProvider
        ChangeNotifierProxyProvider<SettingsProvider, AudioService>(...),
        ChangeNotifierProxyProvider2<SettingsProvider, OBDDataProvider, SensorProvider>(...),
        ChangeNotifierProxyProvider4<OBDDataProvider, LogProvider, AudioService, SettingsProvider,
            BluetoothProvider>(...),
        // ④ 骑行记录 / 骑行统计
        ChangeNotifierProxyProvider<LogProvider, RidingRecordProvider>(...),
        ChangeNotifierProxyProvider3<OBDDataProvider, LogProvider, SettingsProvider,
            RidingStatsProvider>(...),
      ],
      child: const OBDDashboardApp(),
    ),
  );
}
```

> **为什么不用 `create: (_) => SettingsProvider()..init()`**：该写法将异步 `init()` 转为「fire-and-forget」调用，`runApp` 时 `_prefs` 仍为 `null`，首帧读到的是硬编码默认值，用户修改过的设置需等 `init()` 完成后触发 `notifyListeners()` 才能生效，可能造成仪表盘量程等参数的短暂跳变。

---

## 9. SharedPreferences 依赖

项目当前 `pubspec.yaml` 尚未包含 `shared_preferences` 依赖，需要新增：

```yaml
dependencies:
  shared_preferences: ^2.2.0   # 新增
```

执行 `flutter pub get` 后，Android/iOS/macOS 平台均自动配置，无需额外原生代码。

---

## 10. 第三方服务模块：测试连接功能

「测试连接」按钮调用高德 API 发一个轻量级请求（如北京天安门坐标）验证 Key 是否有效：

```dart
Future<_TestResult> _testAmapKey(String key) async {
  try {
    final result = await GeocodingService.getPlaceName(
      39.908823, 116.397470,  // 天安门
      amapKey: key,
    );
    return result != null ? _TestResult.success : _TestResult.failed;
  } catch (_) {
    return _TestResult.failed;
  }
}
```

UI 状态：
- 未测试：无状态指示
- 测试中：`CircularProgressIndicator`
- 成功：`✅ 连接正常`（绿色）
- 失败：`❌ Key 无效或网络异常`（红色）

---

## 11. 参数实时生效策略

| 参数组 | 生效时机 | 实现方式 |
|--------|---------|---------|
| 车辆参数（传动比/齿轮比） | 保存后立即生效 | `SettingsProvider.notifyListeners()` → `GearUtil` 在每次 `calculateGear()` 调用时读取最新值 |
| 车速修正系数 | 保存后立即生效 | `OBDService` 每次解析 OBD 数据时读取 `_settings.speedCorrectionFactor` |
| 仪表盘量程 | 保存后立即生效 | `DashboardScreen` 使用 `context.watch<SettingsProvider>()` 触发重建 |
| 骑行事件阈值 | 保存后立即生效（下一个采样窗口） | `RidingStatsProvider._checkXxx()` 每次从 `_settings.xxx` 读取 |
| 骑行事件开关 | 保存后立即生效 | 同上 |
| 传感器参数 | 保存后需重置滤波器历史队列 | `SensorService.onSettingsChanged()` 清空 `_angleHistory` |
| 蓝牙超时参数 | 下次连接动作时生效 | 无需特殊处理，每次操作前读取最新值 |
| OBD 轮询间隔 | 下次启动轮询时生效 | `BluetoothProvider` 停止并重启轮询定时器 |
| API Key | 保存后下次地理编码请求时生效 | 无需特殊处理 |
| 高级设置（GPS过滤/骑行记录过滤） | 下次触发对应逻辑时生效 | 无需特殊处理 |

---

## 12. 骑行事件面板特殊处理

骑行事件面板字段较多（9 个事件，共约 30 个字段），需要避免 `IndexedStack` 中一次性渲染全部字段导致的性能问题。

推荐使用 `ListView` + `ExpansionTile` 展示每个事件：

```dart
// events_settings_panel.dart
ListView(
  children: [
    _buildGlobalCooldown(),
    _buildEventCard(
      icon: '🔥', title: '性能爆发',
      enabledKey: 'performanceBurstEnabled',
      fields: [
        SettingsNumberField(label: '触发 RPM 阈值', ...),
        Text('冷却时间：使用通用冷却', style: AppTheme.labelSmall),
      ],
    ),
    // ...
  ],
)
```

每个事件卡片：
- 顶部显示 `图标 + 事件名 + Toggle 开关`
- Toggle 关闭时，下方阈值字段置灰（`IgnorePointer` + `Opacity`）
- 默认展开，可折叠

---

## 13. 数据校验

保存前对所有数字字段进行范围校验，非法值不写入，显示 Toast 提示：

```dart
bool _validateDraft() {
  if (_draft['primaryRatio'] < 0.5 || _draft['primaryRatio'] > 5.0) {
    _showError('一级传动比超出范围 (0.5 ~ 5.0)');
    return false;
  }
  // ...
  return true;
}
```

也可在 `SettingsNumberField` 中实时校验，输入框边框变红提示用户。

---

## 14. 实现优先级

按需求文档建议的 P0 > P1 > P2 > P3 顺序：

| 优先级 | 任务 | 状态 |
|--------|------|------|
| P0 | `SettingsProvider` 骨架 + SharedPreferences 读写 + `main.dart` 注册 | ✅ 已完成 |
| P0 | 高德 API Key 从 `geocoding_service.dart` 迁移到 `SettingsProvider` | ✅ 已完成 |
| P0 | 车辆参数（传动比/齿轮比）从 `gear_util.dart` 迁移，引入 `GearConfig` | ✅ 已完成 |
| P0 | 设置页面骨架（顶部导航栏 SETTINGS 入口 + 左右分栏布局 + 占位面板） | ✅ 已完成 |
| P1 | 骑行事件阈值 + 各事件开关从 `riding_stats_provider.dart` 迁移 | ✅ 已完成 |
| P1 | 车辆参数面板 + 第三方服务面板完整 UI | ✅ 已完成 |
| P1 | 骑行事件面板完整 UI | ✅ 已完成 |
| P2 | 蓝牙参数从 `bluetooth_constants.dart` 迁移 + 蓝牙面板 UI | ✅ 已完成 |
| P2 | 仪表盘量程从 `combined_gauge_card.dart` 迁移 + 仪表盘面板 UI | ✅ 已完成 |
| P3 | 车速修正系数从 `obd_service.dart` 迁移 | ✅ 已完成 |
| P3 | 传感器参数从 `sensor_service.dart` 迁移 + 高级设置面板 UI | ✅ 已完成 |
| P3 | GPS 过滤参数从 `riding_stats_provider.dart` 迁移 | ✅ 已完成（高级设置面板已含 GPS 过滤配置）|
| P3 | 重置本组 + 恢复全部默认功能 | ✅ 已完成（各面板 Header 均有「重置本组」按钮）|

> **P0 完成时间**：2026-03-30
> **P1 完成时间**：2026-03-30
> **P2 完成时间**：2026-03-30
> **P3 完成时间**：2026-03-30
>
> **已新建/改动文件（截至 2026-03-30）**：
> - `pubspec.yaml` — 新增 `shared_preferences: ^2.2.0`
> - `lib/providers/settings_provider.dart` — 新建，全量参数 getter/setter + resetGroup/resetAll
> - `lib/main.dart` — `main()` 改为 `async`，`runApp` 前 `await settingsProvider.init()`，注入 `ChangeNotifierProvider.value`
> - `lib/services/geocoding_service.dart` — 移除 `_amapKey` 静态常量，改为 `amapKey` 参数传入；空字符串时降级坐标显示
> - `lib/providers/riding_record_provider.dart` — 注入可选 `SettingsProvider`，4 处 `getPlaceName` 调用更新
> - `lib/providers/riding_stats_provider.dart` — 注入可选 `SettingsProvider`；9 类事件检测方法改为从 `SettingsProvider` 动态读取阈值/开关/冷却；移除硬编码 `static const Duration` 冷却常量
> - `lib/utils/gear_util.dart` — 新增 `GearConfig` 类（含 `theoreticalTotals` 实例 getter），`calculateGear` 接受 `config` 参数
> - `lib/screens/settings_screen.dart` — 新建，左右分栏骨架；占位面板全部替换为真实面板
> - `lib/screens/main_container.dart` — `_pages` 插入 `SettingsScreen`，`navItems` 新增 `SETTINGS`
> - `lib/widgets/settings/settings_fields.dart` — 新建，通用字段 Widget 集合（NumberField / ToggleField / SliderField / PasswordField / SectionTitle / Divider）
> - `lib/widgets/settings/panels/vehicle_settings_panel.dart` — 新建，车辆参数面板
> - `lib/widgets/settings/panels/events_settings_panel.dart` — 新建，骑行事件面板（9 类事件）
> - `lib/widgets/settings/panels/api_settings_panel.dart` — 新建，第三方服务面板（高德 API Key + 测试连接）
> - `lib/widgets/settings/panels/bluetooth_settings_panel.dart` — 新建，蓝牙参数面板
> - `lib/widgets/settings/panels/display_settings_panel.dart` — 新建，仪表盘量程面板
> - `lib/widgets/settings/panels/advanced_settings_panel.dart` — 新建，高级设置面板（传感器滤波 + GPS 过滤 + 事件历史条数）
> - `lib/widgets/combined_gauge_card.dart` — `CombinedGaugePainter` 量程从 `static const` 改为构造参数；`CombinedGaugeCard` 通过 `context.watch<SettingsProvider>()` 动态读取

---

## 15. 关键风险与注意事项

| 风险点 | 说明 | 规避措施 |
|--------|------|---------|
| `GSX8SCalculator` 全静态设计 | 档位计算当前全为 `static`，内含静态状态 `_lastValidGear` 等，难以注入参数 | 引入 `GearConfig` 参数对象，仅替换参数来源，不重构整个静态设计 |
| SharedPreferences 异步初始化 | 应用启动时 `SettingsProvider.init()` 完成前，消费方已在读取参数 | 所有 getter 返回硬编码默认值（`?? default`），保证 `_prefs == null` 时行为与原来一致 |
| 骑行中途修改参数 | 骑行进行中修改传动比等参数，档位计算立即生效，可能造成短暂显示跳变 | 接受这一行为；需求文档已注明「当前骑行也实时生效」 |
| `provider` 依赖层级变深 | `BluetoothProvider` 将依赖 4 个 Provider，`RidingStatsProvider` 依赖 3 个 | 使用 `ChangeNotifierProxyProvider4`/`ProxyProvider3`；注意 `main.dart` 中注册顺序 |
| 高级设置误操作 | 倾角滤波参数不当会导致传感器数据失真 | 面板顶部显示醒目 `⚠️` 警告；「高级设置」模块的重置入口更显眼 |
| 蓝牙 PID 间隔下限 | 高速 PID 间隔不得低于 50ms（ELM327 缓冲区限制） | 数字输入框 `min: 50`，超出范围时拒绝保存并提示 |
| `shared_preferences` 未引入 | 当前 `pubspec.yaml` 没有此依赖 | 实施前先执行 `flutter pub add shared_preferences` |
