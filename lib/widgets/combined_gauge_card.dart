import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// 组合仪表盘的分层几何：**半径的唯一真源**。
///
/// 分层顺序（由圆心向外）：中心数值 → 指针 → **进度环** → 刻度线 → 刻度数字。
/// 静态层（`GaugeStaticPainter`）与动态层（`CombinedGaugePainter`）都从这里取
/// 半径，避免"两层各算一遍"漂移；测试也直接断言这里的几何关系。
///
/// 注意：进度环外缘本来就贴着画布边缘，所以"刻度/数字放到环外"只能靠整体缩径换取——
/// 环的位置由一段**冻结的**外圈预算决定（`ringRadius ≈ half - 54`），比分层交换前小
/// 约 28%（实测 72%~79%）。环半径与刻度数字字号**解耦**：改字号只影响环外的刻度线
/// 与数字，环一动不动；数字则锚在**最外侧**（外沿固定距画布边 `outerPad`）。
/// 各带宽按 `half` 比例取值并 clamp，任意画布尺寸下都成立。
class GaugeGeometry {
  /// 画布中心
  final Offset center;

  /// `min(width, height) / 2`：圆形仪表的可用半宽
  final double half;

  /// 进度环中心线半径（刻度线与刻度数字都在它外面）
  final double ringRadius;

  /// 进度环带宽
  final double ringWidth;

  /// 刻度线外端基准半径（靠数字一侧）
  final double tickOuter;

  /// 粗刻度线长度
  final double tickMajorLen;

  /// 细刻度线长度（与粗刻度**外端对齐**、向内更短）
  final double tickMinorLen;

  /// 刻度数字中心半径
  final double labelRadius;

  /// 刻度数字字号
  final double labelFontSize;

  /// 背景盘半径（铺满卡片、四边微微溢出，维持原有"满卡"观感）
  final double backgroundRadius;

  const GaugeGeometry({
    required this.center,
    required this.half,
    required this.ringRadius,
    required this.ringWidth,
    required this.tickOuter,
    required this.tickMajorLen,
    required this.tickMinorLen,
    required this.labelRadius,
    required this.labelFontSize,
    required this.backgroundRadius,
  });

  /// 环带内缘（指针可用的外边界）
  double get ringInner => ringRadius - ringWidth / 2;

  /// 环带外缘
  double get ringOuter => ringRadius + ringWidth / 2;

  /// 指针尖端半径：环内缘再往里 16px，不碰进度环
  double get pointerTipRadius => ringInner - 16;

  /// 指针根部越过圆心的距离（保持改动前 0.10R 的相对比例）
  double get pointerRootDist => ringRadius * 0.10;

  /// 指针刀片最宽处半径（保持改动前 0.30R 的相对比例）
  double get pointerMidDist => ringRadius * 0.30;

  /// 中心轮毂半径（保持改动前 0.065R 的相对比例）
  double get hubRadius => ringRadius * 0.065;

  /// 中心大数字字号：按**环内缘**定标而不是 [ringRadius]。
  /// 缩径后若仍按 `0.24R` 会掉到 ~29px（主读数变小），故改由可用圆心区决定。
  double get centerValueFontSize => ringInner * 0.34;

