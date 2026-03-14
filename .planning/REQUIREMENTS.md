# Requirements: CYBER-CYCLE OBD Dashboard - Theme System

**Defined:** 2026-03-14
**Core Value:** 为摩托车骑手提供清晰可读的实时 OBD 数据显示，支持多种环境光条件下的最佳可视性。

## v1 Requirements

### Theme Infrastructure

- [ ] **THME-01**: 创建 ThemeColors 数据类，封装每种主题的所有颜色 token
- [ ] **THME-02**: 定义 4 种主题：赛博蓝、红色、橙色、浅色
- [ ] **THME-03**: 实现 ThemeProvider (extends ChangeNotifier)，管理当前主题状态
- [ ] **THME-04**: 使用 shared_preferences 持久化主题偏好设置

### Theme Definitions

- [ ] **THME-05**: 赛博蓝主题 - 深色背景 (#0A1114) + 蓝色强调 (#0DA6F2)
- [ ] **THME-06**: 红色主题 - 深色背景 + 红色强调 (#FF4D4D)
- [ ] **THME-07**: 橙色主题 - 深色背景 + 橙色强调 (#FFAB40)
- [ ] **THME-08**: 浅色主题 - 白色背景 (#FFFFFF) + 黑色文字 (#000000) + 蓝色强调

### Manual Theme Switch

- [ ] **THME-09**: 设置页面提供主题选择器 UI
- [ ] **THME-10**: 用户可选 4 种主题之一
- [ ] **THME-11**: 主题切换后立即生效，无需重启应用

### Auto Theme Switch

- [ ] **THME-12**: 根据日出日落自动切换深色/浅色主题
- [ ] **THME-13**: 使用定位计算当地日出日落时间
- [ ] **THME-14**: 日出后自动切换到浅色主题，日落后切换到深色主题

### Widget Migration

- [ ] **THME-15**: 所有 widgets 使用动态颜色（非硬编码 Color）
- [ ] **THME-16**: 仪表盘页面 (DashboardScreen) 应用主题颜色
- [ ] **THME-17**: 日志页面 (LogsScreen) 应用主题颜色
- [ ] **THME-18**: 蓝牙扫描页面 (BluetoothScanScreen) 应用主题颜色
- [ ] **THME-19**: 设置页面 (SettingsScreen) 应用主题颜色
- [ ] **THME-20**: 通用组件 (速度表、转速表、组合仪表) 应用主题颜色

### System Integration

- [ ] **THME-21**: 主题切换时同步状态栏亮度
- [ ] **THME-22**: 浅色主题使用深色状态栏，深色主题使用浅色状态栏

## v2 Requirements

### Advanced Features

- **THME-23**: 用户可设置偏好的深色主题（红色/橙色/赛博蓝三选一）
- **THME-24**: 日出日落时间缓存，减少定位请求频率

## Out of Scope

| Feature | Reason |
|---------|--------|
| 动态主题（根据实时光线传感器） | 需求明确不需要 |
| 主题渐变动画过渡 | PROJECT.md 明确排除 |
| 用户自定义主题 | MVP 范围之外 |
| 多设备主题同步 | 超出 MVP 范围 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| THME-01 - THME-04 | Phase 1 | Pending |
| THME-05 - THME-08 | Phase 1 | Pending |
| THME-09 - THME-11 | Phase 2 | Pending |
| THME-12 - THME-14 | Phase 3 | Pending |
| THME-15 - THME-22 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-14*
*Last updated: 2026-03-14 after initial definition*
