/// 高德分享路线 · 网络层（零外部依赖，只用 dart:io）
///
/// **Flutter 不需要本地代理**。浏览器里必须起代理是因为
/// `m5.amap.com` 的 `Access-Control-Allow-Origin` 只允许 `https://static3.amap.com`，
/// 而 Dart 的 HttpClient 不受 CORS 约束 —— 原来 server.py 那层在 App 里可以整个删掉，
/// 只保留"短链解析"这一个能力。
///
/// 若你项目里已用 dio/http，把 `_post` / `_noRedirectGet` 换成对应实现即可，
/// 其余逻辑不用动。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'route_analyzer.dart';

class AmapShareClient {
  AmapShareClient({
    this.cookie = defaultCookie,
    this.userAgent = defaultUserAgent,
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 20),
    String? routeApi,
    String? infoApi,
    String? shareRouteApi,
    String? origin,
    String? referer,
  })  : _http = httpClient ?? HttpClient(),
        _routeApi = routeApi ?? defaultRouteApi,
        _infoApi = infoApi ?? defaultInfoApi,
        _shareRouteApi = shareRouteApi ?? defaultShareRouteApi,
        _origin = origin ?? defaultOrigin,
        _referer = referer ?? defaultReferer;

  final String cookie;
  final String userAgent;
  final Duration timeout;
  final HttpClient _http;

  /// 端点可注入：默认走高德线上接口，测试时可指向本地 HttpServer
  final String _routeApi;
  final String _infoApi;
  final String _shareRouteApi;
  final String _origin;
  final String _referer;

  static const String defaultUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36';

  /// Cookie 不是必需的（实测无 Cookie 也能取数），但带上更稳。
  /// 过期不影响大部分接口，真失效了再换。
  static const String defaultCookie =
      'register_gray=1; amap_new_version_flag=1; amap_migrated_to_new_version=1; '
      'cna=e3S9IEQHxlwCAWdmy8DP264t; amap_pc_visited=1; xlly_s=1';

  static const String defaultOrigin = 'https://static3.amap.com';
  static const String defaultReferer =
      'https://static3.amap.com/activity/2020NewDriveSafeV5/index.html?from=main';

  static const String defaultRouteApi =
      'https://m5.amap.com/ws/share/lbs/route/restoration';
  static const String defaultInfoApi = 'https://m5.amap.com/ws/share/lbs/info';

  /// **行前**分享状态端点（GET，页面内部名 `share_route`）。
  ///
  /// 与 [defaultInfoApi] 是两个端点、**两套状态字段**：
  /// 这个给出 `data.status`（1 行前 / 4 已开始导航 / 2,3 已停止 / `code=10001` 已过期），
  /// 行中的 `data.shareInfo.shareStatus` 在 info 里。详见
  /// `amap-user-route-share-info.md` §5.1。
  static const String defaultShareRouteApi =
      'https://m5.amap.com/ws/user/route/share/info';

  // -------------------------------------------------------------------------
  // 1. 短链 -> param
  // -------------------------------------------------------------------------

  /// 解析分享短链，返回接口用的 `param`。
  ///
  /// 原理：短链 302 到
  /// `static3.amap.com/activity/2020NewDriveSafeV5/index.html?from=main&urlParameter=<base64>`，
  /// 页面逻辑是 `param = decodeURIComponent(urlParameter)`。
  ///
  /// 抛 [ShareLinkException] 表示链接无效或不是"行前"分享。
  Future<String> resolveParam(String shareUrl) async {
    final loc = await _noRedirectGet(shareUrl);
    if (loc == null) {
      throw ShareLinkException('短链没有返回 Location，可能不是高德分享短链');
    }
    final uri = Uri.parse(loc);
    final urlParameter = uri.queryParameters['urlParameter'];
    if (urlParameter == null || urlParameter.isEmpty) {
      throw ShareLinkException('跳转地址里没有 urlParameter：$loc');
    }
    // from=before_navi（已点进导航的"行中"分享）前端会改用 naviParams，
    // 那个参数是页面向服务端换取后拿到的，纯静态解析取不到。
    if (uri.queryParameters['from'] == 'before_navi') {
      throw ShareLinkException(
        '这是 before_navi（行中）分享，param 需从浏览器 Network 面板复制',
      );
    }
    return urlParameter; // Uri.queryParameters 已做过 URL 解码
  }

  /// 不自动跟随 302，直接拿 Location
  Future<String?> _noRedirectGet(String url) async {
    final req = await _http.getUrl(Uri.parse(url));
    req.followRedirects = false;
    req.headers.set(HttpHeaders.userAgentHeader, userAgent);
    final res = await req.close().timeout(timeout);
    await res.drain<void>();
    final loc = res.headers.value(HttpHeaders.locationHeader);
    if (loc != null) return loc;
    if (res.statusCode == 200) return res.redirects.isEmpty ? url : null;
    return null;
  }

  // -------------------------------------------------------------------------
  // 2. 数据接口
  // -------------------------------------------------------------------------

  /// 路线几何 + 实时路况。`restorationInfo` 是字符串，内部再 JSON 解析。
  Future<RouteEnvelope> fetchRoute(String param) async {
    final body = await _post('$_routeApi?param=${Uri.encodeQueryComponent(param)}');
    final env = RouteEnvelope.parse(body);
    if (!env.result) {
      throw ShareApiException('restoration 失败：${env.code} / ${env.message}');
    }
    return env;
  }

  /// 分享者实时状态。**位置在这里**（locInfo）；状态看 `env.alive`。
  ///
  /// 业务失败抛 [ShareApiException]（[ShareSession.refresh] 依赖这个语义）；
  /// 只想读状态、不关心失败的话用 [probeNaviStatus]。
  Future<ShareInfoEnvelope> fetchInfo(String param) async {
    final env = await probeNaviStatus(param);
    if (!env.result) {
      throw ShareApiException('info 失败：${env.message}');
    }
    return env;
  }

  /// **行中**分享状态（POST，探测语义：业务失败不抛异常）。
  ///
  /// 判断"导航是否已停止"时，`result:false` / `code != "1"` 本身也是信息
  /// （探不到 ≠ 已停止），所以把信封原样交给调用方按 `alive` 归一。
  /// 只有传输层错误（非 200 / 超时）才抛 [ShareApiException]。
  Future<ShareInfoEnvelope> probeNaviStatus(String param) async {
    final body = await _post(
      '$_infoApi?param=${Uri.encodeQueryComponent(param)}&from=0',
    );
    return ShareInfoEnvelope.parse(body);
  }

  /// **行前**分享状态（GET）。
  ///
  /// 用于判断"该切端点 / 已停止 / 已过期"。业务失败（`code != "1"`）**不抛异常**
  /// —— `code` 本身就是判据（`10001` = 已过期，`2/3` = 参数问题，**不是结束**），
  /// 由调用方按 `alive` 归一。只有传输层错误才抛 [ShareApiException]。
  ///
  /// 注意方法与本端点的差异：行前是 **GET**，行中（[probeNaviStatus]）是 **POST**。
  Future<ShareStatusEnvelope> fetchShareStatus(String param) async {
    final body = await _get(
      '$_shareRouteApi?param=${Uri.encodeQueryComponent(param)}',
    );
    return ShareStatusEnvelope.parse(body);
  }

  /// 公共请求头（Origin/Referer/UA/Cookie/Accept）
  void _applyHeaders(HttpClientRequest req) {
    req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
    req.headers.set('Origin', _origin);
    req.headers.set('Referer', _referer);
    req.headers.set(HttpHeaders.userAgentHeader, userAgent);
    req.headers.set(HttpHeaders.cookieHeader, cookie);
  }

  Future<String> _get(String url) async {
    final req = await _http.getUrl(Uri.parse(url));
    _applyHeaders(req);
    final res = await req.close().timeout(timeout);
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw ShareApiException('HTTP ${res.statusCode}：${_brief(text)}');
    }
    return text;
  }

  Future<String> _post(String url) async {
    final req = await _http.postUrl(Uri.parse(url));
    _applyHeaders(req);
    req.contentLength = 0; // 服务端要求 POST，但 body 为空
    final res = await req.close().timeout(timeout);
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw ShareApiException('HTTP ${res.statusCode}：${_brief(text)}');
    }
    return text;
  }

  static String _brief(String s) => s.length > 200 ? '${s.substring(0, 200)}…' : s;

  void close() => _http.close(force: true);
}