  /// 由画布尺寸推导整套半径。
  ///
  /// 推导顺序很关键（决定了"改字号会不会把环带着一起动"）：
  /// 1. **先冻结环**：`ringRadius` 只由画布尺寸算（复用"数字 13px 那版"的外圈预算
  ///    常量），与刻度数字大小**完全无关**——所以调字号只影响环外的刻度线与数字。
  /// 2. **再把环外剩余空间全给数字**：刻度线之后剩下的带宽，按"最外那个 3 字符标签
  ///    不出画布"（横向约束比行高更早触顶）反解出字号，于是数字自动吃到最大。
  factory GaugeGeometry.of(Size size) {
    final half =
        (size.width < size.height ? size.width : size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    const outerPad = 3.0; // 数字外沿 → 画布边缘（横向最外标签的余量）
    const labelGap = 4.0; // 数字墨迹内沿 → 刻度线外端（实机要看到的缝）
    const tickGap = 3.0; // 刻度线内端 → 环外缘

    // 数字墨迹的"径向深度"：数字行是**轴对齐矩形**，横向宽标签（12k / 210）在
    // 30° 附近最贴近圆心——最近点不是半行高 0.6f，而是行内角。
    // 实测（Roboto Mono Bold，325×328 真实渲染 → 半径直方图）：
    //   墨迹内沿 ≈ 0.92f、墨迹外沿 ≈ 0.86f（行框外沿恒为 0.9f）。
    // 取 0.95f（+3% 余量）作为"内沿深度"，只按 0.6f 留缝就会让数字扎进刻度线。
    const labelDepthRatio = 0.95;

    final ringWidth = (half * 0.16).clamp(18.0, 27.0);

    // ── 1) 环位置：冻结，只由画布尺寸决定 ──
    // 下面的"参考预算"是环半径的历史定义（参考数字行高 + 参考粗刻度 + 三个间隙），
    // 与真实数字字号解耦；改刻度数字字号不会再让环缩/涨。
    final refLabelBox = (half * 0.080).clamp(9.5, 13.0) * 1.2;
    final refTickMajorLen = (half * 0.059).clamp(6.0, 10.0);
    final ringOuterBudget =
        8.0 + refLabelBox + 3.0 + refTickMajorLen + 4.0 + ringWidth / 2;
    var ringRadius = half - ringOuterBudget;
    if (ringRadius < ringWidth) {
      // 极小画布兜底（half < ~40px 才会触发）：宁可环小，也不能让环内缘 ≤ 0
      ringRadius = (half - outerPad) * 0.5;
    }

    // ── 2) 环外：刻度数字锚在**刻度线一侧**（保证有缝），字号随之解出 ──
    // 刻度线相应收短一点（8 → 6），把空间让给"数字 + 缝"
    final tickMajorLen = (half * 0.037).clamp(4.5, 6.0);
    final tickMinorLen = tickMajorLen * 0.5;
    final tickOuter = ringRadius + ringWidth / 2 + tickGap + tickMajorLen;

    // 字号上限：同时满足两条
    //   ① 数字墨迹内沿让出 labelGap：labelRadius = tickOuter + labelGap + 0.95f
    //   ② 数字行外沿不出画布：        labelRadius + 0.9f ≤ half - outerPad
    //   ⇒ f ≤ (half - outerPad - tickOuter - labelGap) / (0.95 + 0.9)
    final maxLabelFontSize = max(
      (half - outerPad - tickOuter - labelGap) / (labelDepthRatio + 0.9),
      6.0,
    );

    // 实际字号 = 上限 × labelFill。labelFill < 1 时数字变小、缝不变，
    // 多出来的空间全部落到**外边界那一侧**（即"减小字号绝不减小外距"）。
    const labelFill = 1.0;
    final labelFontSize = max(
      min(maxLabelFontSize * labelFill, maxLabelFontSize),
      9.5,
    );

    return GaugeGeometry(
      center: center,
      half: half,
      ringRadius: ringRadius,
      ringWidth: ringWidth,
      tickOuter: tickOuter,
      tickMajorLen: tickMajorLen,
      tickMinorLen: tickMinorLen,
      // 数字墨迹内沿距刻度线外端恒为 [labelGap]（间距锚点）；
      // 另一头用 min 兜底：极小画布退化时宁可压刻度线，也不能越出画布。
      labelRadius: min(
        tickOuter + labelGap + labelDepthRatio * labelFontSize,
        (half - outerPad) - 0.9 * labelFontSize,
      ),
      labelFontSize: labelFontSize,
      backgroundRadius: half + outerPad,
    );
  }
}

/// 组合仪表盘卡片（转速+时速）
/// 量程参数从 SettingsProvider 动态读取，修改设置后实时生效
class CombinedGaugeCard extends StatelessWidget {
  const CombinedGaugeCard({super.key});

