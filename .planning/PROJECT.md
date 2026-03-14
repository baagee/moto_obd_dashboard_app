# CYBER-CYCLE OBD Dashboard - 主题系统

## What This Is

赛博朋克风格摩托车 OBD 仪表盘应用，支持多主题切换：赛博蓝、红色、橙色、浅色模式。根据日出日落自动切换深色/浅色主题，也可手动选择。

## Core Value

为摩托车骑手提供清晰可读的实时 OBD 数据显示，支持多种环境光条件下的最佳可视性。

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] 实现多主题系统（赛博蓝、红色、橙色、浅色）
- [ ] 创建设置页面，支持手动主题切换
- [ ] 根据日出日落自动切换深色/浅色主题
- [ ] 主题设置持久化保存
- [ ] 所有页面和组件应用主题颜色

### Out of Scope

- 动态主题（根据实时光线传感器调整）
- 主题渐变动画过渡

## Context

**现有代码库：**
- Flutter 应用，使用 Provider 状态管理
- 当前主题：深色赛博朋克风格（`lib/theme/app_theme.dart`）
- 已有权限：蓝牙、定位（BLE 需要）

**技术实现提示：**
- 使用 `flutter_bloc` 或 Provider 管理主题状态
- 主题数据使用 `ThemeData` 封装
- 日出日落计算可使用 `sunrise_sunset_calc` 或 `solar_calculator` 包
- 使用 `shared_preferences` 持久化主题设置

## Constraints

- **定位权限**：自动切换需要获取用户位置计算日出日落
- **兼容性**：主题需覆盖所有现有页面和自定义组件
- **性能**：主题切换应流畅，不影响 OBD 数据采集

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 使用定位计算日出日落 | 用户已同意获取定位权限 | — Pending |
| 4 种主题：赛博蓝、红色、橙色、浅色 | 覆盖白天夜间多种使用场景 | — Pending |
| 设置页面 + 自动切换 | 提供灵活性和便利性 | — Pending |

---
*Last updated: 2026-03-14 after initialization*
