/// 高德分享路线 · 数据模型
///
/// 对应三个接口的 JSON：
///   1. POST /ws/share/lbs/route/restoration   -> RouteEnvelope（路线 + 实时路况）
///   2. POST /ws/share/lbs/info                -> ShareInfoEnvelope（分享者实时状态）
///   3. GET  /ws/user/route/share/info         -> ShareStatusEnvelope（**行前**分享状态）
///
/// 解析原则：**只读需要的字段，其余忽略**。接口字段会随实例变化
/// （例如 cameras[].speed 时有时无、navigationInfo 可能为 null），
/// 所以所有可选字段都给了默认值，不要用 `!` 或必填构造。
library;

import 'dart:convert';

// ---------------------------------------------------------------------------
// JSON 取值小工具：高德同一字段可能给 int 也可能给 double，甚至 int 给成字符串
// ---------------------------------------------------------------------------

double asDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

int asInt(Object? v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

/// 同 [asInt]，但**缺失 / 非法一律返回 null**。
///
/// 用于"状态枚举"类字段（如 `data.status`、`shareStatus`）：这类字段一旦用 0/-1
/// 之类的哨兵值，就会被误当成某个合法状态参与比较；只有 null 能表达"不知道"，
/// 调用方才会正确地"什么都不做"。
int? asIntOrNull(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String asString(Object? v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return fallback;
}

List<Map<String, Object?>> asMapList(Object? v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => e.cast<String, Object?>()).toList();
}

// ---------------------------------------------------------------------------
// 1. restoration
// ---------------------------------------------------------------------------

class RouteEnvelope {
  RouteEnvelope({
    required this.code,
    required this.result,
    required this.message,
    required this.naviType,
    required this.route,
  });

  final String code;
  final bool result;
  final String message;
  final int naviType; // 9 = 驾车
  final AmapRoute route;

  /// `data.restorationInfo` 是一段 **JSON 字符串**，不是对象，要二次解析。
  factory RouteEnvelope.parse(String body) {
    final outer = (jsonDecodeMap(body));
    final data = (outer['data'] as Map?)?.cast<String, Object?>() ?? const {};
    final raw = data['restorationInfo'];
    final inner = raw is String
        ? jsonDecodeMap(raw)
        : (raw as Map).cast<String, Object?>();
    return RouteEnvelope(
      code: asString(outer['code']),
      result: asBool(outer['result']),
      message: asString(outer['message']),
      naviType: asInt(data['naviType']),
      route: AmapRoute((inner['route'] as Map?)?.cast<String, Object?>() ?? const {}),
    );
  }
}

Map<String, Object?> jsonDecodeMap(String s) =>
    (jsonDecode(s) as Map).cast<String, Object?>();

/// 路线整体。每次轮询都会重新规划，**里程与分段可能变化**。
class AmapRoute {
  AmapRoute(Map<String, Object?> m)
      : timestamp = asInt(m['timestamp']),
        version = asString(m['version']),
        code = asString(m['code']),
        startAdcode = asInt(m['start_adcode']),
        endAdcode = asInt(m['end_adcode']),
        message = asString(m['message']),
        roadNames = asMapList(m['roads_names'])
            .map((e) => asString(e['road_name']))
            .toList(),
        paths = asMapList(m['paths']).map(RoutePath.new).toList(),
        facilities = RouteFacilities(
            (m['facilities'] as Map?)?.cast<String, Object?>() ?? const {}),
        incidents = asMapList((m['incident'] as Map?)?['inner'])
            .map(RoadIncident.new)
            .toList();

  final int timestamp; // 毫秒。路况有效时间，分钟级过期
  final String version;
  final String code;
  final int startAdcode;
  final int endAdcode;
  final String message;
  final List<String> roadNames;
  final List<RoutePath> paths;
  final RouteFacilities facilities;
  final List<RoadIncident> incidents;

  RoutePath get main => paths.first;

  /// `road_name_index` 索引到 `roadNames`；越界或缺失时返回"内部道路"。
  String roadNameOf(int? index) {
    if (index == null || index < 0 || index >= roadNames.length) return '内部道路';
    return roadNames[index];
  }
}

class RoutePath {
  RoutePath(Map<String, Object?> m)
      : pathIndex = asInt(m['path_index']),
        distance = asInt(m['distance']),
        travelTime = asInt(m['travel_time']),
        toll = asInt(m['toll']),
        tollLength = asInt(m['toll_length']),
        taxiFare = asInt(m['taxi_fare']),
        trafficLightCount = asInt(m['traffic_light_count']),
        coords = asMapList(m['coords'])
            .map((e) => LonLat(asDouble(e['lon']), asDouble(e['lat'])))
            .toList(),
        segments = asMapList(m['segments']).map(RouteSegment.new).toList(),
        status = asMapList(m['status'])
            .map((e) => TrafficSpan(
                asInt(e['traffic_state']), asInt(e['len'])))
            .toList(),
        group = asMapList(m['group'])
            .map((e) => RoadGroup(
                asString(e['name']), asInt(e['dist']), asInt(e['start_id']),
                asInt(e['count'])))
            .toList();

  final int pathIndex;
  final int distance; // 米
  final int travelTime; // 秒
  final int toll;
  final int tollLength;
  final int taxiFare;
  final int trafficLightCount;

  /// 路线几何，按行进顺序排列（502 点左右）。link 用下标区间引用它。
  final List<LonLat> coords;
  final List<RouteSegment> segments;

  /// 按里程切分的路况段，`len` 之和 == distance
  final List<TrafficSpan> status;

  /// 按道路聚合，`dist` 之和 == distance
  final List<RoadGroup> group;
}

class RouteSegment {
  RouteSegment(Map<String, Object?> m)
      : segmentIndex = asInt(m['segment_index']),
        mainAction = asInt(m['main_action']),
        assistAction = asInt(m['assist_action']),
        links = asMapList(m['links']).map(RouteLink.new).toList();

  final int segmentIndex;

  /// 段末要执行的动作码。枚举高德未公开，见 ActionCodes。
  final int mainAction;
  final int assistAction;
  final List<RouteLink> links;
}

/// 最小路网单元。25 个字段，其中 road_name_index / back_lane / forward_lane 可选。
class RouteLink {
  RouteLink(Map<String, Object?> m)
      : linkIndex = asInt(m['link_index']),
        topoId64 = asInt(m['topo_id_64']),
        trafficState = asInt(m['traffic_state']),
        hasTrafficLight = asInt(m['has_traffic_light']) == 1,
        length = asInt(m['length']),
        lengthPadding = asInt(m['length_padding']),
        travelTime = asInt(m['travel_time']),
        beginIndex = asInt(m['begin_index']),
        endIndex = asInt(m['end_index']),
        isTollRoad = asBool(m['is_toll_road']),
        roadClass = asInt(m['road_class']),
        formWay = asInt(m['form_way']),
        linkType = asInt(m['link_type']),
        ownership = asInt(m['ownership']),
        isOverHead = asBool(m['is_over_head']),
        kmph = asInt(m['kmph']),
        adcode = asInt(m['adcode']),
        laneNum = asInt(m['lane_num']),
        dirction = asInt(m['dirction']),
        mixFork = asInt(m['mix_fork']),
        roadNameIndex = m.containsKey('road_name_index')
            ? asInt(m['road_name_index'])
            : null,
        backLane = (m['back_lane'] as List?)?.map(asInt).toList(),
        forwardLane = (m['forward_lane'] as List?)?.map(asInt).toList();

  final int linkIndex;
  final int topoId64;
  final int trafficState; // 0未知 1畅通 2缓行 3拥堵 4严重拥堵
  final bool hasTrafficLight;
  final int length; // 米
  final int lengthPadding;
  final int travelTime; // 秒
  final int beginIndex; // coords 下标（含）
  final int endIndex; // coords 下标（含）
  final bool isTollRoad;
  final int roadClass;
  final int formWay;
  final int linkType;
  final int ownership;
  final bool isOverHead;
  final int kmph; // 该段参考速度
  final int adcode;
  final int laneNum;
  final int dirction;
  final int mixFork; // 1 = 岔路口
  final int? roadNameIndex;
  final List<int>? backLane; // 车道级状态数组，值 0-4
  final List<int>? forwardLane;
}

class RouteFacilities {
  RouteFacilities(Map<String, Object?> m)
      : cameras = asMapList(m['cameras']).map(RouteFacility.new).toList(),
        general = asMapList(m['general']).map(RouteFacility.new).toList(),
        tollGates = asMapList(m['toll_gate']).map(TollGate.new).toList();

  final List<RouteFacility> cameras;

  /// type==10 时 speed 是限速值(km/h)；type==92 的点经纬度是坏的，必须过滤
  final List<RouteFacility> general;
  final List<TollGate> tollGates;

  /// 经纬度合法的设施（脏数据过滤）
  List<RouteFacility> get validGeneral =>
      general.where((g) => g.hasValidCoord).toList();
}

class RouteFacility {
  RouteFacility(Map<String, Object?> m)
      : pathIndex = asInt(m['path_index']),
        segmentIndex = asInt(m['segment_index']),
        linkIndex = asInt(m['link_index']),
        lon = asDouble(m['lon']),
        lat = asDouble(m['lat']),
        type = asInt(m['type']),
        speed = m.containsKey('speed') ? asInt(m['speed']) : null;

  final int pathIndex;
  final int segmentIndex;
  final int linkIndex;
  final double lon;
  final double lat;
  final int type;
  final int? speed;

  bool get hasValidCoord => lon.abs() <= 180 && lat.abs() <= 90;
}

class TollGate {
  TollGate(Map<String, Object?> m)
      : segmentIndex = asInt(m['seg_idx']),
        lon = asDouble(m['lon']),
        lat = asDouble(m['lat']),
        name = asString(m['name']);

  final int segmentIndex;
  final double lon;
  final double lat;
  final String name;
}

/// 途中事件/警示点。本例中 title/desc 恒为空，只有坐标和类型可用。
class RoadIncident {
  RoadIncident(Map<String, Object?> m)
      : segmentIndex = asInt(m['seg_idx']),
        linkIndex = asInt(m['link_idx']),
        lon = asDouble(m['lon']),
        lat = asDouble(m['lat']),
        type = asInt(m['type']),
        eventType = asInt(m['event_type']),
        layerTag = asInt(m['layer_tag']),
        title = asString(m['title']),
        desc = asString(m['desc']),
        credibility = asInt(m['credibility']),
        roadClass = asInt(m['road_class']);

  final int segmentIndex;
  final int linkIndex;
  final double lon;
  final double lat;
  final int type;
  final int eventType;
  final int layerTag;
  final String title;
  final String desc;
  final int credibility;
  final int roadClass;
}

class TrafficSpan {
  const TrafficSpan(this.trafficState, this.length);
  final int trafficState;
  final int length;
}

class RoadGroup {
  const RoadGroup(this.name, this.dist, this.startId, this.count);
  final String name;
  final int dist;
  final int startId;
  final int count;
}

class LonLat {
  const LonLat(this.lon, this.lat);
  final double lon;
  final double lat;

  @override
  String toString() => '(${lon.toStringAsFixed(5)}, ${lat.toStringAsFixed(5)})';
}

// ---------------------------------------------------------------------------
// 2. share/lbs/info —— 分享者实时状态
// ---------------------------------------------------------------------------

/// 分享 / 导航是否还"活着" —— 两个端点的**两套取值域归一**到同一个枚举。
///
/// 只能由状态字段推导：行前 `data.status`、行中 `data.shareInfo.shareStatus`。
/// **不要**用位置新鲜度、`shareEndTime`、`online`、`drivenDist` 等字段判断结束 ——
/// 实测全都不可靠（`amap-user-route-share-info.md` §5.5）。
enum ShareAlive {
  /// 行前：分享中，分享者还没开始导航（`status == 1`）
  waiting,

  /// 仍在导航中（行前 `status == 4` / 行中 `shareStatus == 1`）
  navigating,

  /// 已停止 / 已结束（行前 `status == 2/3`、行中 `shareStatus == 5/7/6`）
  stopped,

  /// 该共享已过期（行前顶层 `code == 10001`）
  expired,

  /// 未知取值 / 解析不到 —— **必须当成"什么都没发生"，只记日志**。
  ///
  /// 尤其注意 `code == 2/3` 是"参数问题"，绝不能当"行程结束"；取值域也不能混用
  /// （把 `status` 的值拿去比 `shareStatus` 的枚举必然出错）。
  unknown,
}

class ShareInfoEnvelope {
  ShareInfoEnvelope({
    required this.result,
    required this.code,
    required this.message,
    required this.shareStatus,
    required this.members,
    this.raw = '',
  });

  final bool result;
  final String code;
  final String message;

  /// `data.shareInfo.shareStatus`：1 导航中 / 5,7 已停止 / 6 已结束；
  /// null = 字段不存在（当作未知，不要当成 0 或"未开始"）
  final int? shareStatus;

  final List<ShareMember> members;

  /// 原始响应体（逐字）。
  ///
  /// 接口字段会随实例变化（行前端点连成功样本都还没取到），留一份原文才能在
  /// 真机验证页上逐字取证、回填接口文档；解析本身只用上面那些字段。
  final String raw;

  ShareMember? get first => members.isEmpty ? null : members.first;

  /// 状态归一（**行中**取值域）
  ShareAlive get alive => switch (shareStatus) {
        1 => ShareAlive.navigating,
        5 || 6 || 7 => ShareAlive.stopped,
        _ => ShareAlive.unknown,
      };

  factory ShareInfoEnvelope.parse(String body) {
    final outer = jsonDecodeMap(body);
    final data = outer['data'] as Map?;
    final shareInfo = data?['shareInfo'] as Map?;
    return ShareInfoEnvelope(
      result: asBool(outer['result']),
      code: asString(outer['code']),
      message: asString(outer['message']),
      shareStatus: asIntOrNull(shareInfo?['shareStatus']),
      members: asMapList(data?['shareMembers'])
          .map(ShareMember.new)
          .toList(),
      raw: body,
    );
  }
}

class ShareMember {
  ShareMember(Map<String, Object?> m)
      : uid = asInt(m['uid']),
        nickName = asString(m['nickName']),
        avatar = asString(m['avatar']),
        battery = m.containsKey('battery') ? asInt(m['battery']) : null,
        online = asBool(m['online']),
        locationSwitch = asInt(m['locationSwitch']),
        locInfo = m['locInfo'] is Map
            ? LocInfo((m['locInfo']! as Map).cast<String, Object?>())
            : null,
        driveInfo = m['driveInfo'] is Map
            ? DriveInfo((m['driveInfo']! as Map).cast<String, Object?>())
            : null,
        navigationInfo = m['navigationInfo'] is Map
            ? NavigationInfo((m['navigationInfo']! as Map).cast<String, Object?>())
            : null;

  final int uid;
  final String nickName;
  final String avatar;
  final int? battery; // 手机电量 %
  final bool online;
  final int locationSwitch;

  /// **分享者实时位置在这里**，不在 restoration 里
  final LocInfo? locInfo;
  final DriveInfo? driveInfo;

  /// 只有分享者处于"导航中"时才有值，之前是 null
  final NavigationInfo? navigationInfo;

  /// 位置新鲜度（秒）。用服务端时钟算，避免本机时钟偏差。
  int? get locationLagSeconds {
    final li = locInfo;
    if (li == null || li.nowTime == 0) return null;
    return li.nowTime - li.locationUpdateTime;
  }
}

class LocInfo {
  LocInfo(Map<String, Object?> m)
      : lon = asDouble(m['lon']),
        lat = asDouble(m['lat']),
        address = asString(m['address']),
        locationUpdateTime = asInt(m['locationUpdateTime']),
        rcvTime = asInt(m['rcvTime']),
        nowTime = asInt(m['nowTime']),
        speed = asDouble(m['speed']);

  final double lon;
  final double lat;
  final String address;
  final int locationUpdateTime; // 分享者上报位置的时刻
  final int rcvTime; // 服务端收到的时刻
  final int nowTime; // 服务端当前时刻
  final double speed; // km/h
}

class DriveInfo {
  DriveInfo(Map<String, Object?> m)
      : naviType = asInt(m['naviType']),
        updateTime = asInt(m['updateTime']),
        other =
            DriveOtherInfo((m['otherInfo'] as Map? ?? const {}).cast<String, Object?>());

  final int naviType;
  final int updateTime;
  final DriveOtherInfo other;
}

class DriveOtherInfo {
  DriveOtherInfo(Map<String, Object?> m)
      : destination = NamedPoint.maybe(m['destination']),
        outset = NamedPoint.maybe(m['outset']),
        speed = asDouble(m['speed']),
        averageSpeed = asString(m['averageSpeed']), // 注意：是字符串 "0"
        etaDistance = asInt(m['etaDistance']), // 剩余里程 米
        etaTime = asInt(m['etaTime']), // 剩余时间 秒
        tDistance = asInt(m['tDistance']), // 全程 米
        driveTime = asInt(m['driveTime']), // 已行驶 秒
        drivenDist = asInt(m['drivenDist']), // 已行驶 米
        remainingTrafficLights = asInt(m['remainingTrafficLights']),
        remainingIntersections = asInt(m['remainingNumberOfIntersections']);

  final NamedPoint? destination;
  final NamedPoint? outset;
  final double speed;
  final String averageSpeed;
  final int etaDistance;
  final int etaTime;
  final int tDistance;
  final int driveTime;
  final int drivenDist;
  final int remainingTrafficLights;
  final int remainingIntersections;
}

class NamedPoint {
  NamedPoint(this.x, this.y, this.name);
  final double x;
  final double y;
  final String name;

  static NamedPoint? maybe(Object? v) {
    if (v is! Map) return null;
    final m = v.cast<String, Object?>();
    return NamedPoint(asDouble(m['x']), asDouble(m['y']), asString(m['name']));
  }
}

/// 分享者"导航中"的状态。navigationalState 的具体枚举未见文档。
class NavigationInfo {
  NavigationInfo(Map<String, Object?> m)
      : destination = NamedPoint.maybe(m['destination']),
        navigationalState = asInt(m['navigationalState']),
        drivenTime = asInt(m['drivenTime']),
        drivenDist = asInt(m['drivenDist']),
        passedLightCount = asInt(m['passedLightCount']);

  final NamedPoint? destination;
  final int navigationalState;
  final int drivenTime;
  final int drivenDist;
  final int passedLightCount;
}

// ---------------------------------------------------------------------------
// 枚举（含明确标注的"推断"）
// ---------------------------------------------------------------------------

class TrafficState {
  /// 高德惯例。0 也出现在"内部道路"等无路况数据处。
  static const Map<int, String> label = {
    0: '未知',
    1: '畅通',
    2: '缓行',
    3: '拥堵',
    4: '严重拥堵',
  };
  static String of(int v) => label[v] ?? '未知($v)';
}

class ActionCodes {
  /// `main_action` 官方枚举（14 项，0~13）→ 中文名。
  ///
  /// **来源**：高德 Web 服务官方「驾车动作列表」，见
  /// `amap_test01/docs/amap-share-api-reference.md` §2.11。该表有三重佐证
  /// （`main_action` 取值区间闭合 / 用 coords 在段末算的几何转角吻合 / 语义吻合），
  /// 并明确记录了"**早期对 5 个动作码的几何猜测已被官方枚举推翻**"——
  /// 本表就是按官方枚举重建的版本，不要再改回几何猜测。
  ///
  /// 本工程离线样本的几何自检也对得上：3 实测 −16°~−25°（向左前方）、
  /// 7 实测 −174°（左转调头）、9 实测 −8°（靠左）、10 实测 +27°（靠右）、
  /// 8 实测 −2°（直行）、1 实测 −70°、2 实测 +50°~+89°。
  ///
  /// 注意 [of] 的 `0`：官方是"无基本导航动作"，而实测它只出现在**路线终点段**
  /// （样本里唯一的 0 正好落在 totalDistance 上）。所以界面层不要直接用 0 判"到达"，
  /// 用 `naviTurnLabelOfAction()` / `naviTurnTypeOfAction()` —— 它们只在终点段
  /// （`nextRoadName == null`）才显示"到达"。
  static const Map<int, String> label = {
    0: '无基本导航动作',
    1: '左转',
    2: '右转',
    3: '向左前方行驶',
    4: '向右前方行驶',
    5: '向左后方行驶',
    6: '向右后方行驶',
    7: '左转调头',
    8: '直行',
    9: '靠左',
    10: '靠右',
    11: '进入环岛',
    12: '离开环岛',
    13: '减速行驶',
  };

  /// 同上的方向示意字符（**仅用于验证页的文本日志**，界面一律用自绘箭头）
  static const Map<int, String> arrow = {
    0: '·', 1: '↰', 2: '↱', 3: '↖', 4: '↗',
    5: '↙', 6: '↘', 7: '↺', 8: '↑', 9: '←',
    10: '→', 11: '↻', 12: '↪', 13: '↓',
  };

  /// 该码是否属于"官方枚举之外的推断"——现表已按官方文档重建，恒为 false，
  /// 仅保留给"遇到未知码要按几何自检标定"的提示用（见 [RouteAnalyzer.turnAngleAtCoord]）。
  static bool isInferred(int code) => !label.containsKey(code);

  static String of(int code) => label[code] ?? '未知动作($code)';

  static String arrowOf(int code) => arrow[code] ?? '?';
}

// ---------------------------------------------------------------------------
// 3. user/route/share/info —— 行前分享状态
// ---------------------------------------------------------------------------

/// `GET /ws/user/route/share/info`（内部名 `share_route`）的解析结果。
///
/// 这是**行前**视图的端点：分享者还没开始导航时用它，它同时承担"该切端点了"的
/// 通知（`status == 4`）。行中状态在 [ShareInfoEnvelope.shareStatus] —— 两个字段
/// 是两套取值域，不要互套。
///
/// 响应结构见 `amap-user-route-share-info.md` §3：
/// ```json
/// {"code":"1","data":{"status":4,"safeReportParameter":"…"},"result":true,
///  "message":"Successful.","timestamp":"…","version":"…"}
/// ```
class ShareStatusEnvelope {
  ShareStatusEnvelope({
    required this.result,
    required this.code,
    required this.message,
    required this.status,
    required this.safeReportParameter,
    this.raw = '',
  });

  final bool result;

  /// 顶层 code，**字符串**（`"1"` / `"10001"`）。比较前必须转数值。
  final String code;
  final String message;

  /// `data.status`：1 行前分享中 / 4 分享者已开始导航 / 2,3 已停止；
  /// null = 解析不到（data 为 null、字段缺失或值非法）
  final int? status;

  /// `data.safeReportParameter`：只在 `status == 4` 时有意义（页面据此切行中视图）
  final String? safeReportParameter;

  /// 原始响应体（逐字）—— 行前端点还没有成功样本，真机验证页靠它取证
  final String raw;

  /// 该共享已过期（实测值；页面 `hasExpired` 也只判这一个码）
  static const int expiredCode = 10001;

  /// 状态归一（**行前**取值域）
  ///
  /// `code == 2/3` 是**参数问题**（`param` 缺失/双重编码/不是分享数据），
  /// 不是"行程结束" —— 一律落 `unknown`，让调用方什么都不做。
  ShareAlive get alive {
    final codeNum = int.tryParse(code) ?? -1;
    if (codeNum == expiredCode) return ShareAlive.expired;
    if (codeNum != 1) return ShareAlive.unknown;
    return switch (status) {
      1 => ShareAlive.waiting,
      4 => ShareAlive.navigating, // 不是结束：该改用行中端点
      2 || 3 => ShareAlive.stopped,
      _ => ShareAlive.unknown,
    };
  }

  /// `status == 4`：分享者开始导航了，状态改由行中端点（[ShareInfoEnvelope]）负责
  bool get shouldSwitchToNavi => alive == ShareAlive.navigating;

  factory ShareStatusEnvelope.parse(String body) {
    final outer = jsonDecodeMap(body);
    final data = outer['data'] as Map?;
    return ShareStatusEnvelope(
      result: asBool(outer['result']),
      code: asString(outer['code']),
      message: asString(outer['message']),
      status: asIntOrNull(data?['status']),
      safeReportParameter:
          data == null || data['safeReportParameter'] == null
              ? null
              : asString(data['safeReportParameter']),
      raw: body,
    );
  }
}
