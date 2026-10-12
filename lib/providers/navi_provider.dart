import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../data/amap/models.dart';
import '../data/amap/route_analyzer.dart';
import '../data/amap/share_client.dart';
import '../models/log.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import 'log_provider.dart';
import 'loggable.dart';
import 'obd_data_provider.dart';
import 'settings_provider.dart';

/// 导航状态机（对应方案 §3.4）
enum NaviState {
  /// 未配置短链 —— 第三列维持遥测图 + 轨迹雷达，零导航占位
  off,

  /// 路线已就绪，等首个 GPS 点
  locating,

  /// 有投影且 offset 合理
  navigating,

  /// offset 持续 > 100m，已触发重新拉取路线
  deviated,

  /// 连续请求失败 —— 保留最后一次路线，不静默消失
  stale,
}

/// 为什么还没拿到定位。
///
/// `locating` 是一个**可能永远等不到结果**的状态：权限被拒、系统定位关闭、
/// 信号弱/室内、定位流出错，都会让它一直停在"定位中…"。界面必须说实话并
/// 给出可操作的出口，所以把原因显式建模（真机反馈过"一直显示定位中"）。
enum NaviGpsIssue {
  /// 无异常（可能只是还没有第一帧）
  none,

  /// 系统定位服务未开启
  serviceDisabled,

  /// 权限被拒（可再次请求）
  denied,

  /// 权限被永久拒绝（只能去系统设置）
  deniedForever,

  /// 定位流出错（平台异常）
  streamError,

  /// 权限/服务都正常，但超过 [NaviProvider.gpsFixTimeoutSec] 仍无定位
  /// （典型：室内、地库、遮挡；也可能是 Android 的 smallestDisplacement
  /// 在静止时不回调 —— 已用"即时定位"兜底）
  noFixYet,
}

/// 沿路线的限速点（由 `cameras[].speed` / `general[].speed` 换算而来）
typedef SpeedLimitPoint = ({int speed, double atDistance});

