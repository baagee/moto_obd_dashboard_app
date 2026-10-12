import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../data/amap/models.dart';
import '../data/amap/route_analyzer.dart';
import '../data/amap/share_client.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import '../widgets/cyber_button.dart';
import '../widgets/cyber_toast.dart';

/// 高德「实时分享」路线解析验证页（最小 Demo）。
///
/// 核心结论：分享短链只用来拿**路线几何 + 实时路况**（`restoration` 接口），
/// **位置不走高德的 `info` 接口轮询**——因为分享者就是本机，直接用
/// [LocationService] 的实时 GPS 流投影到路线上，比等 10s 轮询更快、更顺滑，
/// 也省掉这部分网络开销。GPS 是 WGS-84，投影前需转成高德的 GCJ-02
/// （复用现有 [GeocodingService.wgs84ToGcj02]）。
///
/// 使用方式：
/// 1. 高德地图 App 内「导航前」分享行程，复制生成的短链；
/// 2. 粘贴到输入框，点「解析路线」拿到几何与自检结果；
/// 3. 用「模拟位置」拖动里程，**不用出门**即可验证投影 / 指引 / 动作队列；
///    点「跳到下一动作前 150m」可快速走到临近路口，观察 8 秒窗口与连续动作序列；
/// 4. 需要真实定位时点「开启 GPS 追踪」，用本机实时位置投影到这条路线上；
/// 5. 可选再开「路线自动刷新」观察路况/重新规划（带脏检查，内容不变不重建）。
///
/// 仅在 debug 构建从「高级设置」面板进入，不改动任何现有 Provider/Service。
class AmapShareProbeScreen extends StatefulWidget {
  const AmapShareProbeScreen({super.key});

  @override
  State<AmapShareProbeScreen> createState() => _AmapShareProbeScreenState();
}

class _AmapShareProbeScreenState extends State<AmapShareProbeScreen> {
  final _urlController = TextEditingController();
  final _client = AmapShareClient();

  String? _param;
  RouteAnalyzer? _analyzer;

  bool _resolving = false;
  bool _routePolling = false;
  bool _gpsTracking = false;
  bool _probingStatus = false;
  String? _errorText;

  /// 路线自动刷新间隔（秒），可在页面上切换用于实测
  int _routeIntervalSec = 30;

  static const List<int> _intervalOptions = [10, 15, 30, 60];

  Timer? _routeTimer;
  StreamSubscription<Position>? _gpsSub;

  // 最近一次投影结果（用于展示，不依赖高德 info 接口）
  Projection? _projection;
  Guidance? _guidance;
  ({double meters, double seconds, int lights})? _remaining;
  double? _gpsSpeedKmh;
  double? _gpsAccuracy;
  DateTime? _lastFixAt;

  /// 最近一次原始定位（WGS-84 假设）。用于**坐标系自检**：
  /// 部分国内 ROM / 定位源直接返回 GCJ-02，此时再转换一次会有 ~550m 系统偏移
  /// （表现为"高德地图上位置是准的，本 app 里偏"）。自检同时投影两种假设，
  /// 看哪一种贴合路线，就能在真机上一眼分辨是坐标系问题还是 GPS 精度问题。
  double? _lastRawLat;
  double? _lastRawLon;

  /// 上一次用于投影的坐标（GCJ-02）。路线重建后用它重新投影，
  /// 避免位置跳变（迁移文档坑清单 #3）。
  LonLat? _lastKnownGcj;

  // ── 模拟位置（不用出门即可验证投影 / 指引 / 动作队列）──
  /// 非 null 时处于模拟模式；值为模拟的沿路线里程（米）
  double? _simDistance;

  /// 模拟车速（km/h），仅用于 ETA 估算
  double _simSpeedKmh = 40;

  static const List<int> _simSpeedOptions = [20, 40, 60, 80];

  // ── 路线脏检查 ──
  /// 上一次的路线指纹；指纹相同则跳过 RouteAnalyzer 重建
  String? _routeFingerprint;
  int _routeUnchangedCount = 0;

  int _routeRefreshCount = 0;
  int _gpsFixCount = 0;
  int _errorCount = 0;
  final List<String> _eventLog = [];

  static const int _maxLog = 100;

  /// 当前用于 ETA 估算的速度（km/h）：模拟模式用模拟车速，否则用 GPS 速度
  double get _etaSpeedKmh =>
      _simDistance != null ? _simSpeedKmh : (_gpsSpeedKmh ?? 0);

