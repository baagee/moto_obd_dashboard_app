# CYBER-CYCLE OBD Dashboard 设计风格指南

> 生成日期: 2026-03-03

---

## 一、设计风格概述

**风格定位：** 赛博朋克 / 未来科技感 / 暗黑系仪表盘

**核心关键词：**
- 深色背景 + 霓虹发光效果
- 半透明玻璃拟态（Glassmorphism）
- 几何图形与自定义绘制
- 信息密集但层次分明
- 科技感字体与标签

---

## 二、色彩系统

### 主色调

| 名称 | 色值 | 用途 |
|------|------|------|
| **Primary** | `#0DA6F2` | 主强调色、边框、激活状态 |
| **Accent Cyan** | `#00F2FF` | 高亮数据、渐变终点 |
| **Accent Green** | `#00E676` | 成功状态、正常连接 |
| **Accent Orange** | `#FFAB40` | 警告、温度数据 |
| **Accent Red** | `#FF4D4D` | 错误、危险状态 |

### 背景色

| 名称 | 色值 | 用途 |
|------|------|------|
| **Background Dark** | `#0A1114` | 主背景 |
| **Surface** | `#162229` | 卡片背景、面板背景 |
| **Surface Translucent** | `#162229 @ 50%` | 半透明容器 |

### 文字色

| 名称 | 色值 | 用途 |
|------|------|------|
| **Text Primary** | `#FFFFFF` | 主要数据、标题 |
| **Text Secondary** | `#9CA3AF` | 次要标签、说明文字 |
| **Text Muted** | `#6B7280` | 小标签、时间戳 |

### 颜色透明度规范

```dart
// 边框透明度
borderColor.withOpacity(0.2)   // 普通边框
borderColor.withOpacity(0.3)   // 强调边框
borderColor.withOpacity(0.1)   // 弱边框

// 背景透明度
surface.withOpacity(0.5)       // 半透明卡片
surface.withOpacity(0.8)       // 导航栏/状态栏

// 标签透明度
primary.withOpacity(0.6)       // 标签文字
primary.withOpacity(0.4)       // 底部信息
```

---

## 三、圆角规范

| 元素 | 圆角值 |
|------|--------|
| 卡片容器 | `12px` |
| 按钮 | `8px` |
| 输入框 | `8px` |
| 进度条 | `6px` / `3px` (内部) |
| 日志项 | `4px` |
| 状态点 | 圆形 `BoxShape.circle` |

---

## 四、间距规范

### 外边距（Padding）

| 元素 | 间距 |
|------|------|
| 屏幕主容器 | `12px` |
| 卡片内边距 | `16px` |
| 紧凑卡片 | `12px` |
| 列表项 | `8px` |
| 按钮内边距 | `horizontal: 16px` |

### 组件间距

| 场景 | 间距 |
|------|------|
| 卡片之间 | `12px` |
| 同行元素 | `12px` 或 `16px` |
| 标签与内容 | `4px` - `12px` |

---

## 五、边框样式

### 标准卡片边框

```dart
BoxDecoration(
  color: surface.withOpacity(0.5),
  border: Border.all(
    color: primary.withOpacity(0.2),
    width: 1,
  ),
  borderRadius: BorderRadius.circular(12),
)
```

### 强调卡片边框

```dart
BoxDecoration(
  color: surface.withOpacity(0.5),
  border: Border.all(
    color: primary.withOpacity(0.3),
    width: 1,
  ),
  borderRadius: BorderRadius.circular(12),
)
```

### 分隔线

```dart
Border(
  bottom: BorderSide(
    color: primary.withOpacity(0.1),
  ),
)
```

---

## 六、发光效果

### 霓虹发光阴影

```dart
BoxShadow(
  color: color.withOpacity(0.2),
  blurRadius: 15,
  spreadRadius: 0,
)
```

### 进度条发光

```dart
BoxShadow(
  color: color,
  blurRadius: 8,
  spreadRadius: -2,
)
```

### 图标发光

```dart
BoxShadow(
  color: color,
  blurRadius: 4,
  spreadRadius: -1,
)
```

---

## 七、文字排版

### 字体族

- 主字体：Space Grotesk（Google Fonts）
- 等宽字体：monospace（日志时间）

### 字号层级

| 样式 | 字号 | 字重 | 用途 |
|------|------|------|------|
| `headingLarge` | 120px | Bold | 超大数字（速度） |
| `titleMedium` | 14px | Bold | 卡片标题 |
| `labelMedium` | 11px | Medium | 标签 |
| `labelSmall` | 10px | Bold | 小标签 |
| 超小标签 | 9px | Bold | 顶部标签 |

### 字间距

| 场景 | 字间距 |
|------|--------|
| 大标题 | `-2px` ~ `-3px`（紧凑） |
| 英文标签 | `1px` ~ `2px`（展开） |
| 版本信息 | `2px` |

### 文字样式示例