  @override
  Widget build(BuildContext context) {
    // 精确订阅 OBDDataProvider 中仪表盘实际用到的字段
    final rpm = context.select<OBDDataProvider, int>((p) => p.data.rpm);
    final speed = context.select<OBDDataProvider, int>((p) => p.data.speed);
    final peakRpm = context.select<OBDDataProvider, int>((p) => p.peakRpm);
    final peakSpeed = context.select<OBDDataProvider, int>((p) => p.peakSpeed);
    // gear 字段由 GearDisplayPanel 单独订阅，此处传 0 保持画布不含档位
    // codeflicker-fix: OPT-Issue-6/omvh7ni7j93qpiynr7sw
    final maxRpm = context.select<SettingsProvider, int>((s) => s.maxRpm);
    final warnRpm = context.select<SettingsProvider, int>((s) => s.warnRpm);
    final dangerRpm = context.select<SettingsProvider, int>((s) => s.dangerRpm);
    final maxSpeed = context.select<SettingsProvider, int>((s) => s.maxSpeed);
    final warnSpeed = context.select<SettingsProvider, int>((s) => s.warnSpeed);
    final dangerSpeed =
        context.select<SettingsProvider, int>((s) => s.dangerSpeed);
    // 不再套 8px 内边距：画布＝卡盒（原来画布比卡盒小一圈，是整个仪表"显小"的主因）。
    // 数字自带 outerPad=3 的外沿留白，危险呼吸边框由上层 DangerPulseOverlay 画在卡盒边缘。
    return LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              // 静态层：背景盘/进度环暗格/刻度线与刻度数字（在环外侧），
              // 仅量程设置或尺寸变化时重绘
              CustomPaint(
                size: size,
                painter: GaugeStaticPainter(
                  maxRpm: maxRpm,
                  warnRpm: warnRpm,
                  dangerRpm: dangerRpm,
                  maxSpeed: maxSpeed,
                  warnSpeed: warnSpeed,
                  dangerSpeed: dangerSpeed,
                ),
              ),
              // 动态层：进度/指针/数值，独立图层避免波及静态层
              RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: CombinedGaugePainter(
                    rpm: rpm,
                    speed: speed,
                    gear: 0,
                    peakRpm: peakRpm,
                    peakSpeed: peakSpeed,
                    maxRpm: maxRpm,
                    warnRpm: warnRpm,
                    dangerRpm: dangerRpm,
                    maxSpeed: maxSpeed,
                    warnSpeed: warnSpeed,
                    dangerSpeed: dangerSpeed,
                  ),
                ),
              ),
            ],
          );
        },
    );
  }
}

/// 组合仪表盘绘制器
/// 量程参数从 SettingsProvider 注入，不再使用 static const
class CombinedGaugePainter extends CustomPainter {
  final int rpm;
  final int speed;
  final int gear;

  // 峰值保持（Peak-Hold）
  final int peakRpm;
  final int peakSpeed;

  // 量程参数（从 SettingsProvider 注入）
  final int maxRpm;
  final int warnRpm;
  final int dangerRpm;
  final int maxSpeed;
  final int warnSpeed;
  final int dangerSpeed;

  /// 车速到角度的线性映射
  static double speedToAngle(double speed, int maxSpeed) {
    return (speed / maxSpeed) * pi;
  }

  /// RPM 到角度的非线性映射
  /// 0-4000RPM 占据前 20% 角度，4000-maxRpm 占据后 80%
  static double rpmToAngle(double rpm, int maxRpm) {
    const double normalMax = 4000;
    const double normalRatio = 0.20;

    if (rpm <= normalMax) {
      return (rpm / normalMax) * normalRatio * pi;
    } else {
      final double extendedMax = maxRpm - 4000;
      return normalRatio * pi +
          ((rpm - normalMax) / extendedMax) * (1 - normalRatio) * pi;
    }
  }

  /// 将角度（从 rpmToAngle 映射空间）近似还原为 RPM 值，用于刻度格着色
  static double angleToApproxRpm(double angle, int maxRpm) {
    const double normalMax = 4000;
    const double normalRatio = 0.20;
    final double normalEndAngle = normalRatio * pi;

    if (angle <= normalEndAngle) {
      return (angle / normalEndAngle) * normalMax;
    } else {
      return normalMax +
          ((angle - normalEndAngle) / ((1 - normalRatio) * pi)) *
              (maxRpm - normalMax);
    }
  }