  @override
  void dispose() {
    _stopRoutePolling();
    _stopGpsTracking();
    _client.close();
    _urlController.dispose();
    super.dispose();
  }

  void _log(String message) {
    final ts = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final prefix = '${two(ts.hour)}:${two(ts.minute)}:${two(ts.second)}';
    setState(() {
      _eventLog.insert(0, '[$prefix] $message');
      if (_eventLog.length > _maxLog) {
        _eventLog.removeRange(_maxLog, _eventLog.length);
      }
    });
  }

  // ---------------------------------------------------------------------
  // 分享状态：两个端点各打一次，逐字留证
  // ---------------------------------------------------------------------

  /// 探测"这条分享还活着吗"，两个端点都打（行后 / 行前）。
  ///
  /// 用途有两个：
  /// 1. **取证**：行前端点连成功样本都还没取到（见
  ///    `amap-user-route-share-info.md` §8），这里把**原始响应逐字**写进日志，
  ///    真机跑一次就能回填接口文档 §4/§5；
  /// 2. **对拍**：确认线上两个端点的 `code/status/shareStatus` 归一结果，与
  ///    `ShareAlive` 的映射表一致。
  Future<void> _probeShareStatus() async {
    final url = _urlController.text.trim();
    if (_param == null && url.isEmpty) {
      if (mounted) {
        CyberToast.show(context, '请先输入分享短链或解析一次', type: CyberToastType.warning);
      }
      return;
    }
    setState(() => _probingStatus = true);
    try {
      final param = _param ?? await _client.resolveParam(url);
      _param = param;

      // ① 行中（POST /ws/share/lbs/info）—— 主判据
      final navi = await _client.probeNaviStatus(param);
      _log('【行中 info】code=${navi.code} result=${navi.result} '
          'shareStatus=${navi.shareStatus ?? "null"} → ${navi.alive.name}');
      _log('  raw: ${_clip(navi.raw)}');

      // ② 行前（GET /ws/user/route/share/info）—— 复核 / 切端点判据
      final before = await _client.fetchShareStatus(param);
      _log('【行前 share/info】code=${before.code} status='
          '${before.status ?? "null"} → ${before.alive.name}'
          '${before.shouldSwitchToNavi ? "（status=4，该改用行中端点）" : ""}');
      _log('  raw: ${_clip(before.raw)}');

      if (mounted) {
        CyberToast.show(
          context,
          '行中=${navi.alive.name} / 行前=${before.alive.name}',
          type: CyberToastType.success,
        );
      }
    } catch (e) {
      _errorCount++;
      _log('分享状态探测失败：$e');
      if (mounted) {
        CyberToast.show(context, '探测失败：$e', type: CyberToastType.error);
      }
    } finally {
      if (mounted) setState(() => _probingStatus = false);
    }
  }

  /// 日志里保留原始响应的前 800 字符（够看出全部字段，又不会刷屏）
  static String _clip(String s) =>
      s.length > 800 ? '${s.substring(0, 800)}…(${s.length} 字符)' : s;