/// 导航 HUD 状态管理
///
/// 数据链路（见方案 §3.1）：
/// ```
/// 分享短链 → param → restoration（路线几何 + 路况 + 动作码）
/// 本机 GPS(WGS-84) → GCJ-02 → analyzer.project() → 动作队列 / 剩余量
/// ```
/// **不轮询 `info` 接口**：本机 GPS 就是分享者位置，精度更高、无上报延迟。
///
/// 通栏展开状态由**动作队列**驱动（见方案 §2.4）：存在 `eta < 8s` 的动作即展开，
/// 仍有动作在窗口内则保持展开 —— 连续转弯期间只换内容不收回，消除抖动。
class NaviProvider extends ChangeNotifier with WidgetsBindingObserver {
  NaviProvider({
    required OBDDataProvider obdDataProvider,
    required LogProvider logProvider,
    AmapShareClient? client,
    Stream<Position> Function()? positionStreamFactory,
    Future<LocationPermissionStatus> Function()? locationGate,
    Future<Position?> Function()? firstFixProvider,
    Duration smoothTickPeriod = const Duration(milliseconds: smoothTickMs),
  })  : _obdDataProvider = obdDataProvider,
        _client = client ?? AmapShareClient(),
        _ownsClient = client == null,
        _smoothTickPeriod = smoothTickPeriod,
        _positionStreamFactory = positionStreamFactory ??
            // 采样频率由 LocationService.androidFixInterval（Android 1s/帧）
            // 显式下传 —— 不传的话 Android 回退到 5s 默认值，60km/h 下会滞后
            // 80 多米，表现为"拐过弯了还在提示前方右转"；distanceFilter 3m 只
            // 负责最小位移（拐弯/变道时更灵敏）；隧道/地库的系统级降频由
            // GPS 失联心跳兜底
            (() => LocationService.getPositionStream(distanceFilter: 3)),
        // 权限 + 系统定位服务自检（必要时会发起一次权限请求）
        _locationGate = locationGate ?? LocationService.checkAndRequestOnLaunch,
        // 即时定位：Android 的 smallestDisplacement 在**静止状态下可能不回调**，
        // 只靠流会永远"定位中"；先要一次即时定位，进页面就有位置（这也是
        // 地图类 app 的常规做法）
        _firstFixProvider = firstFixProvider ??
            (() => LocationService.getCurrentPosition()) {
    _logCallback = createLogger(logProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  // ===== 常量（方案 §2.5 / §2.4 / §3.4）=====

  /// 通栏展开阈值：队列中任一动作的预计剩余时间小于该值即展开
  static const double bannerEtaThresholdSec = 8;

  /// 通栏与导航卡共用的前方动作数量（当前大 + 后续序列）
  static const int upcomingLimit = 3;

  /// ETA 估算的速度下限（m/s），避免低速/静止时除零产生无穷大
  static const double minEtaSpeedMs = 2.0;

  /// 偏离路线判定阈值（米）
  static const double deviationThresholdMeters = 100;

  /// 连续多少次定位 offset 超阈值才判定"持续偏离"
  static const int deviationFixThreshold = 3;

  /// 偏离状态下的重新拉取节流（秒），避免每次定位都拉 228KB
  static const int deviationRefetchThrottleSec = 10;

  /// 确认"重新规划拿不到新路线"后的重试节流（秒）。
  ///
  /// 分享链接返回的是**分享时刻的快照**，重新拉取只会拿到同一条路线，
  /// 所以真正能等到新路线的唯一时机是分享者自己重新规划过。
  /// 一直以 10s 去拉同一个结果没有意义，改为慢速重试。
  static const int deviationRefetchBackoffSec = 60;

  /// 连续请求失败多少次转为 stale
  static const int staleFailureThreshold = 3;

  /// 等了多久还没有任何定位就把原因说出来（秒）
  static const int gpsFixTimeoutSec = 12;

  /// 超过多久没有新定位就把卡片标成"推算中"（秒）。
  ///
  /// 注意：**它只影响 UI 上的"推算中"标签**，不再影响是否外推 —— 里程平滑
  /// 从两帧之间就一直按 OBD 车速推进（见 [smoothTickMs]）。
  static const int gpsStaleSeconds = 5;

  /// 里程平滑 / 航位推算的心跳周期（毫秒）。
  ///
  /// 取 200ms（5Hz）：Android 定位是 1s/帧，中间用 OBD 车速把里程连续推进
  /// （"推算-校正"的推算步），于是仪表盘不再每秒"跳"17~33 米，转弯提示也
  /// 不再滞后一个采样周期；真偏离由下一次实测定位校正（见 [measured] 参数）。
  ///
  /// 静止（车速低于 [minEtaSpeedMs]）不推进，避免原地漂移。
  static const int smoothTickMs = 200;

  /// 定位龄期补偿的可信上限（秒）：`now - pos.timestamp` 超过它就放弃补偿。
  ///
  /// 正常定位龄期是数百毫秒（GNSS 解算 + 融合 + 派发）；超过 2.5s 通常意味着
  /// 时间戳不可信（时钟偏移 / 单位错 / 批处理积压），此时**宁可慢也不能凭空
  /// 多跑几十米** —— 100km/h 下 2.5s 是 69 米，足以把用户推到弯道之后。
  static const double maxFixAgeSec = 2.5;

  /// 判定"分享已停止"需要**连续几次独立探测**同向确认。
  ///
  /// 状态文档实测过"同一 param 落到不同后端节点快照不一致"（差 46 小时）与
  /// "用户空间记录比匿名分享活得短"，单次判据不足以证明此刻真的停了；而**误停
  /// 导航不可恢复**（分享链接是快照，只能重贴）。两次同向才收尾。
  static const int statusConfirmCount = 2;

  /// 分享状态心跳周期（秒）：默认、下限、上限。
  ///
  /// 行中端点响应仅 ~2.5KB（对比路线轮询 228KB/30s），所以周期可以比路线轮询短；
  /// 下限 5s 是为了避免误配成高频请求。
  static const int defaultStatusWatchSec = 15;
  static const int minStatusWatchSec = 5;
  static const int maxStatusWatchSec = 60;

  // ===== 依赖 =====
  final OBDDataProvider _obdDataProvider;
  final AmapShareClient _client;
  final bool _ownsClient;
  final Stream<Position> Function() _positionStreamFactory;
  final Future<LocationPermissionStatus> Function() _locationGate;
  final Future<Position?> Function() _firstFixProvider;

  /// 里程平滑心跳周期（默认 [smoothTickMs]）。
  ///
  /// 可注入是为了**测试确定性**：布局类用例断言的是固定里程/距离标签，而平滑
  /// 推进让"剩余 100 米"在 pump 350ms 后变成 96 米，所以那些用例把它设成足够
  /// 长以冻结推进（见 `test/widgets/navi_hud_widgets_test.dart`）；平滑本身的
  /// 用例反过来设成 20ms 以便毫秒级观察（见「里程平滑」组）。
  final Duration _smoothTickPeriod;
  SettingsProvider? _settings;
  late void Function(String source, LogType type, String message) _logCallback;

  static const String _source = 'Navi';

  // ===== 会话 =====
  NaviState _state = NaviState.off;
  String? _shareUrl;
  String? _param;
  RouteAnalyzer? _analyzer;
  String? _routeFingerprint;

  /// 限速点（按里程升序），4d 超速联动数据源
  List<SpeedLimitPoint> _speedLimits = const [];

  // ===== 定位与指引 =====
  Projection? _projection;
  String? _currentRoad;
  List<ActionPoint> _upcoming = const [];
  ({double meters, double seconds, int lights})? _remaining;
  double? _gpsAccuracy;
  DateTime? _lastFixAt;
  int? _speedLimitKmh;

  /// 最后一次**实测**定位的投影里程（米）。
  ///
  /// `_projection.distance` 会被 5Hz 平滑外推改动，所以连续性先验必须以这个
  /// 实测值为基准，否则同一段间隔会被算两遍（见 [_continuityPrior]）。
  double? _measuredDistance;

  /// 上一次用于投影的坐标（GCJ-02）。路线整体替换后用其重新投影，避免位置跳变
  /// （迁移文档坑清单 #3）。
  LonLat? _lastKnownGcj;

  /// 视窗切片的重算锚点与航向（抑制逐帧抖动）
  double? _sliceAnchorDistance;
  double? _sliceBearing;

  // ===== 通栏 =====
  bool _bannerExpanded = false;

  /// 航位推算中（隧道 / 地库无 GPS，由 OBD 车速外推）
  bool _extrapolating = false;

  // ===== 速度 =====
  double _speedKmh = 0;
  double _speedMs = minEtaSpeedMs;

  // ===== 偏离检测 =====
  int _deviationFixCount = 0;
  DateTime? _lastDeviationRefetchAt;

  /// 偏离后已确认"重新规划拿不到新路线"（分享路线是快照，指纹没变）。
  ///
  /// 置位后界面不再谎称"重新规划中"，改为提示可手动重贴短链；
  /// 重拉节流也从 10s 退到 60s。
  bool _replanFailed = false;

  // ===== 运行期 =====
  Timer? _routeTimer;
  Timer? _smoothTicker;

  // ===== 分享状态心跳（"高德那边是否已停止导航"）=====
  Timer? _statusTimer;
  bool _statusWatchOn = true;
  int _statusWatchSec = defaultStatusWatchSec;
  bool _stopOnShareEnd = true;

  /// 连续同向确认计数（见 [statusConfirmCount]）
  int _statusStrikes = 0;

  /// 已探到"停止"但因 `naviStopOnShareEnd = false` 没有收尾 —— 卡片据此提示
  bool _shareStoppedHint = false;

  /// 上一次 [start] 是否被**行前自检**拦下（"这条分享已结束"）。
  /// 供 UI 选择提示样式：这是"分享本来就没在导航"，不是用户的解析失败。
  bool _lastStartEndedShare = false;

  /// 首个定位的超时兜底（到点仍无定位就把原因说出来，而不是永远"定位中"）
  Timer? _fixTimeoutTimer;
  NaviGpsIssue _gpsIssue = NaviGpsIssue.none;
  StreamSubscription<Position>? _gpsSub;
  int _routeRefreshSec = 30;
  int _failureCount = 0;
  DateTime? _lastSmoothTickAt;

  // ===== 诊断计数 =====
  int _routeRefreshCount = 0;
  int _routeUnchangedCount = 0;
  int _gpsFixCount = 0;
  int _errorCount = 0;
  int _statusProbeCount = 0;
  int _statusProbeFailureCount = 0;

  /// 定位健康度诊断（累计 5 帧后记一条日志）。
  ///
  /// 真机排查"导航滞后"先看这一行：采样间隔正常 ≈1000ms、定位龄期正常 <500ms；
  /// 若明显更大，说明 Android 的 `intervalDuration` 没生效或系统在降频。
  int _fixIntervalSamples = 0;
  int _fixIntervalSumMs = 0;
  int _fixAgeSamples = 0;
  int _fixAgeSumMs = 0;
  bool _fixIntervalLogged = false;

  String? _errorMessage;
  bool _suspended = false;

  // ===== Getter（暴露状态，不使用直接字段访问）=====

  NaviState get state => _state;
  String? get shareUrl => _shareUrl;
  String? get errorMessage => _errorMessage;
  String? get currentRoad => _currentRoad;
  Projection? get projection => _projection;
  List<ActionPoint> get upcomingActions => _upcoming;
  ActionPoint? get nextAction => _upcoming.isEmpty ? null : _upcoming.first;
  ({double meters, double seconds, int lights})? get remaining => _remaining;
  bool get bannerExpanded => _bannerExpanded;
  bool get extrapolating => _extrapolating;
  double? get gpsAccuracy => _gpsAccuracy;
  DateTime? get lastFixAt => _lastFixAt;
  int? get speedLimitKmh => _speedLimitKmh;
  double get speedKmh => _speedKmh;
  double get speedMs => _speedMs;
  double? get traveledDistance => _projection?.distance;
  double? get offsetMeters => _projection?.offset;
  double? get totalDistance => _analyzer?.totalDistance;
  int get routeRefreshSec => _routeRefreshSec;
  int get routeRefreshCount => _routeRefreshCount;

  /// 路线脏检查命中次数（无实质变化，跳过重建）
  int get routeUnchangedCount => _routeUnchangedCount;

  /// 偏离后重拉仍未拿到新路线（分享链接是快照）。
  ///
  /// UI 据此把"重新规划中…"换成实话：无法重新规划，可点卡片重贴短链。
  bool get replanFailed => _replanFailed;

  /// 为什么还没定位（`locating` 态下 UI 必须说实话）
  NaviGpsIssue get gpsIssue => _gpsIssue;

  /// 定位问题是否属于"需要用户去系统设置处理"
  bool get gpsNeedsSettings =>
      _gpsIssue == NaviGpsIssue.denied ||
      _gpsIssue == NaviGpsIssue.deniedForever ||
      _gpsIssue == NaviGpsIssue.serviceDisabled;
  int get gpsFixCount => _gpsFixCount;
  int get errorCount => _errorCount;

  /// 已探到"分享已停止"，但因 `naviStopOnShareEnd = false` 选择继续导航。
  ///
  /// 卡片据此提示"已停止"，让用户知道指引已不再来自高德那边（而不是静默继续）。
  bool get shareStoppedHint => _shareStoppedHint;

  /// 上一次 [start] 被行前自检拦下（"这条分享已结束，未开始导航"）。
  ///
  /// 供粘贴弹窗区分提示：这种情况**不弹终态卡**，只给一个 warning 级提示，
  /// 卡片保持关闭（回默认的轨迹雷达面板）。
  bool get lastStartEndedShare => _lastStartEndedShare;

  /// 分享状态心跳周期（秒）
  int get statusWatchSec => _statusWatchSec;

  /// 状态探测次数 / 失败次数（探测失败不算"已停止"，只计数）
  int get statusProbeCount => _statusProbeCount;
  int get statusProbeFailureCount => _statusProbeFailureCount;

  /// 实测定位采样间隔均值（毫秒）；样本不足时返回 null。
  ///
  /// 正常值应在 1000ms 上下（`LocationService.androidFixInterval`）。
  int? get gpsFixIntervalMs => _fixIntervalSamples == 0
      ? null
      : (_fixIntervalSumMs / _fixIntervalSamples).round();

  /// 实测定位龄期均值（毫秒，= 送达时刻 − 采集时刻）；样本不足时返回 null。
  ///
  /// 这段是"采样间隔之外"的固有延迟（GNSS 解算 + 融合 + 派发），
  /// 由 [_compensateFixAge] 用当前车速前推掉，正常 <500ms。
  int? get gpsFixAgeMs =>
      _fixAgeSamples == 0 ? null : (_fixAgeSumMs / _fixAgeSamples).round();
  /// 是否为"正在跑的会话"。
  ///
  /// 终态已收敛为 `off` 一个（见 [_endSession]）：分享失效 / 高德那边停了都**静默
  /// 收尾**回 `off`，不再有"已结束"的终态卡，所以这里只需排除 `off`。
  bool get isActive => _state != NaviState.off;

  /// 是否配置了路线（UI 据此决定第三列挂导航卡还是轨迹雷达）
  bool get hasSession => _state != NaviState.off;

  /// 已行驶比例 0..1
  double get progress {
    final total = _analyzer?.totalDistance ?? 0;
    if (total <= 0) return 0;
    return ((_projection?.distance ?? 0) / total).clamp(0.0, 1.0);
  }

  /// 当前 OBD 车速是否超过最近生效的限速（超速语义见方案 §2.8）
  bool get isSpeeding {
    final limit = _speedLimitKmh;
    if (limit == null || limit <= 0) return false;
    return _speedKmh > limit;
  }

  /// 动作 [a] 的预计剩余时间（秒）
  double etaSeconds(ActionPoint a) {
    final ahead = a.atDistance - (_projection?.distance ?? 0);
    return ahead / _speedMs;
  }

  /// 导航卡与通栏当前应展示的动作点。
  ///
  /// 有投影时取队列第一个；E1（定位中）退化为路线首个动作 —— 箭头来自
  /// **路线切线方向，不依赖定位**（方案 §2.6 E1）。
  ///
  /// 界面请优先用它（而不是只取动作码）：`0` 码需要上下文才能区分
  /// "无基本导航动作"与终点段的"到达"（见 `naviTurnTypeOfAction`）。
  ActionPoint? get displayAction {
    if (_upcoming.isNotEmpty) return _upcoming.first;
    final analyzer = _analyzer;
    if (analyzer == null || analyzer.actions.isEmpty) return null;
    final d = _projection?.distance;
    if (d == null) return analyzer.actions.first;
    return analyzer.lastPassedAction(d) ?? analyzer.actions.last;
  }

  /// 导航卡与通栏当前应展示的动作码
  int? get displayActionCode => displayAction?.actionCode;

  /// 距下一个动作还有多少米；无投影时为 null（E1 显示"--"）
  double? get distanceToNextAction {
    final next = nextAction;
    final d = _projection?.distance;
    if (next == null || d == null) return null;
    return math.max(0, next.atDistance - d);
  }

  /// 导航卡底图用：以当前位置为锚点的真实路线切片（heading-up 绘制）
  RouteSlice get routeSlice => _routeSlice ?? RouteSlice.empty;
  RouteSlice? _routeSlice;

  /// 底图上的点标记（红绿灯 / 限速点）
  List<RouteMarker> get routeMarkers => _routeMarkers;
  List<RouteMarker> _routeMarkers = const [];

  /// 底图前方视窗里程（米）
  int get mapAheadMeters => _mapAheadMeters;
  int _mapAheadMeters = defaultMapAheadMeters;

  /// 是否给底图叠加路况着色
  bool get routeTrafficColor => _routeTrafficColor;
  bool _routeTrafficColor = false;

  /// 剩余时间是"预计到达时刻"还是"剩余时长"
  bool get etaAsClock => _etaMode == 'clock';
  String _etaMode = 'clock';

  /// 其剩余时间显示方式设置值（`clock` / `duration`）
  String get etaMode => _etaMode;

  static const int defaultMapAheadMeters = 300;

  /// 视窗锚点（里程，米）：只有挪动超过该距离才重算切片，避免每帧抖动
  static const double sliceAnchorStepMeters = 8;

  /// 视窗航向死区（弧度，约 6°）：转向角小于它时沿用上一次切片
  static const double sliceBearingDeadbandRad = 0.105;

  /// 切片时保留的后方里程（米）：给出"刚从哪来"的方向感
  static const double sliceBehindMeters = 40;

  /// 由 main.dart 的 ProxyProvider 注入（与 OBDDataProvider 同模式）
  void updateSettings(SettingsProvider? settings) {
    _settings = settings;
    if (settings == null) return;
    final sec = settings.naviRouteRefreshSec;
    if (sec != _routeRefreshSec) {
      _routeRefreshSec = sec;
      if (_routeTimer != null) _startRouteTimer();
    }
    _mapAheadMeters = settings.naviMapAheadMeters;
    _routeTrafficColor = settings.naviRouteTrafficColor;
    _etaMode = settings.naviEtaMode;

    // 分享状态心跳：周期/开关变化要重建定时器
    final watchOn = settings.naviShareStatusWatchOn;
    final watchSec =
        settings.naviShareStatusWatchSec.clamp(minStatusWatchSec, maxStatusWatchSec);
    _stopOnShareEnd = settings.naviStopOnShareEnd;
    if (watchOn != _statusWatchOn || watchSec != _statusWatchSec) {
      _statusWatchOn = watchOn;
      _statusWatchSec = watchSec;
      if (_statusTimer != null) _startStatusWatch();
    }
  }

  /// 设置底图前方视窗里程（米），持久化并立即生效
  void setMapAheadMeters(int meters) {
    final clamped = meters.clamp(100, 2000);
    if (clamped == _mapAheadMeters) return;
    _mapAheadMeters = clamped;
    _settings?.setNaviMapAheadMeters(clamped);
    _sliceAnchorDistance = null; // 强制重算
    _rebuildRouteSlice();
    notifyListeners();
  }

  /// 测试钩子：当前路线模型（用于在测试里由里程反查坐标）
  @visibleForTesting
  RouteAnalyzer? get debugAnalyzer => _analyzer;

  /// 测试钩子：手动触发一次路线刷新，避免测试真等一个轮询周期
  @visibleForTesting
  Future<void> debugRefreshRouteNow() => _refreshRoute();

  /// 测试钩子：手动触发一次分享状态探测（避免测试真等一个心跳周期）
  @visibleForTesting
  Future<void> debugStatusProbeNow() => _onStatusProbe();

  // ==========================================================================
  // 生命周期：开始 / 停止 / 前台后台
  // ==========================================================================

  /// 解析分享短链并开始导航；返回是否成功启动。
  ///
  /// **失败一律静默收尾回 `off`**（见 [_endSession]）：短链解析不出来、接口明确
  /// 判失效、空路线……都不摆终态卡，第三列保持默认的轨迹雷达卡；原因留在
  /// [errorMessage] 供调用方（粘贴弹窗）弹一条 toast。
  ///
  /// **行前自检**：解析出 `param` 后、拉路线之前，先用状态端点问一句"这条分享
  /// 还在导航吗"。已结束则**同样不建立会话**（状态停在 `off`，卡片保持关闭），
  /// 只通过 [lastStartEndedShare] / [errorMessage] 给调用方一个提示 —— 不把用户
  /// 已经结束的行程拉起来、更不展示任何"导航已结束"。见 [_shareAlreadyEndedAtStart]。
  ///
  /// 两个开关与心跳同一套语义：[naviShareStatusWatchOn] 是总闸（关掉就完全不探），
  /// [naviStopOnShareEnd] 关了则照常启动、只把 [shareStoppedHint] 置上。
  Future<bool> start(String shareUrl) async {
    final url = shareUrl.trim();
    if (url.isEmpty) {
      _errorCount++;
      _errorMessage = '分享短链为空';
      notifyListeners();
      return false;
    }

    // 清理上一次会话，保证零残留
    await stop();
    _shareUrl = url;
    _errorMessage = null;
    _log(LogType.info, '开始解析分享短链：$url');
    // 注意：这里**先不发 `locating`**。若这是一条已结束的分享，卡片一秒都不该出现
    // （见下面的行前自检）—— 解析短链与自检都是短请求，正常路径下用户几乎无感。

    try {
      final param = await _client.resolveParam(url);
      _param = param;

      // 行前自检：高德那边如果**已经**停了导航，就别把卡片拉起来再显示"已结束"。
      // 用户要的是"直接关闭导航卡片、恢复默认面板"，而不是一张终态卡。
      // 受两个开关管辖，与心跳同一套语义：`naviShareStatusWatchOn` 关了就整个不探；
      // `naviStopOnShareEnd` 关了（用户明确要"高德停了也继续"）则照常启动、只提示。
      if (_statusWatchOn && await _shareAlreadyEndedAtStart(param)) {
        if (_stopOnShareEnd) {
          await stop(); // 全量清零（含 _param / 定时器），保证零残留
          _errorMessage = '这条分享已结束，未开始导航';
          _lastStartEndedShare = true;
          _log(LogType.info, '行前自检：该分享已结束，不建立导航会话');
          notifyListeners();
          return false;
        }
        _shareStoppedHint = true; // 照常启动，但卡片要如实提示"高德那边已停止"
        _log(LogType.warning,
            '行前自检：该分享已结束，但 naviStopOnShareEnd=false，照常启动');
      }

      _state = NaviState.locating; // 确认要建会话后才给 UI 反馈
      notifyListeners();

      final env = await _client.fetchRoute(param);

      if (env.code != '1') {
        await _endSession('分享链接已失效（code=${env.code}）');
        return false;
      }
      if (env.route.paths.isEmpty) {
        // 接口异常返回空路线：不建空会话，直接失败
        _errorCount++;
        _state = NaviState.off;
        _errorMessage = '接口返回空路线（paths 为空）';
        _log(LogType.error, _errorMessage!);
        _stopRuntime();
        notifyListeners();
        return false;
      }

      _adoptRoute(env.route, initial: true);

      _state = NaviState.locating; // 路线就绪，等首个定位
      _failureCount = 0;
      _log(
        LogType.success,
        '路线就绪 distance=${_analyzer!.totalDistance.toStringAsFixed(0)}m '
        'links=${_analyzer!.links.length} segments=${_analyzer!.segments.length} '
        'actions=${_analyzer!.actions.length} 自检=${_analyzer!.lengthConsistent ? "通过" : "不一致"}',
      );

      _startRouteTimer();
      await _startGps();
      _startStatusWatch();
      notifyListeners();
      return true;
    } on ShareLinkException catch (e) {
      await _endSession(e.message);
      return false;
    } on ShareApiException catch (e) {
      // 接口明确返回失败（result=false）——按分享失效处理
      await _endSession(e.message);
      return false;
    } catch (e) {
      _errorCount++;
      _state = NaviState.off;
      _errorMessage = '路线获取失败：$e';
      _log(LogType.error, _errorMessage!);
      _stopRuntime();
      notifyListeners();
      return false;
    }
  }

  /// 手动粘贴入口：与 [start] 同义，语义上更明确。
  Future<bool> startFromShareUrl(String shareUrl) => start(shareUrl);

  /// 停止导航，释放全部定时器与订阅，回到 `off`（方案 §2.7 零残留）
  Future<void> stop() async {
    _stopRuntime();
    _shareUrl = null;
    _param = null;
    _analyzer = null;
    _routeFingerprint = null;
    _speedLimits = const [];
    _projection = null;
    _currentRoad = null;
    _upcoming = const [];
    _remaining = null;
    _bannerExpanded = false;
    _extrapolating = false;
    _statusStrikes = 0;
    _shareStoppedHint = false;
    _lastStartEndedShare = false;
    _speedLimitKmh = null;
    _speedKmh = 0;
    _speedMs = minEtaSpeedMs;
    _gpsAccuracy = null;
    _lastFixAt = null;
    _lastSmoothTickAt = null;
    _measuredDistance = null;
    _lastKnownGcj = null;
    _routeSlice = null;
    _routeMarkers = const [];
    _sliceAnchorDistance = null;
    _sliceBearing = null;
    _deviationFixCount = 0;
    _lastDeviationRefetchAt = null;
    _replanFailed = false;
    _gpsIssue = NaviGpsIssue.none;
    _failureCount = 0;
    _fixIntervalSamples = 0;
    _fixIntervalSumMs = 0;
    _fixAgeSamples = 0;
    _fixAgeSumMs = 0;
    _fixIntervalLogged = false;
    _state = NaviState.off;
    _errorMessage = null;
    notifyListeners();
  }

  /// 切换路线刷新间隔（秒）并持久化到设置
  void setRouteRefreshSec(int sec) {
    final clamped = sec.clamp(10, 120);
    if (clamped == _routeRefreshSec && _routeTimer != null) return;
    _routeRefreshSec = clamped;
    _settings?.setNaviRouteRefreshSec(clamped);
    if (_routeTimer != null) _startRouteTimer();
    _log(LogType.info, '路线刷新间隔改为 ${clamped}s');
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _suspend();
    } else if (state == AppLifecycleState.resumed) {
      _resume();
    }
  }

  /// 后台：停轮询与 GPS 订阅（保留会话状态与最后路线）
  void _suspend() {
    if (_suspended || !isActive) return;
    _suspended = true;
    _routeTimer?.cancel();
    _routeTimer = null;
    _smoothTicker?.cancel();
    _smoothTicker = null;
    _statusTimer?.cancel();
    _statusTimer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    _log(LogType.info, '应用进入后台，暂停路线轮询 / 状态心跳与 GPS 订阅');
  }

  /// 回前台：立即补一次路线刷新与定位订阅
  void _resume() {
    if (!_suspended) return;
    _suspended = false;
    if (!isActive) return;
    _log(LogType.info, '应用回到前台，恢复路线轮询与 GPS 订阅');
    _startRouteTimer();
    _startSmoothTicker();
    _startStatusWatch();
    _startGps();
    unawaited(_refreshRoute());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRuntime();
    if (_ownsClient) _client.close();
    super.dispose();
  }

  void _stopRuntime() {
    _routeTimer?.cancel();
    _routeTimer = null;
    _smoothTicker?.cancel();
    _smoothTicker = null;
    _statusTimer?.cancel();
    _statusTimer = null;
    _fixTimeoutTimer?.cancel();
    _fixTimeoutTimer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    _suspended = false;
  }

  // ==========================================================================
  // 路线
  // ==========================================================================

  void _adoptRoute(AmapRoute route, {bool initial = false}) {
    _routeFingerprint = fingerprintOf(route);
    _analyzer = RouteAnalyzer(route);
    _speedLimits = extractSpeedLimits(_analyzer!);
    // 路线换了，视窗切片必须整体重算（锚点里程也可能变）
    _sliceAnchorDistance = null;
    _sliceBearing = null;
    if (!initial) {
      // 路线整体替换后用最后一次已知坐标重新投影（坑清单 #3）
      _reprojectKnown();
    } else {
      _rebuildRouteSlice(); // E1：先给出以起点为锚点的底图
    }
  }

  /// 路线指纹：`version + 里程 + link 数 + 几何点数`，覆盖"重新规划"会变动的全部
  /// 维度，且不需要构建 RouteAnalyzer。用于脏检查（方案 §4 流量）。
  static String fingerprintOf(AmapRoute route) {
    if (route.paths.isEmpty) return '${route.version}|empty';
    final p = route.main;
    final linkCount = p.segments.fold<int>(0, (a, s) => a + s.links.length);
    return '${route.version}|${p.distance}|$linkCount|${p.coords.length}';
  }

  void _startRouteTimer() {
    _routeTimer?.cancel();
    _routeTimer = Timer.periodic(
      Duration(seconds: _routeRefreshSec),
      (_) => unawaited(_refreshRoute()),
    );
  }

  Future<void> _refreshRoute() async {
    final param = _param;
    if (param == null || _analyzer == null) return;
    _routeRefreshCount++;
    try {
      final env = await _client.fetchRoute(param);
      _failureCount = 0;

      if (env.code != '1') {
        await _endSession('分享链接已失效（code=${env.code}）');
        return;
      }

      final fingerprint = fingerprintOf(env.route);
      if (fingerprint == _routeFingerprint && _analyzer != null) {
        _routeUnchangedCount++;
        // 偏离状态下重拉还是同一条路线 → 分享链接是快照，"重新规划"不可能成功。
        // 必须让界面说实话（否则就是无限"重新规划中…"，真机反馈过这个 bug）。
        if (_state == NaviState.deviated && !_replanFailed) {
          _replanFailed = true;
          _log(
            LogType.warning,
            '重新规划失败：分享路线是分享时刻的快照，内容未变化'
            '（后续改为每 ${deviationRefetchBackoffSec}s 慢速重试；'
            '分享者重新规划后才会有新路线）',
          );
        }
        if (_state == NaviState.stale) {
          _state = _projection == null ? NaviState.locating : NaviState.navigating;
        }
        notifyListeners();
        return;
      }

      _replanFailed = false; // 真拿到了新路线
      _adoptRoute(env.route);
      if (_state == NaviState.stale) {
        _state = _projection == null ? NaviState.locating : NaviState.navigating;
      }
      _log(
        LogType.info,
        '路线刷新 #$_routeRefreshCount：内容变化 → 重建 '
        'distance=${_analyzer!.totalDistance.toStringAsFixed(0)}m',
      );
      notifyListeners();
    } catch (e) {
      if (e is ShareApiException) {
        await _endSession(e.message);
        return;
      }
      _errorCount++;
      _failureCount++;
      _log(LogType.warning, '路线刷新失败（连续 $_failureCount 次）：$e');
      if (_failureCount >= staleFailureThreshold && _analyzer != null) {
        _state = NaviState.stale; // 保留最后路线，不静默消失
      }
      notifyListeners();
    }
  }

  /// 路线替换后，用最后一次已知坐标重新投影，避免等下一次定位才刷新
  void _reprojectKnown() {
    final analyzer = _analyzer;
    final gcj = _lastKnownGcj;
    if (analyzer == null || gcj == null) return;
    final projection = analyzer.project(gcj.lon, gcj.lat);
    // 新几何上的里程同时作为连续性先验的新基准
    _measuredDistance = projection.distance;
    _applyProjection(projection);
    _log(LogType.info, '路线变化后重新投影 dist=${_projection?.distance.toStringAsFixed(0)}m');
    notifyListeners();
  }

  // ==========================================================================
  // 分享状态心跳：高德那边是否已停止导航
  // ==========================================================================
  //
  // 为什么需要：本机 GPS 只知道"我在哪"，永远不知道分享者（用户自己）在高德里
  // 停止了导航。没有这个信号时，里程会一直投影到那条**已冻结**的旧路线上，
  // 骑手拐进别的路甚至回了家，卡片还在报"前方 X 米转弯"。
  //
  // 数据来源是两个端点的**两个不同字段**（详见 amap-user-route-share-info.md §5.1）：
  //   行中 POST /ws/share/lbs/info          -> data.shareInfo.shareStatus（1/5/7/6）
  //   行前 GET  /ws/user/route/share/info   -> data.status（1/4/2/3）、code 10001 已过期

  void _startStatusWatch() {
    _statusTimer?.cancel();
    _statusTimer = null;
    if (!_statusWatchOn) {
      _log(LogType.info, '分享状态心跳已关闭（设置项 naviShareStatusWatchOn）');
      return;
    }
    _statusTimer = Timer.periodic(
      Duration(seconds: _statusWatchSec),
      (_) => unawaited(_onStatusProbe()),
    );
  }

  /// 一次**两步求证**的分享状态探测（主判据 + 复核）。
  ///
  /// `unknown`（取值不认识、字段缺失、`code=2/3` 参数问题）与传输层失败一律
  /// 返回 `null` —— 调用方按"探测不到 ≠ 已停止"处理，绝不据此改状态。
  Future<({ShareAlive alive, String detail})?> _probeShareAlive(
    String param,
  ) async {
    try {
      // ① 主判据：行中端点（响应仅 ~2.5KB）。我们的 param 与非洲路线都来自
      //    行中族端点，所以这里是常态路径。
      final navi = await _client.probeNaviStatus(param);
      if (navi.alive != ShareAlive.unknown) {
        return (
          alive: navi.alive,
          detail: '行中 shareStatus=${navi.shareStatus ?? "无"}',
        );
      }
      // ② 复核：行中端点给不出结论（例如 param 只在行前族有效）时问行前端点。
      final before = await _client.fetchShareStatus(param);
      return (
        alive: before.alive,
        detail: '行前 status=${before.status ?? "无"} code=${before.code}',
      );
    } catch (e) {
      // 网络/传输层失败：只计数与记日志，**绝不改状态**
      _statusProbeFailureCount++;
      _log(LogType.info, '分享状态探测失败（忽略，不改状态）：$e');
      return null;
    }
  }

  /// 一次状态心跳：只有"明确判据"（[ShareAlive.stopped] / [ShareAlive.expired]）
  /// 才计数；`unknown` 一律清零计数并什么都不做。
  Future<void> _onStatusProbe() async {
    if (!isActive) return;
    final param = _param;
    if (param == null) return;
    _statusProbeCount++;

    final probe = await _probeShareAlive(param);
    if (probe == null) return; // 探测不到 → 不动状态
    if (!isActive) return; // 探测期间会话可能已结束
    _applyStatusVerdict(probe.alive, probe.detail);
  }

  /// **行前自检**：打开 App 刚粘贴（或回前台补一次自动同步）时，先问一句
  /// "这条分享现在还在导航吗？"
  ///
  /// 返回 true = 已经明确结束，调用方**直接不建立会话**（状态停在 `off`、卡片保持
  /// 关闭、回默认面板），而不是把整条路线拉起来再收尾 —— 用户根本没开始导航，
  /// 任何"已结束"的提示都会让他以为自己操作错了。
  ///
  /// 判据与心跳完全一致（[statusConfirmCount] 次同向确认），并沿用
  /// "**探测不到 ≠ 已停止**"：只要任一次给不出结论，就当作还活着、照常启动。
  Future<bool> _shareAlreadyEndedAtStart(String param) async {
    for (var i = 0; i < statusConfirmCount; i++) {
      final probe = await _probeShareAlive(param);
      if (probe == null) return false; // fail-open：探不到就照常启动
      final dead = probe.alive == ShareAlive.stopped ||
          probe.alive == ShareAlive.expired;
      if (!dead) {
        if (i > 0) {
          _log(LogType.info,
              '行前自检：${probe.detail} → ${probe.alive.name}，照常启动');
        }
        return false; // 还在导航 / 还没开始导航 → 照常启动
      }
      _log(
        LogType.info,
        '行前自检：${probe.detail} → ${probe.alive.name}'
        '（第 ${i + 1}/$statusConfirmCount 次确认）',
      );
    }
    return true;
  }

  /// 归一结果落地：连续同向确认 → 收尾。
  void _applyStatusVerdict(ShareAlive alive, String detail) {
    switch (alive) {
      case ShareAlive.stopped:
      case ShareAlive.expired:
        _statusStrikes++;
        _log(
          LogType.info,
          '分享状态：$detail → ${alive.name}'
          '（第 $_statusStrikes/$statusConfirmCount 次确认）',
        );
        if (_statusStrikes < statusConfirmCount) return;
        if (!_stopOnShareEnd) {
          // 用户关掉了"停止即收尾"：只提示，不掐导航（可能只是想按这条路继续骑）
          if (!_shareStoppedHint) {
            _shareStoppedHint = true;
            _log(LogType.warning, '高德导航已停止，但 naviStopOnShareEnd=false，继续导航');
            notifyListeners();
          }
          return;
        }
        // 已连续确认：静默收尾回默认面板（不摆"导航已结束"终态卡）
        unawaited(_endSession(
          alive == ShareAlive.expired
              ? '该分享已过期（$detail）'
              : '高德那边已停止导航（$detail）',
        ));
      case ShareAlive.waiting:
      case ShareAlive.navigating:
        if (_statusStrikes != 0) {
          _log(LogType.info, '分享状态恢复：$detail → ${alive.name}，确认计数清零');
        }
        _statusStrikes = 0;
      case ShareAlive.unknown:
        // 不确认就打断"连续确认"链（半途的 unknown 说明快照不稳定）
        _statusStrikes = 0;
    }
  }

  /// **静默收尾**：分享失效 / 该分享已过期 / 高德那边停止了导航。
  ///
  /// 三种情况都**不摆"导航已结束"终态卡**，直接全量清零回 `off` ⇒ `hasSession`
  /// 为 false ⇒ 第三列渲染回默认的轨迹雷达卡（"直接恢复原来的样子"）。
  /// 只留一条日志（以及 [errorMessage]，供粘贴弹窗在 `start()` 失败时复用）。
  ///
  /// 收尾是幂等的：会话本来就没建起来（`start()` 早期失败）时，`stop()` 只是再
  /// 清零一次，但仍然要把原因写进 [errorMessage] 并通知一次，粘贴弹窗才会说实话。
  Future<void> _endSession(String message) async {
    await stop(); // 全量清零：路线轮询 / GPS 订阅 / 状态心跳 / 平滑 / 各计数
    _errorCount++;
    _errorMessage = message;
    _log(LogType.warning, '结束导航（静默，不摆终态卡）：$message');
    notifyListeners();
  }

  // ==========================================================================
  // 定位
  // ==========================================================================

  Future<void> _startGps() async {
    _gpsSub?.cancel();
    _gpsIssue = NaviGpsIssue.none;

    // ① 权限 / 系统定位服务自检：缺失时立刻说实话并给出出口，
    //    而不是订阅一个永远不会来数据的流、界面停在"定位中…"。
    //    **仍然继续订阅**：用户去设置里打开权限/定位后能自动恢复。
    final status = await _checkLocationGate();
    if (status != null && status != LocationPermissionStatus.granted) {
      _gpsIssue = _issueOf(status);
      _errorCount++;
      _log(
        LogType.warning,
        '定位不可用：${gpsIssueLabel(_gpsIssue)}'
        '（仍保持订阅，用户处理后自动恢复）',
      );
      notifyListeners();
    }

    // ② 先要一次"即时定位"：Android 的 smallestDisplacement 在静止状态下
    //    可能一直不回调，只靠流会永远停在定位中（高德等地图 app 同样先取即时定位）
    unawaited(_primeWithFirstFix());

    // ③ 订阅持续定位流
    try {
      _gpsSub = _positionStreamFactory().listen(
        _onGpsPosition,
        onError: (Object e) {
          _errorCount++;
          _gpsIssue = NaviGpsIssue.streamError;
          _log(LogType.warning, 'GPS 流出错：$e');
          notifyListeners();
        },
      );
    } catch (e) {
      // 权限被拒时部分平台会在建流阶段直接抛异常
      _errorCount++;
      _gpsIssue = NaviGpsIssue.streamError;
      _log(LogType.error, '定位流建立失败：$e');
      notifyListeners();
    }
    _startSmoothTicker();
    _startFixTimeout();
  }

  static NaviGpsIssue _issueOf(LocationPermissionStatus s) => switch (s) {
        LocationPermissionStatus.serviceDisabled => NaviGpsIssue.serviceDisabled,
        LocationPermissionStatus.deniedForever => NaviGpsIssue.deniedForever,
        LocationPermissionStatus.denied => NaviGpsIssue.denied,
        LocationPermissionStatus.granted => NaviGpsIssue.none,
      };

  /// 界面与日志共用的人话描述
  static String gpsIssueLabel(NaviGpsIssue issue) => switch (issue) {
        NaviGpsIssue.none => '正常',
        NaviGpsIssue.serviceDisabled => '系统定位服务未开启',
        NaviGpsIssue.denied => '定位权限被拒绝',
        NaviGpsIssue.deniedForever => '定位权限被永久拒绝，需去系统设置授权',
        NaviGpsIssue.streamError => '定位流出错',
        NaviGpsIssue.noFixYet =>
          '已等待 $gpsFixTimeoutSec 秒仍无定位（信号弱 / 室内 / 遮挡）',
      };

  /// 权限自检；异常或超时都不阻断（当作"无法判定"，由超时兜底负责说话）。
  ///
  /// **必须加超时**：`start()` 会 await 这里，平台调用一旦卡住，
  /// 会话就永远进不了下一步 —— 那正是"一直定位中"的另一种成因。
  Future<LocationPermissionStatus?> _checkLocationGate() async {
    try {
      return await _locationGate().timeout(const Duration(seconds: 3));
    } catch (e) {
      _log(LogType.warning, '定位权限自检失败（忽略，继续尝试定位）：$e');
      return null;
    }
  }

  /// 取一次即时定位（失败/超时只记日志，不改变状态）
  Future<void> _primeWithFirstFix() async {
    try {
      final pos = await _firstFixProvider().timeout(const Duration(seconds: 12));
      if (pos == null) {
        _log(LogType.warning, '即时定位返回空（等待定位流）');
        return;
      }
      if (_state == NaviState.off) return; // 期间已停止
      _log(LogType.info, '即时定位到达：accuracy=${pos.accuracy.toStringAsFixed(1)}m');
      _onGpsPosition(pos);
    } catch (e) {
      _log(LogType.warning, '即时定位失败（忽略）：$e');
    }
  }

  /// 首个定位超时兜底：到点仍无定位 → 换成实话，不再只说"定位中"
  void _startFixTimeout() {
    _fixTimeoutTimer?.cancel();
    _fixTimeoutTimer = Timer(const Duration(seconds: gpsFixTimeoutSec), () {
      if (_lastFixAt != null || _state == NaviState.off) return;
      _gpsIssue = NaviGpsIssue.noFixYet;
      _log(LogType.warning, '首个定位超时：${gpsIssueLabel(NaviGpsIssue.noFixYet)}');
      notifyListeners();
    });
  }

  /// 里程平滑心跳（5Hz）：两次定位之间用当前车速把里程连续推进，
  /// GPS 长时间不来时同一套逻辑自然退化为航位推算外推（方案 §4 隧道 / 无 GPS）。
  void _startSmoothTicker() {
    _smoothTicker?.cancel();
    _smoothTicker = Timer.periodic(
      _smoothTickPeriod,
      (_) => _onSmoothTick(),
    );
  }

  /// "推算-校正"的**推算步**：`_lastSmoothTickAt` 起按当前车速前推里程。
  ///
  /// 与旧实现的区别：不再等 GPS 失联 5 秒才开始外推 —— 每一帧定位结束后就
  /// 接着推，于是 Android 1s/帧的采样间隙里画面是平滑移动而不是每秒跳一次，
  /// 转弯提示也不再滞后一个采样周期。误差由下一帧实测定位**校正**
  /// （`_onGpsPosition` 整体覆盖里程），偏差被限制在一个采样周期内（≤1s 车程）。
  ///
  /// 护栏见 [_advanceProjection]。
  void _onSmoothTick() {
    final analyzer = _analyzer;
    final lastFix = _lastFixAt;
    if (analyzer == null || lastFix == null || _projection == null) return;

    // 车速优先取 OBD 实时值：OBD 的轮询频率高于 1Hz 的 GPS 帧，
    // 能跟上加减速（GPS 兜底值只在两帧之间保持上一次的）
    final obdKmh = _obdDataProvider.data.speed.toDouble();
    if (obdKmh > 1) _speedKmh = obdKmh;
    _speedMs = math.max(_speedKmh / 3.6, minEtaSpeedMs);

    final now = DateTime.now();
    var dirty = false;

    // "推算中"只表示**定位本身过期**（>gpsStaleSeconds），与是否平滑推进无关
    final stale = now.difference(lastFix).inSeconds >= gpsStaleSeconds;
    if (stale != _extrapolating) {
      _extrapolating = stale;
      dirty = true;
    }

    final ref = _lastSmoothTickAt ?? lastFix;
    _lastSmoothTickAt = now;
    final dt = now.difference(ref).inMicroseconds / 1e6;

    if (_advanceProjection(dt)) dirty = true;

    // 通栏的展开条件是"队列里有动作的 ETA < 8 秒"，而 ETA 与车速有关：
    // 20 米外 30km/h（2.4s，展开）一路刹到 5km/h（10s）时里程几乎不动，
    // 但通栏必须收回 —— 否则会在路口前一直挂着。
    if (_updateBannerExpansion()) dirty = true;

    if (dirty) notifyListeners();
  }

  void _onGpsPosition(Position pos) {
    final analyzer = _analyzer;
    if (analyzer == null) return;

    // GPS 原始坐标为 WGS-84，高德 coords 为 GCJ-02，投影前必须转换，
    // 否则会有 100~600m 的系统性偏移（迁移文档坑清单 #12）
    final gcj = GeocodingService.wgs84ToGcj02(pos.latitude, pos.longitude);
    final now = DateTime.now();
    final prevFixAt = _lastFixAt; // 上一帧的**送达**时刻（采样间隔诊断用）
    final prior = _continuityPrior(prevFixAt);
    _lastKnownGcj = LonLat(gcj[1], gcj[0]);
    _gpsFixCount++;
    _lastFixAt = now;
    _lastSmoothTickAt = now;
    _extrapolating = false;
    _gpsAccuracy = pos.accuracy;
    // 拿到定位即清掉"等不到定位"的告警
    _fixTimeoutTimer?.cancel();
    _fixTimeoutTimer = null;
    _gpsIssue = NaviGpsIssue.none;

    // 车速优先取 OBD（实时、隧道内也有），GPS 兜底（方案 §2.5）
    final obdKmh = _obdDataProvider.data.speed.toDouble();
    final gpsKmh = pos.speed > 0 ? pos.speed * 3.6 : 0.0;
    _speedKmh = obdKmh > 1 ? obdKmh : gpsKmh;

    // 校正步：实测投影覆盖推算值
    final projection = analyzer.project(
      gcj[1],
      gcj[0],
      nearDistance: prior.anchor,
      windowAhead: prior.windowAhead,
    );
    _measuredDistance = projection.distance;
    _applyProjection(projection);

    // 补偿步：把"采集时刻 → 送达时刻"这段用当前车速前推掉。
    // 手机在弯道里收到的定位往往已经是几百毫秒前的车位置（GNSS 解算 + 融合 +
    // 派发），只从"收到时刻"起算就会**一直落后一个定位龄期** —— 100km/h 下
    // 300ms 就是 8 米，最坏 1 秒就是 28 米，正是"进弯了还差几十米"的来源。
    // 定位龄期取自 pos.timestamp（Android = Location.getTime()，
    // iOS = CLLocation.timestamp，两端都是**采集时刻**）。
    final ageSeconds = _compensateFixAge(now, pos.timestamp);
    _recordFixStats(now.difference(prevFixAt ?? now), ageSeconds);

    notifyListeners();
  }

  /// 定位龄期补偿：见 [_onGpsPosition] 的"补偿步"。
  ///
  /// 只用可信区间 `[0, maxFixAgeSec]` 内的龄期：时间戳晚于本地时钟（时钟偏移）、
  /// 或明显是异常值（单位/时区错、批处理积压）时**放弃补偿** —— 宁可慢一点，
  /// 也不能凭空多跑几十米把用户推到弯道之后。返回实际补偿的秒数（0 = 未补偿）。
  double _compensateFixAge(DateTime now, DateTime fixTimestamp) {
    final age = now.difference(fixTimestamp).inMicroseconds / 1e6;
    if (age < 0 || age > maxFixAgeSec) return 0;
    if (!_advanceProjection(age)) return 0;
    return age;
  }

  /// 按当前车速把里程前推 [seconds]（航位推算的一步），返回是否真的推进了。
  ///
  /// 两条推算路径共用：①两帧之间的平滑、②定位龄期补偿。
  ///
  /// 三条护栏：
  /// - **静止不推**（车速低于 [minEtaSpeedMs]），避免等红灯时里程自己往前爬；
  /// - **偏离态不推**：车已经不在路线上，沿路线前推没有意义；
  /// - **偏离判定只由实测定位驱动**（`measured: false`），否则 5Hz 的推算会把
  ///   连续 3 次"偏离"在 0.6 秒内凑满，把一次坏点放大成 deviated。
  bool _advanceProjection(double seconds) {
    final analyzer = _analyzer;
    final projection = _projection;
    if (analyzer == null || projection == null) return false;
    if (_state == NaviState.deviated) return false;
    if (_speedMs <= minEtaSpeedMs || seconds <= 0) return false;

    final advanced = (projection.distance + _speedMs * seconds)
        .clamp(0.0, analyzer.totalDistance);
    if (advanced <= projection.distance) return false;

    // 只有里程推进是关键，offset 沿用最后一次实测值
    _applyProjection(Projection(advanced, projection.offset), measured: false);
    return true;
  }

  /// 定位健康度诊断：累计 5 帧后记一条日志。
  ///
  /// 真机排查"导航滞后"就看这两项：
  /// - **采样间隔**：正常 ≈1000ms（`LocationService.androidFixInterval`），
  ///   明显更大说明 `intervalDuration` 没生效或系统在降频；
  /// - **定位龄期**（采集 → 送达）：正常 <500ms，越大说明芯片解算/融合/派发
  ///   这一段越慢，也就越需要龄期补偿来兜。
  void _recordFixStats(Duration gap, double ageSeconds) {
    final ms = gap.inMilliseconds;
    if (ms > 0 && ms <= 60000) {
      _fixIntervalSamples++;
      _fixIntervalSumMs += ms;
    }
    if (ageSeconds > 0) {
      _fixAgeSamples++;
      _fixAgeSumMs += (ageSeconds * 1000).round();
    }
    if (!_fixIntervalLogged && _fixIntervalSamples >= 5) {
      _fixIntervalLogged = true;
      _log(
        LogType.info,
        '定位健康度：采样间隔均值 ${gpsFixIntervalMs}ms（期望 '
        '≈${LocationService.androidFixInterval.inMilliseconds}ms）/ '
        '定位龄期均值 ${gpsFixAgeMs ?? "--"}ms（期望 <500ms）',
      );
    }
  }

  /// 连续性投影的先验：上一次里程 + 按车速推算的前进量（含前向搜索窗口）。
  ///
  /// 为什么需要：路线在空间上贴回自己时（立交上下匝道 / 主辅路，实测相隔
  /// 仅 18m），"整条路线取最近边"会把里程吸到几百米后的另一段，表现为
  /// **下一个动作跳过后面的转弯**。给出里程先验后，投影会在窗口内取
  /// "里程最接近先验"的候选（连续性优先于几何最近）。
  ///
  /// 首次定位，或定位空档过长（>60s：可能已驶离很远、或被系统挂起后回前台）
  /// 时返回 null，退回全局最近，由偏离检测兜底。
  ///
  /// **基准必须是"实测里程"而不是"当前显示里程"**：显示里程含平滑外推量，
  /// 在它之上再加 `车速 × 定位间隔` 会把同一个间隔算两遍（先验偏前一帧车程，
  /// 窗口甚至会把真实位置排除在外 —— 隧道恢复时最明显）。
  ({double? anchor, double windowAhead}) _continuityPrior(DateTime? prevFixAt) {
    final base = _measuredDistance;
    if (base == null || prevFixAt == null) {
      return (anchor: null, windowAhead: 400);
    }
    final dt = DateTime.now().difference(prevFixAt).inMilliseconds / 1000.0;
    if (dt < 0 || dt > 60) return (anchor: null, windowAhead: 400);
    final advance = _speedKmh / 3.6 * dt;
    return (
      anchor: base + advance,
      windowAhead: math.max(400, advance * 3),
    );
  }

  /// 投影结果落到各项状态（通栏、偏离、限速），GPS 与航位推算共用。
  ///
  /// [measured] 为 false 表示这是平滑/外推产生的推算值：里程与队列照样更新，
  /// 但**不参与偏离判定** —— 偏离是"实测点离路线多远"的属性，用推算值反复喂
  /// 同一个 offset 会在 5Hz 下把"连续 3 次超阈值"凑满（0.6 秒就误判 deviated）。
  void _applyProjection(Projection projection, {bool measured = true}) {
    final analyzer = _analyzer;
    if (analyzer == null) return;

    _projection = projection;
    _currentRoad = analyzer.linkAt(projection.distance).roadName;
    _remaining = analyzer.remainingAt(projection.distance);
    _upcoming = analyzer.upcomingActions(projection.distance, limit: upcomingLimit);
    _speedMs = math.max(_speedKmh / 3.6, minEtaSpeedMs);

    // 4d 超速联动：最近一个已生效的限速点
    _speedLimitKmh = speedLimitFor(_speedLimits, projection.distance);

    _rebuildRouteSlice();
    _updateBannerExpansion();
    if (measured) _updateDeviation(projection.offset);
  }

  /// 重算底图切片。
  ///
  /// 带**抖动抑制**：里程前移不足 [sliceAnchorStepMeters] 且航向变化不足
  /// [sliceBearingDeadbandRad] 时沿用上一次切片 —— 视窗不动，路线不会"呼吸"。
  void _rebuildRouteSlice() {
    final analyzer = _analyzer;
    if (analyzer == null) {
      _routeSlice = null;
      _routeMarkers = const [];
      return;
    }

    // E1：路线已就绪但还没有定位 → 以路线起点为锚点画全程（不含已行驶段）
    final hasFix = _projection != null;
    final vd = _projection?.distance ?? 0.0;
    final bearing = analyzer.bearingAt(vd) ?? _sliceBearing ?? 0.0;
    final anchor = _sliceAnchorDistance;

    if (hasFix &&
        anchor != null &&
        _routeSlice != null &&
        (vd - anchor).abs() < sliceAnchorStepMeters &&
        _sliceBearing != null &&
        _angleDelta(bearing, _sliceBearing!) < sliceBearingDeadbandRad) {
      return;
    }

    _sliceAnchorDistance = vd;
    _sliceBearing = bearing;

    final slice = analyzer.routeSlice(
      vehicleDistance: vd,
      behindMeters: hasFix ? sliceBehindMeters : 0,
      aheadMeters: _mapAheadMeters.toDouble(),
    );
    _routeSlice = slice;
    _routeMarkers = _buildMarkers(analyzer, slice);
  }

  /// 视窗内的点标记：红绿灯（link 级 `has_traffic_light`）与限速点
  List<RouteMarker> _buildMarkers(RouteAnalyzer analyzer, RouteSlice slice) {
    if (slice.isEmpty) return const [];
    final out = <RouteMarker>[];
    for (final span in analyzer.links) {
      if (!span.link.hasTrafficLight) continue;
      // 红绿灯位于"驶向路口"的 link 的**终点节点**（该 link 与下一条 link 的交点）。
      // 高德把 has_traffic_light 标在进入路口的 link 上，而不是驶出路口的 link：
      // 实测样本 22 条被标记 link 中，无一是某段的首条，却有 2 条是末条；
      // 且段末动作（main_action）恰好落在末条 link 的终点。
      // 因此用 span.end（= 下一条 link 的起点坐标）而非 span.start，
      // 否则灯会被画在该 link 起点、比真实路口早约一个 link 的长度（样本 3~97m）。
      final lightDistance = span.end;
      if (lightDistance < slice.fromDistance ||
          lightDistance > slice.toDistance) {
        continue;
      }
      out.add(RouteMarker(
        analyzer.coordAt(lightDistance),
        RouteMarkerKind.trafficLight,
      ));
    }
    for (final limit in _speedLimits) {
      if (limit.atDistance < slice.fromDistance ||
          limit.atDistance > slice.toDistance) {
        continue;
      }
      out.add(RouteMarker(
        analyzer.coordAt(limit.atDistance),
        RouteMarkerKind.speedLimit,
        value: limit.speed,
      ));
    }
    return out;
  }

  /// 两个方位角之间的最小夹角（弧度，恒为正）
  static double _angleDelta(double a, double b) {
    var d = (a - b) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    return d.abs();
  }

  /// 通栏展开状态由**队列**驱动，而非单个动作（方案 §2.4 ①）：
  /// 只要队列中还有动作在 8 秒窗口内，通栏就保持展开。
  bool _updateBannerExpansion() {
    final hasImminent =
        _upcoming.any((a) => etaSeconds(a) < bannerEtaThresholdSec);
    if (hasImminent == _bannerExpanded) return false;
    _bannerExpanded = hasImminent;
    return true;
  }

  void _updateDeviation(double offset) {
    if (offset > deviationThresholdMeters) {
      _deviationFixCount++;
      final justDeviated = _deviationFixCount == deviationFixThreshold;
      if (justDeviated) {
        _state = NaviState.deviated;
        _log(LogType.warning, '偏离路线 ${offset.toStringAsFixed(0)}m，尝试拉取新路线');
      }
      if (_deviationFixCount >= deviationFixThreshold) {
        final now = DateTime.now();
        final last = _lastDeviationRefetchAt;
        // 已经确认拿不到新路线（快照未变）就退化为慢速重试
        final throttle = _replanFailed
            ? deviationRefetchBackoffSec
            : deviationRefetchThrottleSec;
        if (last == null || now.difference(last).inSeconds >= throttle) {
          _lastDeviationRefetchAt = now;
          unawaited(_refreshRoute());
        }
      }
      return;
    }

    _deviationFixCount = 0;
    if (_state == NaviState.deviated) {
      _state = NaviState.navigating;
      _replanFailed = false;
      _log(LogType.success, '已回到路线，恢复导航');
    } else if (_state == NaviState.locating) {
      _state = NaviState.navigating; // 首个有效投影
    }
  }

  // ==========================================================================
  // 限速点（4d）
  // ==========================================================================

  /// 由 facilities 提取可用限速点。
  ///
  /// - `cameras[type==0].speed`：带限速值的测速点（本样本出现 100/80/30）
  /// - `general[type==10].speed`：限速标志
  /// - 脏坐标（`|lon|>180` 或 `|lat|>90`）必须过滤（方案 §3.7）
  static List<SpeedLimitPoint> extractSpeedLimits(RouteAnalyzer analyzer) {
    final out = <SpeedLimitPoint>[];

    void consider(double lon, double lat, int segIdx, int linkIdx, int? speed) {
      if (speed == null || speed <= 0) return;
      if (lon.abs() > 180 || lat.abs() > 90) return;
      double? at;
      for (final span in analyzer.links) {
        if (span.segmentIndex == segIdx && span.link.linkIndex == linkIdx) {
          at = span.start;
          break;
        }
      }
      at ??= analyzer.project(lon, lat).distance;
      out.add((speed: speed, atDistance: at));
    }

    for (final c in analyzer.route.facilities.cameras) {
      if (c.type != 0) continue;
      consider(c.lon, c.lat, c.segmentIndex, c.linkIndex, c.speed);
    }
    for (final g in analyzer.route.facilities.general) {
      if (g.type != 10) continue;
      consider(g.lon, g.lat, g.segmentIndex, g.linkIndex, g.speed);
    }
    out.sort((a, b) => a.atDistance.compareTo(b.atDistance));
    return out;
  }

  /// 里程 [distance] 处**当前生效**的限速值。
  ///
  /// 取最后一个不晚于当前里程的限速点；若它已经在身后 [limitValidMeters] 米之外，
  /// 说明限速已过期（路段切换），返回 null 避免一直挂牌。
  static const double limitValidMeters = 2000;

  static int? speedLimitFor(List<SpeedLimitPoint> limits, double distance) {
    int? found;
    double foundAt = 0;
    for (final l in limits) {
      if (l.atDistance > distance) break;
      found = l.speed;
      foundAt = l.atDistance;
    }
    if (found == null) return null;
    if (distance - foundAt > limitValidMeters) return null;
    return found;
  }

  void _log(LogType type, String message) =>
      _logCallback(_source, type, message);
}