class ShareLinkException implements Exception {
  ShareLinkException(this.message);
  final String message;
  @override
  String toString() => 'ShareLinkException: $message';
}

class ShareApiException implements Exception {
  ShareApiException(this.message);
  final String message;
  @override
  String toString() => 'ShareApiException: $message';
}

// ---------------------------------------------------------------------------
// 3. 便捷封装：一次拿到"路线 + 位置 + 指引"
// ---------------------------------------------------------------------------

/// 一次刷新后的完整快照
class ShareSnapshot {
  ShareSnapshot({
    required this.analyzer,
    required this.member,
    required this.routeAt,
  }) : guidance = analyzer.guidanceAt(routeAt.distance),
       remaining = analyzer.remainingAt(routeAt.distance);

  final RouteAnalyzer analyzer;
  final ShareMember member;

  /// 分享者位置在路线上的投影
  final Projection routeAt;
  final Guidance guidance;

  final ({double meters, double seconds, int lights}) remaining;

  double get remainingMinutes => remaining.seconds / 60;

  /// 位置新鲜度（秒）；null 表示分享者没上报位置
  int? get locationLag => member.locationLagSeconds;
}

class ShareSession {
  ShareSession(this.client, this.param);

  final AmapShareClient client;
  final String param;

  RouteAnalyzer? _analyzer;

  RouteAnalyzer? get analyzer => _analyzer;

  /// 拉一次路线 + 位置，算出当前指引。UI 定时调用即可。
  Future<ShareSnapshot> refresh() async {
    final results = await Future.wait([
      client.fetchRoute(param),
      client.fetchInfo(param),
    ]);
    final route = results[0] as RouteEnvelope;
    final info = results[1] as ShareInfoEnvelope;

    final member = info.first ?? (throw ShareApiException('shareMembers 为空'));
    _analyzer = RouteAnalyzer(route.route);

    final li = member.locInfo;
    final projection = li == null
        ? const Projection(0, 0)
        : _analyzer!.project(li.lon, li.lat);

    return ShareSnapshot(
      analyzer: _analyzer!,
      member: member,
      routeAt: projection,
    );
  }
}