```dart
// 标签文字
TextStyle(
  color: primary.withOpacity(0.6),
  fontSize: 9,
  fontWeight: FontWeight.bold,
  letterSpacing: 2,
)

// 大数字
TextStyle(
  color: Colors.white,
  fontSize: 120,
  fontWeight: FontWeight.bold,
  letterSpacing: -2,
  height: 1,
)

// 次要信息
TextStyle(
  color: textSecondary,
  fontSize: 13,
)
```

---

## 八、组件设计模式

### 1. 卡片组件

```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: surface.withOpacity(0.5),
    border: Border.all(color: primary.withOpacity(0.2)),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 标签
      Text('LABEL', style: labelStyle),
      SizedBox(height: 12),
      // 内容
      ...
    ],
  ),
)
```

### 2. 进度条

```dart
Stack(
  children: [
    // 背景
    Container(
      height: 6,
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
    // 进度
    FractionallySizedBox(
      widthFactor: value / 100,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(3),
          boxShadow: [glowShadow],
        ),
      ),
    ),
  ],
)
```

### 3. 状态指示点

```dart
Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(
    color: statusColor,
    shape: BoxShape.circle,
  ),
)
```

### 4. 事件项

```dart
Container(
  padding: EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: eventColor.withOpacity(0.1),
    borderRadius: BorderRadius.circular(4),
    border: Border(
      left: BorderSide(color: eventColor, width: 2),
    ),
  ),
  child: Row(
    children: [
      Icon(icon, color: eventColor, size: 18),
      SizedBox(width: 10),
      Expanded(child: ...),
    ],
  ),
)
```

---

## 九、自定义绘制规范

### 圆形进度表盘

- 背景圆环：深色 `#1E293B`，strokeWidth: 6
- 进度圆环：渐变色 Primary → Accent Cyan
- 最大弧度：270°（0.75 * 2π）
- 起始角度：-90°（顶部）
- 刻度点：60个，均匀分布

```dart
// 渐变配置
SweepGradient(
  startAngle: -pi / 2,
  endAngle: -pi / 2 + sweepAngle,
  colors: [primary, accentCyan],
)
```

### 折线图

- 网格线：`primary.withOpacity(0.1)`
- 主线：实线，strokeWidth: 3
- 副线：虚线，dash: 4px, gap: 4px
- 面积填充：渐变 20% → 0% 透明度

---

## 十、图标使用

| 场景 | 图标 |
|------|------|
| 温度/冷却液 | `Icons.device_thermostat` |
| 进气温度 | `Icons.ac_unit` |
| 警告 | `Icons.warning` |
| 成功 | `Icons.check_circle` |
| 速度 | `Icons.speed` |
| 蓝牙连接 | `Icons.bluetooth_connected` |
| 电池 | `Icons.battery_full` |
| 信号 | `Icons.signal_cellular_alt` |
| 设置 | `Icons.settings_input_antenna` |
| 运动 | `Icons.sports_motorsports` |

---

## 十一、导航栏设计

### 顶部导航栏

- 高度：60px
- 背景：`backgroundDark.withOpacity(0.8)`
- 底部边框：`primary.withOpacity(0.2)`
- 水平内边距：24px

### 导航项

- 激活状态：Primary 色 + 下划线指示器
- 非激活状态：textSecondary 色
- 间距：24px

### 主按钮

```dart
Container(
  height: 40,
  padding: EdgeInsets.symmetric(horizontal: 16),
  decoration: BoxDecoration(
    color: primary,
    borderRadius: BorderRadius.circular(8),
    boxShadow: glowShadow(primary),
  ),
  child: Text(
    'BUTTON TEXT',
    style: TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    ),
  ),
)
```

---

## 十二、底部状态栏

- 高度：约 36px
- 背景：`surface.withOpacity(0.8)`
- 顶部边框：`primary.withOpacity(0.2)`
- 状态点：8px 圆形
- 文字：9px Bold，letterSpacing: 2

---

## 十三、设计原则总结

1. **深色优先** - 所有背景都是深色调
2. **发光点缀** - 关键元素添加霓虹发光效果
3. **半透明层次** - 使用透明度创造层次感
4. **标签全大写** - 英文标签统一大写 + 字母间距
5. **渐变强调** - 重要数据使用渐变色
6. **边框分隔** - 使用微弱边框区分区域
7. **状态色彩** - 绿/橙/红表示不同状态
8. **紧凑布局** - 信息密集但通过间距保持可读性

---

## 十四、复刻新页面检查清单

- [ ] 使用 `#0A1114` 作为主背景
- [ ] 卡片使用 `surfaceBorder()` 样式
- [ ] 标签文字全大写，letterSpacing: 2
- [ ] 重要数据使用渐变或发光效果
- [ ] 状态颜色正确映射（绿=正常，橙=警告，红=错误）
- [ ] 圆角统一使用 12px（容器）/ 8px（按钮）/ 4px（小元素）
- [ ] 间距使用 12px 或 16px 的倍数
- [ ] 添加合适的边框分隔
- [ ] 文字层级清晰（Primary 白色 → Secondary 灰色 → Muted 暗灰色）