  Future<void> _tryPasteFromClipboard() async {    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) CyberToast.show(context, '剪贴板为空', type: CyberToastType.warning);
      return;
    }
    _urlController.text = text;
    _log('已从剪贴板粘贴：$text');
  }

  // ---------------------------------------------------------------------
  // 路线：只负责几何 + 路况，30s 一次足够（见 amap-share-route-flutter-port.md）
  // ---------------------------------------------------------------------

  Future<void> _resolveRouteOnce() async {
    final url = _urlController.text.trim();
    if (_param == null && url.isEmpty) {
      if (mounted) CyberToast.show(context, '请先输入分享短链', type: CyberToastType.warning);
      return;
    }
    setState(() {
      _resolving = true;
      _errorText = null;
    });
    try {
      final param = _param ?? await _client.resolveParam(url);
      _param = param;
      final env = await _client.fetchRoute(param);
      _routeRefreshCount++;

      // ── 脏检查：指纹未变则不重建 RouteAnalyzer（构建成本在 669 条 link 的
      //    索引与 526 个几何点的里程插值，实测同一路线长期完全一致）──
      final fingerprint = _fingerprintOf(env.route);
      if (fingerprint == _routeFingerprint && _analyzer != null) {
        _routeUnchangedCount++;
        _log('路线刷新 #$_routeRefreshCount：无实质变化，跳过重建（$fingerprint）');
        return;
      }

      final analyzer = RouteAnalyzer(env.route);
      _routeFingerprint = fingerprint;
      _log(
        '路线刷新 #$_routeRefreshCount：内容变化 → 重建 distance='
        '${analyzer.totalDistance.toStringAsFixed(0)}m links=${analyzer.links.length} '
        'coords=${analyzer.path.coords.length} segs=${analyzer.segments.length} '
        '自检=${analyzer.lengthConsistent ? "通过" : "不一致"}',
      );
      setState(() => _analyzer = analyzer);
      // 路线变化后立即用上一次已知坐标重新投影，避免等下一次定位才刷新
      _reprojectKnown();
    } catch (e) {
      _errorCount++;
      final msg = e.toString();
      setState(() => _errorText = msg);
      _log('路线解析出错：$msg');
      if (mounted) CyberToast.show(context, '解析失败：$msg', type: CyberToastType.error);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _toggleRoutePolling() {
    if (_routePolling) {
      _stopRoutePolling();
    } else {
      _startRoutePolling();
    }
  }

  void _startRoutePolling() {
    if (_analyzer == null) {
      if (mounted) {
        CyberToast.show(context, '请先「解析路线」成功后再开启自动刷新',
            type: CyberToastType.warning);
      }
      return;
    }
    setState(() => _routePolling = true);
    _log('开启路线自动刷新：${_routeIntervalSec}s/次');
    _routeTimer = Timer.periodic(
        Duration(seconds: _routeIntervalSec), (_) => _resolveRouteOnce());
  }

  /// 切换刷新间隔：轮询中则立即重建定时器生效
  void _setRouteInterval(int sec) {
    if (sec == _routeIntervalSec) return;
    setState(() => _routeIntervalSec = sec);
    _log('路线刷新间隔改为 ${sec}s');
    if (_routePolling) {
      _routeTimer?.cancel();
      _routeTimer = Timer.periodic(
          Duration(seconds: sec), (_) => _resolveRouteOnce());
    }
  }

  void _stopRoutePolling() {
    _routeTimer?.cancel();
    _routeTimer = null;
    if (_routePolling && mounted) setState(() => _routePolling = false);
    if (_routePolling) _log('已停止路线自动刷新');
  }

  // ---------------------------------------------------------------------
  // 位置：不轮询高德 info 接口，直接用本机实时 GPS 投影到路线上
  // ---------------------------------------------------------------------

  Future<void> _toggleGpsTracking() async {
    if (_gpsTracking) {
      _stopGpsTracking();
      return;
    }
    if (_analyzer == null) {
      if (mounted) {
        CyberToast.show(context, '请先「解析路线」拿到几何数据后再开 GPS 追踪',
            type: CyberToastType.warning);
      }
      return;
    }
    final status = await LocationService.checkAndRequestOnLaunch();
    if (status != LocationPermissionStatus.granted) {
      if (mounted) {
        CyberToast.show(context, '定位权限未授予（$status），无法启动 GPS 追踪',
            type: CyberToastType.error);
      }
      return;
    }
    setState(() => _gpsTracking = true);
    _log('开启 GPS 追踪：实时流，minMoveDistance=3m');
    _gpsSub = LocationService.getPositionStream(distanceFilter: 3)
        .listen(_onGpsPosition, onError: (Object e) {
      _errorCount++;
      _log('GPS 流出错：$e');
    });
  }

  void _stopGpsTracking() {
    _gpsSub?.cancel();
    _gpsSub = null;
    if (_gpsTracking && mounted) setState(() => _gpsTracking = false);
    if (_gpsTracking) _log('已停止 GPS 追踪');
  }

  void _onGpsPosition(Position pos) {
    final analyzer = _analyzer;
    if (analyzer == null) return;

    // GPS 原始坐标是 WGS-84，高德 coords 是 GCJ-02，投影前必须转换，
    // 否则会有 100~600 米的系统性偏移（见迁移文档坑清单 #12）
    final gcj = GeocodingService.wgs84ToGcj02(pos.latitude, pos.longitude);
    final projection = analyzer.project(gcj[1], gcj[0]); // project(lon, lat)
    final guidance = analyzer.guidanceAt(projection.distance);
    final remaining = analyzer.remainingAt(projection.distance);

    _gpsFixCount++;
    _lastFixAt = DateTime.now();
    _lastKnownGcj = LonLat(gcj[1], gcj[0]);
    setState(() {
      // 真实定位到达即退出模拟模式（GPS 优先）
      _simDistance = null;
      _projection = projection;
      _guidance = guidance;
      _remaining = remaining;
      _gpsSpeedKmh = pos.speed * 3.6;
      _gpsAccuracy = pos.accuracy;
      _lastRawLat = pos.latitude;
      _lastRawLon = pos.longitude;
    });
    _log(
      'GPS 定位 #$_gpsFixCount：dist=${projection.distance.toStringAsFixed(0)}m '
      'off=${projection.offset.toStringAsFixed(1)}m speed=${(pos.speed * 3.6).toStringAsFixed(1)}km/h '
      'accuracy=${pos.accuracy.toStringAsFixed(1)}m${_coordSystemVerdictLog(analyzer)}',
    );
  }

  /// 坐标系自检的日志结论（每 5 次定位打一次，避免刷屏）
  String _coordSystemVerdictLog(RouteAnalyzer analyzer) {
    if (_lastRawLat == null || _gpsFixCount % 5 != 0) return '';
    final v = _coordSystemCheck(analyzer);
    return '｜坐标系自检：不转换 off=${v.rawOffset.toStringAsFixed(0)}m / '
        '转换后 off=${v.convertedOffset.toStringAsFixed(0)}m'
        '${v.rawLooksBetter ? " ⚠️ 本机定位可能已是 GCJ-02" : " ✓"}';
  }

  /// 同时投影两种假设，返回各自偏离量与判定
  ({double rawOffset, double convertedOffset, bool rawLooksBetter})
      _coordSystemCheck(RouteAnalyzer analyzer) {
    final lat = _lastRawLat!, lon = _lastRawLon!;
    final raw = analyzer.project(lon, lat); // 假设定位源已经是 GCJ-02
    final conv = analyzer.project(_lastKnownGcj!.lon, _lastKnownGcj!.lat);
    return (
      rawOffset: raw.offset,
      convertedOffset: conv.offset,
      // 不转换反而明显更贴合（差 50m 以上），才判定为"定位源已是 GCJ-02"
      rawLooksBetter: raw.offset + 50 < conv.offset,
    );
  }

  /// 路线指纹：用于脏检查。取 version + 里程 + link 数 + 几何点数，
  /// 覆盖"重新规划"会变动的全部维度，且不需要构建 RouteAnalyzer。
  static String _fingerprintOf(AmapRoute route) {
    if (route.paths.isEmpty) return '${route.version}|empty';
    final p = route.main;
    final linkCount = p.segments.fold<int>(0, (a, s) => a + s.links.length);
    return '${route.version}|${p.distance}|$linkCount|${p.coords.length}';
  }

  /// 路线内容变化后，用上一次已知坐标重新投影（迁移文档坑清单 #3）。
  void _reprojectKnown() {
    final analyzer = _analyzer;
    final gcj = _lastKnownGcj;
    if (analyzer == null || gcj == null) {
      _log('路线已更新，等待首次定位');
      return;
    }
    final projection = analyzer.project(gcj.lon, gcj.lat);
    setState(() {
      _projection = projection;
      _guidance = analyzer.guidanceAt(projection.distance);
      _remaining = analyzer.remainingAt(projection.distance);
      if (_simDistance != null) _simDistance = projection.distance;
    });
    _log('路线变化后重新投影：dist=${projection.distance.toStringAsFixed(0)}m '
        'off=${projection.offset.toStringAsFixed(1)}m');
  }

  // ---------------------------------------------------------------------
  // 模拟位置：从路线几何取点直接喂给投影链路，不用出门即可验证算法
  // ---------------------------------------------------------------------

  /// 把"沿路线里程 d"处的坐标喂进投影链路。
  ///
  /// 注意：`coordAt()` 返回的已是 GCJ-02，因此**跳过 WGS-84→GCJ-02 转换**
  /// （该转换由真实 GPS 路径覆盖）。自检点：投影回来的里程应 ≈ d、偏移应 ≈ 0。
  void _applySimulation(double d, {bool log = false}) {
    final analyzer = _analyzer;
    if (analyzer == null) return;
    final coord = analyzer.coordAt(d);
    final projection = analyzer.project(coord.lon, coord.lat);
    _lastKnownGcj = coord;
    _lastFixAt = DateTime.now();
    setState(() {
      _simDistance = d;
      _projection = projection;
      _guidance = analyzer.guidanceAt(projection.distance);
      _remaining = analyzer.remainingAt(projection.distance);
    });
    if (log) {
      _log('模拟位置 d=${d.toStringAsFixed(0)}m → 投影 dist='
          '${projection.distance.toStringAsFixed(0)}m '
          'off=${projection.offset.toStringAsFixed(1)}m'
          '${projection.offset.abs() > 5 ? "  ⚠️ 偏移偏大，coordAt 插值可能有误差" : "  ✓ 自检通过"}');
    }
  }

  /// 跳到「下一个动作前 150m」，用于验证临近路口的提示与连续动作序列
  void _jumpBeforeNextAction() {
    final analyzer = _analyzer;
    if (analyzer == null) return;
    final cur = _projection?.distance ?? 0;
    ActionPoint? target;
    for (final a in analyzer.upcomingActions(cur, limit: 10)) {
      if (a.atDistance - 150 > cur + 5) {
        target = a;
        break;
      }
    }
    if (target == null) {
      if (mounted) {
        CyberToast.show(context, '后面没有更远的动作了', type: CyberToastType.warning);
      }
      return;
    }
    final d = target.atDistance - 150;
    _applySimulation(d);
    _log('跳到动作前 150m：d=${d.toStringAsFixed(0)}m '
        '（${target.arrow} ${target.label} @${target.atDistance.toStringAsFixed(0)}m）');
  }

  void _clearSimulation() {
    setState(() {
      _simDistance = null;
      _projection = null;
      _guidance = null;
      _remaining = null;
      _lastKnownGcj = null;
      _lastFixAt = null;
    });
    _log('已清除模拟位置');
  }

  Future<void> _copyLog() async {
    if (_eventLog.isEmpty) {
      if (mounted) CyberToast.show(context, '暂无日志可复制', type: CyberToastType.warning);
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('=== 高德分享路线解析验证日志（共 ${_eventLog.length} 条）===');
    buffer.writeln('路线刷新 $_routeRefreshCount 次（其中内容变化 $_routeChangedCount 次、'
        '无变化 $_routeUnchangedCount 次）/ GPS 定位 $_gpsFixCount 次 / 出错 $_errorCount 次');
    buffer.writeln('');
    // _eventLog 最新在前；导出按时间正序，便于阅读因果顺序
    for (final line in _eventLog.reversed) {
      buffer.writeln(line);
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) CyberToast.show(context, '已复制日志');
  }

  void _reset() {
    _stopRoutePolling();
    _stopGpsTracking();
    setState(() {
      _param = null;
      _analyzer = null;
      _projection = null;
      _guidance = null;
      _remaining = null;
      _gpsSpeedKmh = null;
      _gpsAccuracy = null;
      _lastFixAt = null;
      _lastKnownGcj = null;
      _lastRawLat = null;
      _lastRawLon = null;
      _simDistance = null;
      _simSpeedKmh = 40;
      _routeFingerprint = null;
      _routeUnchangedCount = 0;
      _errorText = null;
      _routeRefreshCount = 0;
      _gpsFixCount = 0;
      _errorCount = 0;
    });
    _log('已重置会话');
  }

  /// 内容真正变化（发生重建）的刷新次数
  int get _routeChangedCount => _routeRefreshCount - _routeUnchangedCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildInputArea(),
            _buildToolbar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorText != null) _buildErrorBanner(),
                    if (_analyzer != null) _buildRouteCard(_analyzer!),
                    const SizedBox(height: 12),
                    if (_analyzer != null) _buildSimulationCard(),
                    const SizedBox(height: 12),
                    if (_guidance != null) _buildGuidanceCard(),
                    const SizedBox(height: 12),
                    if (_analyzer != null) _buildActionQueueCard(),
                    const SizedBox(height: 12),
                    _buildLogSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.primary20)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.alt_route, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('高德分享路线解析验证 · Demo', style: AppTheme.titleMedium),
          const Spacer(),
          _buildStatusDots(),
        ],
      ),
    );
  }

  Widget _buildStatusDots() {
    return Row(
      children: [
        _buildDot(_routePolling, '路线'),
        const SizedBox(width: 10),
        _buildDot(_gpsTracking, 'GPS'),
      ],
    );
  }

  Widget _buildDot(bool active, String label) {
    final color = active ? AppTheme.gaugeNormal : AppTheme.textMuted;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: active ? AppTheme.glowShadow(color, blur: 6) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface40,
                border: Border.all(color: AppTheme.primary20),
              ),
              child: TextField(
                controller: _urlController,
                style: AppFonts.monoStyle(fontSize: 12, color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'https://surl.amap.com/xxxxxxxxx',
                  hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _tryPasteFromClipboard,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.content_paste, size: 20, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
          CyberButton(
            text: _resolving ? '解析中…' : '解析路线',
            type: CyberButtonType.primary,
            height: 32,
            fontSize: 11,
            icon: Icons.play_arrow,
            onPressed: _resolving ? null : _resolveRouteOnce,
          ),
          CyberButton(
            text: _routePolling
                ? '停止路线刷新'
                : '路线自动刷新(${_routeIntervalSec}s)',
            type: _routePolling ? CyberButtonType.danger : CyberButtonType.secondary,
            height: 32,
            fontSize: 11,
            icon: _routePolling ? Icons.stop : Icons.autorenew,
            onPressed: _toggleRoutePolling,
          ),
          CyberButton(
            text: _gpsTracking ? '停止 GPS 追踪' : '开启 GPS 追踪',
            type: _gpsTracking ? CyberButtonType.danger : CyberButtonType.success,
            height: 32,
            fontSize: 11,
            icon: _gpsTracking ? Icons.stop : Icons.gps_fixed,
            onPressed: _toggleGpsTracking,
          ),
          CyberButton.secondary(
            text: _probingStatus ? '探测中…' : '分享状态探测',
            height: 32,
            fontSize: 11,
            icon: Icons.flag_outlined,
            onPressed: _probingStatus ? null : _probeShareStatus,
          ),
          CyberButton.secondary(
            text: '复制日志',
            height: 32,
            fontSize: 11,
            icon: Icons.copy,
            onPressed: _copyLog,
          ),
          CyberButton.secondary(
            text: '重置会话',
            height: 32,
            fontSize: 11,
            icon: Icons.refresh,
            onPressed: _reset,
          ),
            ],
          ),
          const SizedBox(height: 8),
          _buildIntervalSelector(),
        ],
      ),
    );
  }

  /// 路线刷新间隔选择器：用于实测不同频率下的数据新鲜度与流量
  Widget _buildIntervalSelector() {
    return Row(
      children: [
        const Text('路线刷新间隔：',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(width: 4),
        for (final sec in _intervalOptions) ...[
          GestureDetector(
            onTap: () => _setRouteInterval(sec),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: sec == _routeIntervalSec
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                border: Border.all(
                  color: sec == _routeIntervalSec
                      ? AppTheme.primary
                      : AppTheme.primary20,
                ),
              ),
              child: Text(
                '${sec}s',
                style: AppFonts.monoStyle(
                  fontSize: 11,
                  color: sec == _routeIntervalSec
                      ? AppTheme.primary
                      : AppTheme.textMuted,
                ),
              ),
            ),
          ),
        ],
        const Spacer(),
        if (_routePolling)
          const Text('生效中', style: TextStyle(color: AppTheme.accentGreen, fontSize: 11)),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.accentRed50),
      ),
      child: Text(
        _errorText ?? '',
        style: AppFonts.monoStyle(fontSize: 11, color: AppTheme.accentRed),
      ),
    );
  }

  Widget _buildRouteCard(RouteAnalyzer analyzer) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface40,
        border: Border.all(color: AppTheme.primary20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('路线（高德 restoration）',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          _buildStatRow('全程', '${analyzer.totalDistance.toStringAsFixed(0)} m'),
          _buildStatRow('link / 几何点 / 分段',
              '${analyzer.links.length} / ${analyzer.path.coords.length} / ${analyzer.segments.length}'),
          _buildStatRow('里程自检',
              analyzer.lengthConsistent ? 'Σlink.length == distance ✓' : '不一致 ✗',
              valueColor: analyzer.lengthConsistent
                  ? AppTheme.accentGreen
                  : AppTheme.accentRed),
          _buildStatRow('路线刷新次数', '$_routeRefreshCount'),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard() {
    final guidance = _guidance!;
    final projection = _projection!;
    final remaining = _remaining!;
    final offsetColor = projection.offset > 100
        ? AppTheme.gaugeDanger
        : (projection.offset > 50 ? AppTheme.gaugeWarn : AppTheme.gaugeNormal);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface50,
        border: Border.all(color: AppTheme.primary20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('导航指引（本机实时 GPS 投影，非高德 info 轮询）',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${guidance.actionArrow}  ${guidance.actionLabel}',
                style: AppFonts.displayStyle(fontSize: 22, color: AppTheme.gaugeNormal),
              ),
              const SizedBox(width: 12),
              Text(
                '${guidance.distanceToAction.toStringAsFixed(0)} 米后',
                style: AppFonts.monoStyle(fontSize: 14, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '当前道路：${guidance.currentRoad}（main_action=${guidance.actionCode}'
            '${_isLowConfidenceAction(guidance.actionCode) ? "，低可信兜底" : ""}）',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _buildStatRow('已行驶/全程',
              '${guidance.traveledDistance.toStringAsFixed(0)}m / ${_analyzer!.totalDistance.toStringAsFixed(0)}m'),
          _buildStatRow('剩余里程/时间',
              '${(remaining.meters / 1000).toStringAsFixed(2)}km / ${(remaining.seconds / 60).toStringAsFixed(1)}分钟'),
          _buildStatRow('剩余红绿灯', '${remaining.lights} 个'),
          _buildStatRow('偏离路线', '${projection.offset.toStringAsFixed(1)} m',
              valueColor: offsetColor),
          _buildStatRow('GPS 速度', '${(_gpsSpeedKmh ?? 0).toStringAsFixed(1)} km/h'),
          _buildStatRow('GPS 精度', '${(_gpsAccuracy ?? 0).toStringAsFixed(1)} m'),
          if (_lastRawLat != null && _lastRawLon != null) ...[
            _buildStatRow('原始定位坐标',
                '${_lastRawLat!.toStringAsFixed(6)}, ${_lastRawLon!.toStringAsFixed(6)}'),
            _buildCoordSystemCheck(),
          ],
          _buildStatRow('最近定位',
              _lastFixAt == null ? '-' : _lastFixAt!.toLocal().toString().substring(11, 19)),
          _buildStatRow('GPS 定位次数', '$_gpsFixCount'),
        ],
      ),
    );
  }

  bool _isLowConfidenceAction(int code) =>
      !(code == 0 || code == 1 || code == 2 || code == 3);

  /// 坐标系自检：本机定位到底是 WGS-84，还是**已经是 GCJ-02**？
  ///
  /// 把同一个点按两种假设各投影一次：若"不转换"明显更贴合路线，说明定位源
  /// 直接给了 GCJ-02（部分国内 ROM / 定位源的已知行为），此时本工程再做一次
  /// WGS→GCJ 转换就会引入 ~550m 的**系统性**偏移 —— 真机现象正是
  /// "高德地图上位置是准的，本 app 里偏"，且偏差方向固定。
  /// 若两种假设差别只在几十米内，那就是 GPS 精度问题，不是坐标系问题。
  Widget _buildCoordSystemCheck() {
    final analyzer = _analyzer;
    if (analyzer == null || _lastRawLat == null || _lastRawLon == null) {
      return const SizedBox.shrink();
    }
    final v = _coordSystemCheck(analyzer);
    final String verdict;
    final Color color;
    if (v.rawLooksBetter) {
      verdict = '⚠️ 不转换才贴合 → 本机定位可能已是 GCJ-02（再转换会偏 ~550m）';
      color = AppTheme.gaugeWarn;
    } else if (v.convertedOffset + 50 < v.rawOffset) {
      verdict = '✓ 转换后明显更贴合（定位源为 WGS-84，处理正确）';
      color = AppTheme.gaugeNormal;
    } else {
      verdict = '— 两种假设差别在 GPS 精度内，无法区分（属正常）';
      color = AppTheme.textMuted;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow('自检·不转换', '偏离 ${v.rawOffset.toStringAsFixed(1)} m'),
        _buildStatRow('自检·转换后', '偏离 ${v.convertedOffset.toStringAsFixed(1)} m'),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Text(verdict, style: TextStyle(fontSize: 11, color: color)),
        ),
      ],
    );
  }

  /// 模拟位置卡片：拖动里程即可把路线上的任意点喂给投影链路，
  /// 不用出门就能验证投影 / 指引 / 动作队列（真实 GPS 低速度时不产生新点）。
  Widget _buildSimulationCard() {
    final analyzer = _analyzer!;
    final total = analyzer.totalDistance;
    final active = _simDistance != null;
    final current = (_simDistance ?? _projection?.distance ?? 0).clamp(0.0, total);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface40,
        border: Border.all(
          color: active ? AppTheme.primary50 : AppTheme.primary20,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(active ? Icons.smart_toy : Icons.smart_toy_outlined,
                  size: 13,
                  color: active ? AppTheme.primary : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                active ? '模拟位置（进行中）' : '模拟位置（不依赖 GPS）',
                style: TextStyle(
                    color: active ? AppTheme.primary : AppTheme.textMuted,
                    fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${current.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} m',
                style: AppFonts.monoStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.primary20,
              thumbColor: AppTheme.primary,
            ),
            child: Slider(
              value: current,
              max: total > 0 ? total : 1,
              onChanged: (v) => _applySimulation(v),
              onChangeEnd: (v) => _applySimulation(v, log: true),
            ),
          ),
          Row(
            children: [
              const Text('模拟车速',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              const SizedBox(width: 8),
              for (final spd in _simSpeedOptions) ...[
                GestureDetector(
                  onTap: () => setState(() => _simSpeedKmh = spd.toDouble()),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _simSpeedKmh == spd
                          ? AppTheme.primary.withValues(alpha: 0.2)
                          : Colors.transparent,
                      border: Border.all(
                        color: _simSpeedKmh == spd
                            ? AppTheme.primary
                            : AppTheme.primary20,
                      ),
                    ),
                    child: Text(
                      '$spd',
                      style: AppFonts.monoStyle(
                        fontSize: 11,
                        color: _simSpeedKmh == spd
                            ? AppTheme.primary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              CyberButton.secondary(
                text: '跳到下一动作前 150m',
                height: 28,
                fontSize: 10,
                icon: Icons.skip_next,
                onPressed: _jumpBeforeNextAction,
              ),
              if (active) ...[
                const SizedBox(width: 6),
                CyberButton.secondary(
                  text: '清除',
                  height: 28,
                  fontSize: 10,
                  icon: Icons.close,
                  onPressed: _clearSimulation,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 前方动作队列：按里程升序列出尚未经过的动作点。
  ///
  /// 与"查当前所在 segment"的区别：GPS 跳点跨过短 segment 时，
  /// 队列仍能给出正确的"下一个动作"，不会静默漏掉。
  Widget _buildActionQueueCard() {
    final analyzer = _analyzer!;
    final distance = _projection?.distance ?? 0;
    final upcoming = analyzer.upcomingActions(distance, limit: 4);
    final passed = analyzer.lastPassedAction(distance);
    final speedMs = _etaSpeedKmh / 3.6;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface50,
        border: Border.all(color: AppTheme.primary20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('前方动作队列', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              const SizedBox(width: 8),
              Text('共 ${analyzer.actions.length} 个动作',
                  style: AppFonts.monoStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            const Text('已无后续动作（接近终点）',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
          else
            ...upcoming.asMap().entries.map((e) => _buildActionRow(
                  ordinal: e.key + 1,
                  action: e.value,
                  distance: distance,
                  speedMs: speedMs,
                )),
          if (passed != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppTheme.primary20),
            const SizedBox(height: 6),
            Text(
              '刚经过：${passed.arrow} ${passed.label}'
              '（已过 ${(distance - passed.atDistance).toStringAsFixed(0)} m）',
              style: AppFonts.monoStyle(
                  fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required int ordinal,
    required ActionPoint action,
    required double distance,
    required double speedMs,
  }) {
    final ahead = action.atDistance - distance;
    // 按当前速度估算到达时间；速度过低时不做估算（避免除零/无意义的大数）
    final etaSec = speedMs > 1.0 ? ahead / speedMs : null;
    final isNext = ordinal == 1;
    final accent = isNext ? AppTheme.gaugeNormal : AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Text('$ordinal',
                style: AppFonts.monoStyle(fontSize: 11, color: AppTheme.textMuted)),
          ),
          SizedBox(
            width: 62,
            child: Text(
              '${action.arrow} ${action.label}',
              style: AppFonts.monoStyle(fontSize: 12, color: accent),
            ),
          ),
          SizedBox(
            width: 66,
            child: Text(
              '${ahead.toStringAsFixed(0)} m',
              style: AppFonts.monoStyle(fontSize: 12, color: accent),
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              etaSec == null ? '--' : '${etaSec.toStringAsFixed(0)} s',
              style: AppFonts.monoStyle(
                fontSize: 12,
                // 8 秒内高亮，即为 L1「临近展开」的触发条件
                color: etaSec != null && etaSec < 8
                    ? AppTheme.gaugeWarn
                    : AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              action.nextRoadName == null
                  ? '${action.roadName} → 终点'
                  : '${action.roadName} → ${action.nextRoadName}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
          if (!action.isHighConfidence)
            Text('推断',
                style: AppFonts.monoStyle(
                    fontSize: 9, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppFonts.monoStyle(
                  fontSize: 12, color: valueColor ?? AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.terminal, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              '事件日志（路线 $_routeRefreshCount｜变化 $_routeChangedCount / '
              '无变化 $_routeUnchangedCount｜GPS $_gpsFixCount｜出错 $_errorCount）',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ..._eventLog.map((line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line,
                style: AppFonts.monoStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            )),
      ],
    );
  }
}