  CombinedGaugePainter({
    required this.rpm,
    required this.speed,
    required this.gear,
    this.peakRpm = 0,
    this.peakSpeed = 0,
    this.maxRpm = 12000,
    this.warnRpm = 7000,
    this.dangerRpm = 9000,
    this.maxSpeed = 240,
    this.warnSpeed = 120,
    this.dangerSpeed = 180,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 几何只在 paint 时拿得到 size，故按尺寸现算（无状态、不影响 shouldRepaint）
    final g = GaugeGeometry.of(size);

    // 绘制上半圆 RPM 进度
    _drawRPMProgress(canvas, g);

    // 绘制下半圆 Speed 进度
    _drawSpeedProgress(canvas, g);

    // 绘制指针
    _drawRPMPointer(canvas, g);
    _drawSpeedPointer(canvas, g);
    _drawCenterHub(canvas, g);

    // 绘制峰值保持标记（在指针之上，中心值之下）
    _drawPeakMarkers(canvas, g);

    // 绘制中心数值
    _drawCenterValues(canvas, g);

    // 温度与电压由右上方 VehicleHealthCard 统一展示。
  }

  /// RPM 分节刻度条：同色激活格合并为一个 Path，单次描边绘制，无辉光层
  void _drawRPMProgress(Canvas canvas, GaugeGeometry g) {
    // 分节刻度条：60 格，覆盖上半圆 180°
    const totalSegments = 60;
    const totalAngle = pi;
    const fillRatio = 0.65;
    final segAngle = totalAngle / totalSegments;
    final segFill = segAngle * fillRatio;
    final segGap = segAngle * (1 - fillRatio);

    final currentSweep =
        CombinedGaugePainter.rpmToAngle(rpm.toDouble(), maxRpm);
    final rect = Rect.fromCircle(center: g.center, radius: g.ringRadius);

    // 按颜色分组合并激活格
    final pathsByColor = <Color, Path>{};
    for (int i = 0; i < totalSegments; i++) {
      final segMidSweep = (i + 0.5) * segAngle; // 该格中点对应的角度
      final isActive = segMidSweep <= currentSweep;

      if (!isActive) continue; // 暗格已在静态层绘制

      // 根据该格对应的 RPM 值确定颜色
      // 使用逆映射：由角度比例还原近似 RPM
      final segMidRpm =
          CombinedGaugePainter.angleToApproxRpm(segMidSweep, maxRpm);
      final Color segColor;
      if (segMidRpm <= warnRpm) {
        segColor = AppTheme.gaugeNormal;
      } else if (segMidRpm <= dangerRpm) {
        segColor = AppTheme.gaugeWarn;
      } else {
        segColor = AppTheme.gaugeDanger;
      }

      final startAngle = pi + i * segAngle + segGap / 2;
      pathsByColor
          .putIfAbsent(segColor, () => Path())
          .addArc(rect, startAngle, segFill);
    }

    // 每种颜色：同色激活格合并为一个 Path，只画实体层（不做辉光——
    // 多层描边视觉偏脏，且调用量会随数据频率放大）
    pathsByColor.forEach((color, path) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = g.ringWidth
          ..strokeCap = StrokeCap.butt,
      );
    });
  }

  /// 速度进度弧：单次 SweepGradient 绘制，替代原 60 段循环
  void _drawSpeedProgress(Canvas canvas, GaugeGeometry g) {
    final sweepAngle =
        CombinedGaugePainter.speedToAngle(speed.toDouble(), maxSpeed);
    if (sweepAngle <= 0) return;

    // 末端颜色（当前速度阶段）
    Color endColor;
    if (speed <= warnSpeed) {
      endColor = AppTheme.gaugeNormal;
    } else if (speed <= dangerSpeed) {
      endColor = AppTheme.gaugeWarn;
    } else {
      endColor = AppTheme.gaugeDanger;
    }

    final rect = Rect.fromCircle(center: g.center, radius: g.ringRadius);

    // 单弧 + SweepGradient：起点（π-sweepAngle，当前速度端）亮 → 终点（π，低速端）浅
    canvas.drawArc(
      rect,
      pi - sweepAngle,
      sweepAngle,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: pi - sweepAngle,
          endAngle: pi,
          colors: [
            endColor,
            endColor.withValues(alpha: 0.15),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = g.ringWidth
        ..strokeCap = StrokeCap.butt,
    );
  }

  void _drawRPMPointer(Canvas canvas, GaugeGeometry g) {
    if (rpm <= 0) return;

    final center = g.center;

    // 动态颜色：跟随 RPM 区间变化
    Color color;
    if (rpm <= warnRpm) {
      color = AppTheme.gaugeNormal;
    } else if (rpm <= dangerRpm) {
      color = AppTheme.gaugeWarn;
    } else {
      color = AppTheme.gaugeDanger;
    }

    final sweepAngle = CombinedGaugePainter.rpmToAngle(rpm.toDouble(), maxRpm);
    final angle = pi + sweepAngle;
    final pointerLength = g.pointerTipRadius;
    const halfWidth = 3.5;

    // 指针尖端（贴近环带内缘）
    final tipX = center.dx + pointerLength * cos(angle);
    final tipY = center.dy + pointerLength * sin(angle);

    // 指针根部（从圆心略微后退）
    final rootDist = g.pointerRootDist;
    final rootX = center.dx - rootDist * cos(angle);
    final rootY = center.dy - rootDist * sin(angle);

    // 刀片最宽处（距圆心约 30%）
    final perpAngle = angle + pi / 2;
    final midDist = g.pointerMidDist;
    final midX = center.dx + midDist * cos(angle);
    final midY = center.dy + midDist * sin(angle);
    final leftX = midX + halfWidth * cos(perpAngle);
    final leftY = midY + halfWidth * sin(perpAngle);
    final rightX = midX - halfWidth * cos(perpAngle);
    final rightY = midY - halfWidth * sin(perpAngle);

    // 刀片路径：菱形（尖端→左宽→根部→右宽）
    final bladePath = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(leftX, leftY)
      ..lineTo(rootX, rootY)
      ..lineTo(rightX, rightY)
      ..close();

    // 实体刀片（渐变：根部→尖端高亮）
    // 已精简：删除双层光晕与尖端发光点（与进度弧末端发光位置重复，降低视觉噪音与 blur 开销）
    final bladeRect = Rect.fromPoints(Offset(rootX, rootY), Offset(tipX, tipY));
    canvas.drawPath(
      bladePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.92),
          ],
        ).createShader(bladeRect)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawSpeedPointer(Canvas canvas, GaugeGeometry g) {
    if (speed <= 0) return;

    final center = g.center;

    // 动态颜色：跟随速度区间变化
    Color color;
    if (speed <= warnSpeed) {
      color = AppTheme.gaugeNormal;
    } else if (speed <= dangerSpeed) {
      color = AppTheme.gaugeWarn;
    } else {
      color = AppTheme.gaugeDanger;
    }

    final sweepAngle =
        CombinedGaugePainter.speedToAngle(speed.toDouble(), maxSpeed);
    final angle = pi - sweepAngle;
    final pointerLength = g.pointerTipRadius;
    const halfWidth = 3.5;

    // 指针尖端
    final tipX = center.dx + pointerLength * cos(angle);
    final tipY = center.dy + pointerLength * sin(angle);

    // 指针根部
    final rootDist = g.pointerRootDist;
    final rootX = center.dx - rootDist * cos(angle);
    final rootY = center.dy - rootDist * sin(angle);

    // 刀片最宽处
    final perpAngle = angle + pi / 2;
    final midDist = g.pointerMidDist;
    final midX = center.dx + midDist * cos(angle);
    final midY = center.dy + midDist * sin(angle);
    final leftX = midX + halfWidth * cos(perpAngle);
    final leftY = midY + halfWidth * sin(perpAngle);
    final rightX = midX - halfWidth * cos(perpAngle);
    final rightY = midY - halfWidth * sin(perpAngle);

    final bladePath = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(leftX, leftY)
      ..lineTo(rootX, rootY)
      ..lineTo(rightX, rightY)
      ..close();

    // 实体刀片（渐变）
    // 已精简：删除双层光晕与尖端发光点（与进度弧末端发光位置重复，降低视觉噪音与 blur 开销）
    final bladeRect = Rect.fromPoints(Offset(rootX, rootY), Offset(tipX, tipY));
    canvas.drawPath(
      bladePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.92),
          ],
        ).createShader(bladeRect)
        ..style = PaintingStyle.fill,
    );
  }

  /// 金属轮毂（统一替代两个指针末尾的中心白点）
  void _drawCenterHub(Canvas canvas, GaugeGeometry g) {
    final center = g.center;
    final hubR = g.hubRadius;

    // 金属质感径向渐变圆盘
    canvas.drawCircle(
      center,
      hubR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            AppTheme.primary.withValues(alpha: 0.7),
            AppTheme.backgroundDark,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: hubR)),
    );

    // 顶层高光小点（偏左上，营造金属反光感）
    canvas.drawCircle(
      center.translate(-hubR * 0.22, -hubR * 0.22),
      hubR * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  /// 峰值保持标记（Peak-Hold）：弧上覆盖一条短亮线，无发光层
  /// 无数字标签；峰值 > 0 才绘制
  void _drawPeakMarkers(Canvas canvas, GaugeGeometry g) {
    final rect = Rect.fromCircle(center: g.center, radius: g.ringRadius);

    // ── RPM 峰值标记（上半圆） ──
    if (peakRpm > 0) {
      final peakAngle = pi + rpmToAngle(peakRpm.toDouble(), maxRpm);
      final peakColor = zoneColor(peakRpm, warnRpm, dangerRpm);
      const markerArc = 0.03; // 约 5° 短弧段

      // 实体层：弧正上方覆盖
      canvas.drawArc(
        rect,
        peakAngle - markerArc / 2,
        markerArc,
        false,
        Paint()
          ..color = peakColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.butt,
      );
    }

    // ── 速度峰值标记（下半圆） ──
    if (peakSpeed > 0) {
      final peakAngle = pi - speedToAngle(peakSpeed.toDouble(), maxSpeed);
      final peakColor = zoneColor(peakSpeed, warnSpeed, dangerSpeed);
      const markerArc = 0.03;

      // 实体层
      canvas.drawArc(
        rect,
        peakAngle - markerArc / 2,
        markerArc,
        false,
        Paint()
          ..color = peakColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  /// 根据数值/阈值确定仪表分区色（青/琥珀/红）
  static Color zoneColor(int value, int warn, int danger) {
    if (value <= warn) return AppTheme.gaugeNormal;
    if (value <= danger) return AppTheme.gaugeWarn;
    return AppTheme.gaugeDanger;
  }

  /// 中心数值块：RPM 在上、速度在下，均跟随区间变色。
  ///
  /// 缩径后改用**环内缘**（`g.ringInner`）定标而不是环半径：主读数不跟着环径
  /// 一起变小；数值与单位采用**顺序布局**（单位永远贴着数值放），避免调字号时重叠。
  void _drawCenterValues(Canvas canvas, GaugeGeometry g) {
    final center = g.center;
    final innerR = g.ringInner;
    final valueFontSize = g.centerValueFontSize;
    final unitFontSize = valueFontSize * 0.34;
    final gap = innerR * 0.02;

    // RPM 在上半圆视觉中心：数值在 center 上方， 单位在数值更上方
    // RPM 值 — 跟随区间变色
    final rpmColor = zoneColor(rpm, warnRpm, dangerRpm);
    final rpmValueTop = center.dy - innerR * 0.72;
    final rpmUnitTop = rpmValueTop - unitFontSize * 1.2 - gap;

    final rpmTextSpan = TextSpan(
      text: rpm.toString(),
      style: AppFonts.displayStyle(
        fontSize: valueFontSize,
        color: rpmColor,
        letterSpacing: -1,
      ),
    );
    final rpmTextPainter = TextPainter(
      text: rpmTextSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    rpmTextPainter.paint(
      canvas,
      Offset(center.dx - rpmTextPainter.width / 2, rpmValueTop),
    );

    // RPM 单位 (在RPM值更上方) — 同色 70% 透明度
    // painter 里没有 BuildContext，主题 fontFamily 继承链是断的，
    // 必须显式指定字体族，否则会掉到系统默认字体（和大数字不是一个字体）
    final rpmUnitSpan = TextSpan(
      text: 'RPM',
      style: AppFonts.monoStyle(
        fontSize: unitFontSize,
        color: rpmColor.withValues(alpha: 0.7),
      ).copyWith(fontWeight: FontWeight.w500),
    );
    final rpmUnitPainter = TextPainter(
      text: rpmUnitSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    rpmUnitPainter.paint(
      canvas,
      Offset(center.dx - rpmUnitPainter.width / 2, rpmUnitTop),
    );

    // Speed 在下半圆视觉中心：数值在 center 下方， 单位在数值更下方
    // Speed 值 — 跟随区间变色
    final speedColor = zoneColor(speed, warnSpeed, dangerSpeed);
    final speedValueTop = center.dy + innerR * 0.30;
    final speedUnitTop = speedValueTop + valueFontSize * 1.2 + gap;

    final speedTextSpan = TextSpan(
      text: '$speed',
      style: AppFonts.displayStyle(
        fontSize: valueFontSize,
        color: speedColor,
        letterSpacing: -1,
      ),
    );
    final speedTextPainter = TextPainter(
      text: speedTextSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    speedTextPainter.paint(
      canvas,
      Offset(center.dx - speedTextPainter.width / 2, speedValueTop),
    );

    // Speed 单位 (在Speed值下方) — 同色 70% 透明度
    final speedUnitSpan = TextSpan(
      text: 'km/h',
      style: AppFonts.monoStyle(
        fontSize: unitFontSize,
        color: speedColor.withValues(alpha: 0.7),
      ).copyWith(fontWeight: FontWeight.w500),
    );
    final speedUnitPainter = TextPainter(
      text: speedUnitSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    speedUnitPainter.paint(
      canvas,
      Offset(center.dx - speedUnitPainter.width / 2, speedUnitTop),
    );
  }

  @override
  bool shouldRepaint(covariant CombinedGaugePainter oldDelegate) {
    return oldDelegate.rpm != rpm ||
        oldDelegate.speed != speed ||
        oldDelegate.gear != gear ||
        oldDelegate.peakRpm != peakRpm ||
        oldDelegate.peakSpeed != peakSpeed ||
        oldDelegate.maxRpm != maxRpm ||
        oldDelegate.warnRpm != warnRpm ||
        oldDelegate.dangerRpm != dangerRpm ||
        oldDelegate.maxSpeed != maxSpeed ||
        oldDelegate.warnSpeed != warnSpeed ||
        oldDelegate.dangerSpeed != dangerSpeed;
  }
}

/// 仪表盘静态层绘制器：背景圆盘、进度环暗格、刻度线与刻度数字
/// 分层：进度环在里、刻度线与数字在外（数字最外）；几何全部取自 [GaugeGeometry]
/// 仅量程设置/尺寸变化时重绘（配合 RepaintBoundary 吃图层缓存）
class GaugeStaticPainter extends CustomPainter {
  final int maxRpm;
  final int warnRpm;
  final int dangerRpm;
  final int maxSpeed;
  final int warnSpeed;
  final int dangerSpeed;

  GaugeStaticPainter({
    this.maxRpm = 12000,
    this.warnRpm = 7000,
    this.dangerRpm = 9000,
    this.maxSpeed = 240,
    this.warnSpeed = 120,
    this.dangerSpeed = 180,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final g = GaugeGeometry.of(size);

    _drawBackground(canvas, g);
    _drawTickBackground(canvas, g);
    _drawTicks(canvas, g);
  }

  void _drawBackground(Canvas canvas, GaugeGeometry g) {
    // 背景渐变（半径铺满卡片、四边微微溢出，维持"满卡"观感）
    final gradient = RadialGradient(
      colors: [
        AppTheme.backgroundDark,
        AppTheme.slateGray.withValues(alpha: 0.5),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: g.center, radius: g.backgroundRadius),
      );

    canvas.drawCircle(g.center, g.backgroundRadius, paint);
  }

  /// 进度环暗格：**属于环**，跟着环一起内移，不随刻度外移
  void _drawTickBackground(Canvas canvas, GaugeGeometry g) {
    // 上半圆：60 个暗格背景（与分节刻度条对齐）
    const totalSegments = 60;
    const totalAngle = pi;
    const fillRatio = 0.65;
    final segAngle = totalAngle / totalSegments;
    final segFill = segAngle * fillRatio;
    final segGap = segAngle * (1 - fillRatio);

    final ringRect = Rect.fromCircle(center: g.center, radius: g.ringRadius);

    final bgPaint = Paint()
      ..color = AppTheme.slateGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = g.ringWidth
      ..strokeCap = StrokeCap.butt;

    for (int i = 0; i < totalSegments; i++) {
      final startAngle = pi + i * segAngle + segGap / 2;
      canvas.drawArc(ringRect, startAngle, segFill, false, bgPaint);
    }

    // 下半圆：保持连续背景弧
    final speedBgPaint = Paint()
      ..color = AppTheme.slateGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = g.ringWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(ringRect, 0, pi, false, speedBgPaint);
  }

  /// 刻度线与刻度数字：全部画在**进度环外侧**
  /// （细刻度与粗刻度外端对齐、向内更短；数字在刻度更外侧）
  void _drawTicks(Canvas canvas, GaugeGeometry g) {
    // 公共 0 刻度 - 在正下方（π 角度）：RPM 与速度两半共用一条，只画一次。
    // 旧版"共享 0 + RPM 列表里的 0 + 速度列表里的 0"会在同一像素上画三遍，
    // 颜色取刻度分区色（＝旧版最后覆盖上去、实际可见的那个颜色）。
    final zeroColor = _tickZoneColor(0, warnRpm, dangerRpm);
    _drawTickLine(canvas, g, pi, g.tickMajorLen, zeroColor, 4);
    _drawTickLabel(canvas, g, pi, '0', zeroColor.withValues(alpha: 0.8));

    // 上半圆刻度 (RPM) - 顺时针从π到2π，经过上方
    // 大刻度动态生成：0-4000 每 2000 一个，4000-maxRpm 每 1000 一个
    // （0 由上面的公共刻度负责，不重复画）
    final rpmMajorTicks = <int>[2000];
    for (int v = 4000; v <= maxRpm; v += 1000) {
      rpmMajorTicks.add(v);
    }
    for (final i in rpmMajorTicks) {
      // 顺时针：π → 3π/2 → 2π
      final sweepAngle = CombinedGaugePainter.rpmToAngle(i.toDouble(), maxRpm);
      final angle = pi + sweepAngle;
      final tickColor = _tickZoneColor(i, warnRpm, dangerRpm);

      _drawTickLine(canvas, g, angle, g.tickMajorLen, tickColor, 4);

      // 刻度值 - 跟随分区色（80% 透明度）
      _drawTickLabel(
        canvas,
        g,
        angle,
        i >= 1000 ? '${i ~/ 1000}k' : i.toString(),
        tickColor.withValues(alpha: 0.8),
      );
    }

    // 细粒度刻度 (RPM) - 根据区间变色
    // 0-4000 每 1000 的中间值（1000,3000），4000+ 每 1000 的中间值（4500,5500,...）
    final rpmFineTicks = <int>[1000, 3000];
    for (int v = 4500; v < maxRpm; v += 1000) {
      rpmFineTicks.add(v);
    }
    for (final i in rpmFineTicks) {
      final sweepAngle = CombinedGaugePainter.rpmToAngle(i.toDouble(), maxRpm);
      final angle = pi + sweepAngle;
      // 与粗刻度外端对齐，向内更短
      _drawTickLine(
        canvas,
        g,
        angle,
        g.tickMinorLen,
        _tickZoneColor(i, warnRpm, dangerRpm).withValues(alpha: 0.6),
        1.5,
      );
    }

    // 下半圆刻度 (Speed) - 逆时针从π到0，经过下方
    // 大刻度：每 30 km/h，动态生成到 maxSpeed
    // （不含 maxSpeed 本身，避免与末端重叠；也不含 0，由公共刻度负责）
    final speedMajorTicks = <int>[];
    for (int v = 30; v < maxSpeed; v += 30) {
      speedMajorTicks.add(v);
    }
    for (final i in speedMajorTicks) {
      // 逆时针：π → π/2 → 0
      final sweepAngle =
          CombinedGaugePainter.speedToAngle(i.toDouble(), maxSpeed);
      final angle = pi - sweepAngle;
      final tickColor = _tickZoneColor(i, warnSpeed, dangerSpeed);

      _drawTickLine(canvas, g, angle, g.tickMajorLen, tickColor, 4);

      // 刻度值 - 跟随分区色（80% 透明度）
      _drawTickLabel(
        canvas,
        g,
        angle,
        i.toString(),
        tickColor.withValues(alpha: 0.8),
      );
    }

    // 小刻度 (Speed) - 每 30 km/h 的中间值（15, 45, ...），动态生成
    final speedFineTicks = <int>[];
    for (int v = 15; v < maxSpeed; v += 30) {
      speedFineTicks.add(v);
    }
    for (final i in speedFineTicks) {
      final sweepAngle =
          CombinedGaugePainter.speedToAngle(i.toDouble(), maxSpeed);
      final angle = pi - sweepAngle;
      _drawTickLine(
        canvas,
        g,
        angle,
        g.tickMinorLen,
        _tickZoneColor(i, warnSpeed, dangerSpeed).withValues(alpha: 0.6),
        1.5,
      );
    }
  }

  /// 画一条径向刻度线：外端固定在 [GaugeGeometry.tickOuter]，向圆心延伸 [len]
  void _drawTickLine(
    Canvas canvas,
    GaugeGeometry g,
    double angle,
    double len,
    Color color,
    double strokeWidth,
  ) {
    final outerR = g.tickOuter;
    final innerR = outerR - len;
    canvas.drawLine(
      Offset(
        g.center.dx + innerR * cos(angle),
        g.center.dy + innerR * sin(angle),
      ),
      Offset(
        g.center.dx + outerR * cos(angle),
        g.center.dy + outerR * sin(angle),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  /// 画刻度数字：中心落在 [GaugeGeometry.labelRadius] 那个同心圆上
  void _drawTickLabel(
    Canvas canvas,
    GaugeGeometry g,
    double angle,
    String text,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppFonts.monoStyle(fontSize: g.labelFontSize, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        g.center.dx + g.labelRadius * cos(angle) - textPainter.width / 2,
        g.center.dy + g.labelRadius * sin(angle) - textPainter.height / 2,
      ),
    );
  }

  /// 刻度线/数字的分区色：临界值本身算入**下一档**（与数值/指针所用的
  /// [CombinedGaugePainter.zoneColor] 的 `<=` 语义不同），保持改动前观感
  static Color _tickZoneColor(int value, int warn, int danger) {
    if (value < warn) return AppTheme.gaugeNormal;
    if (value < danger) return AppTheme.gaugeWarn;
    return AppTheme.gaugeDanger;
  }

  @override
  bool shouldRepaint(covariant GaugeStaticPainter oldDelegate) {
    return oldDelegate.maxRpm != maxRpm ||
        oldDelegate.warnRpm != warnRpm ||
        oldDelegate.dangerRpm != dangerRpm ||
        oldDelegate.maxSpeed != maxSpeed ||
        oldDelegate.warnSpeed != warnSpeed ||
        oldDelegate.dangerSpeed != dangerSpeed;
  }
}
