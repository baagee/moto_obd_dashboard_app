# 设置功能可配置参数全量梳理

> 扫描范围：`lib/` 目录下所有 Dart 源文件（constants、providers、services、utils、widgets、models）
> 整理时间：2026-03-30

---

## 1. 蓝牙连接 & OBD 轮询相关

> 来源：`lib/constants/bluetooth_constants.dart`、`lib/providers/bluetooth_provider.dart`、`lib/services/obd_service.dart`

### 1.1 蓝牙扫描

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `scanTimeout` | 3 秒 | 蓝牙设备扫描超时时长 | Slider（1-10s） |
| `scanWaitTimeout` | 3100 ms | 自动重连时等待扫描找到设备的时间（需略大于 scanTimeout） | 高级设置，联动计算 |
| `minRssi` | -90 dBm | 扫描过滤弱信号阈值（越小越宽松，越大越严格） | Slider（-100 ~ -60） |

### 1.2 蓝牙连接

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `connectionTimeout` | 2 秒 | 连接超时时间（BLE connect 超时） | Slider（1-10s） |
| `connectWaitCallbackTimeout` | 2100 ms | 等待 BLE 握手回调的最大时间（需略大于 connectionTimeout） | 高级设置，联动计算 |
| `elm327InitWait` | 1000 ms | ATZ 复位后初始化等待时间 | 高级设置（500-3000ms） |
| `obdCommandInterval` | 200 ms | ELM327 初始化命令发送间隔 | 高级设置（100-500ms） |

### 1.3 自动重连

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `maxReconnectAttempts` | 2 次 | 自动重连最大次数 | Dropdown（0/1/2/3/5） |
| `reconnectRetryInterval` | 500 ms | 重连失败后的重试等待时间 | 高级设置 |
| 自动重连开关 | 硬编码开启 | 是否在断开后自动重连 | Toggle |

### 1.4 OBD 数据轮询

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `pollingBaseIntervalMs` | 50 ms | 轮询定时器基础间隔（≈20Hz 时钟基） | 高级设置 |
| `highSpeedPollingIntervalMs` | 50 ms | 车速/转速等高速 PID 间隔（≈14Hz） | 高级设置 |
| `mediumSpeedPollingIntervalMs` | 200 ms | 节气门/进气等中速 PID 间隔（≈4Hz） | 高级设置 |
| `lowSpeedPollingIntervalMs` | 500 ms | 水温/负载/电压等低速 PID 间隔（2Hz） | 高级设置 |

---

## 2. 车辆参数（档位计算）

> 来源：`lib/utils/gear_util.dart`（`GSX8SCalculator`）

这是**强车型依赖**的参数组，换车时必须全部重设。

### 2.1 传动系统参数

| 参数名 | 当前值（GSX-8S） | 说明 | 建议设置类型 |
|--------|----------------|------|-------------|
| `primaryRatio` | 1.675 | 一级传动比（曲轴→离合器） | 数字输入框 |
| `finalRatio` | 2.764 | 终传动比（链轮齿数比） | 数字输入框 |
| `tireCircumference` | 1.97857 m | 后轮周长（影响 km/h 与 RPM 对应） | 数字输入框（或轮胎规格计算器） |
| `internalGearRatios` | [3.071, 2.200, 1.700, 1.416, 1.230, 1.107] | 六档各档内齿轮比 | 6 个数字输入框 |

### 2.2 档位识别阈值

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `_gearThresholds` | [0.18, 0.15, 0.12, 0.10, 0.08, 0.12] | 各档传动比误差允许阈值（越大越宽松） | 高级设置，数组输入 |
| `_creepThreshold` | 0.25 | 半离合/蠕动专用宽松阈值 | 高级设置 |
| `_neutralSpeedThreshold` | 3 km/h | 空档判定低速阈值 | 数字输入 |
| `_neutralRpmThreshold` | 1200 rpm | 空档判定低转速阈值 | 数字输入 |
| `_minValidSpeed` | 5 km/h | 最低有效速度 | 数字输入 |
| `_minValidRpm` | 1300 rpm | 最低有效转速 | 数字输入 |

### 2.3 半离合检测参数

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `_creepMinSpeed` | 3 km/h | 半离合检测最低速 | 高级设置 |
| `_creepMaxSpeed` | 20 km/h | 半离合检测最高速 | 高级设置 |
| `_creepMaxThrottle` | 35 % | 半离合检测最大油门开度 | 高级设置 |

### 2.4 车速校正系数

| 参数名 | 当前值 | 说明 | 来源 |
|--------|--------|------|------|
| 车速倍率 | 1.08（`speed * 1.08`） | OBD 原始车速乘以修正系数（补偿轮胎磨损/胎压） | `lib/services/obd_service.dart` 第 124 行 |

> 建议可设置范围：0.90 ~ 1.20

---

## 3. 第三方接口 API Key

> 来源：`lib/services/geocoding_service.dart`

### 3.1 高德地图 Web 服务 API

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `_amapKey` | `'99d4e91045213ccda8ebee56a8061eb2'`（硬编码） | 高德逆地理编码 HTTP API Key | 文本输入框（密码样式） |
| HTTP 请求超时 | 5 秒 | 逆地理编码请求超时时间 | 高级设置 |
| AOI 距离过滤 | 500 m | aoi 结果距离过滤阈值 | 高级设置 |
| POI 距离过滤 | 300 m | poi 结果距离过滤阈值 | 高级设置 |

> ⚠️ **安全问题**：`_amapKey` 当前直接硬编码在源码中，提交到 GitHub 后 Key 会裸露被扫描滥用。强烈建议移入 `SharedPreferences`，在设置页以密码样式输入，运行时动态读取。

---

## 4. 骑行事件触发阈值 & 冷却时间

> 来源：`lib/providers/riding_stats_provider.dart`、`lib/models/riding_event.dart`

### 4.1 全局事件冷却时间

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `eventCooldown`（通用） | 30 秒 | 默认事件冷却时间（防重复触发） | Slider（5-300s） |
| `extremeLeanCooldown` | 60 秒 | 极限压弯专用冷却 | Slider |
| `longRidingCooldown` | 1200 秒（20 分钟） | 长途骑行提醒专用冷却 | Slider（5-60 分钟） |
| `efficientCruisingCooldown` | 300 秒（5 分钟） | 高效巡航专用冷却 | Slider |
| `coldEnvironmentCooldown` | 120 秒（2 分钟） | 低温环境风险专用冷却 | Slider |

### 4.2 各事件触发阈值

| 事件 | 参数 | 当前阈值 | 说明 | 建议设置类型 |
|------|------|----------|------|-------------|
| 性能爆发 `performanceBurst` | RPM 阈值 | 6300 rpm | `avgRpm > 6300` 时触发 | 数字输入（4000-9000） |
| 引擎过热 `engineOverheating` | 水温阈值 | 110 °C | `avgTemp > 110` 时触发 | 数字输入（90-130） |
| 电压异常 `voltageAnomaly` | 低压下限 | 11.5 V | `avgVoltage < 11.5` 时触发 | 数字输入 |
| 电压异常 `voltageAnomaly` | 高压上限 | 15.3 V | `avgVoltage > 15.3` 时触发 | 数字输入 |
| 高负荷 `highEngineLoad` | 负荷阈值 | 70 % | `avgLoad > 70` 时触发 | Slider（50-90%） |
| 长途骑行 `longRiding` | 骑行时长 | 1 小时 | `duration > 1h` 时触发 | Dropdown（0.5/1/1.5/2/3h） |
| 高效巡航 `efficientCruising` | 速度下限 | 70 km/h | 速度范围下限 | 数字输入 |
| 高效巡航 `efficientCruising` | 速度上限 | 100 km/h | 速度范围上限 | 数字输入 |
| 高效巡航 `efficientCruising` | 负荷上限 | 30 % | 负荷需低于此值 | 数字输入 |
| 高效巡航 `efficientCruising` | 油门稳定性（σ） | 10 % | 油门标准差需低于此值 | 高级设置 |
| 引擎预热 `engineWarmup` | 水温上限 | 70 °C | 水温未达到此值视为预热 | 数字输入 |
| 引擎预热 `engineWarmup` | RPM 阈值 | 6000 rpm | 预热期超过此转速触发 | 数字输入 |
| 低温风险 `coldEnvironmentRisk` | 温度阈值 | 5 °C | 进气温度低于此值 | 数字输入（-10~15） |
| 低温风险 `coldEnvironmentRisk` | 速度阈值 | 40 km/h | 速度高于此值才触发 | 数字输入 |
| 极限压弯 `extremeLean` | 速度阈值 | 60 km/h | 速度需高于此值 | 数字输入（40-80） |
| 极限压弯 `extremeLean` | 倾角阈值 | 20 ° | 倾角需大于此值 | Slider（10-45°） |

### 4.3 各事件独立开关

每个事件应有独立开关，允许用户关闭不需要的语音提醒（Toggle）：

- `performanceBurst` 性能爆发
- `engineOverheating` 引擎过热
- `voltageAnomaly` 电压异常
- `highEngineLoad` 高负荷
- `longRiding` 长途骑行
- `efficientCruising` 高效巡航
- `engineWarmup` 引擎预热
- `coldEnvironmentRisk` 低温风险
- `extremeLean` 极限压弯

---

## 5. 传感器 & GPS 相关

> 来源：`lib/services/sensor_service.dart`、`lib/providers/riding_stats_provider.dart`

### 5.1 倾角传感器（SensorService）

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `sampleIntervalMs` | 15 ms（≈67Hz） | 加速度计/陀螺仪采样间隔 | 高级设置 |
| `alpha`（互补滤波系数） | 0.98 | 陀螺仪权重（0.98=高权重陀螺仪，低权重加速计） | Slider（0.90-0.99） |
| `movingAverageWindow` | 5 帧 | 移动平均窗口大小（越大越平滑，响应越慢） | Slider（3-15） |
| `deadzoneThreshold` | 1.0 ° | 死区滤波阈值（小于此角度视为水平不更新） | 数字输入（0.5-5°） |
| 最大输出角度 | 60 ° | `clamp(0, 60)` 限制最大倾角显示 | 数字输入 |

### 5.2 GPS 轨迹过滤（RidingStatsProvider）

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `_maxReasonableSpeedMs` | 69.44 m/s（250 km/h） | GPS 漂移过滤极速上限 | 高级设置 |
| `_maxGpsGapSeconds` | 30 秒 | GPS 失联超过此时长视为异常跳跃 | 高级设置 |
| `_minMoveDistance` | 3.0 m | 小于此距离视为静止噪声，不累加里程 | 数字输入（1-10m） |
| GPS 时间过滤 | 500 ms | 相邻 GPS 更新最小时间间隔 | 高级设置 |

### 5.3 骑行数据采样

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `sampleInterval` | 500 ms（2Hz） | 事件检测采样间隔 | 高级设置 |
| `windowDuration` | 5 秒 | 滑动窗口大小（事件检测用均值的时间范围） | 高级设置（3-10s） |
| `_waypointInterval` | 1 秒 | 轨迹点采集定时器间隔 | 高级设置 |
| `_waypointBatchSize` | 15 个 | 轨迹点批量写库阈值 | 高级设置 |
| `_snapshotInterval` | 30 秒 | 骑行统计快照持久化间隔 | 高级设置 |
| 倾角统计最低车速 | 3 km/h | 车速低于此值时不统计倾角（过滤静止噪声） | 数字输入 |

---

## 6. UI 显示相关

> 来源：`lib/widgets/combined_gauge_card.dart`

### 6.1 仪表盘量程

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| `maxRpm` | 12000 rpm | 转速表最大量程 | Dropdown（8000/10000/12000/14000） |
| `warnRpm` | 7000 rpm | 转速警告（黄色区）起始值 | 数字输入 |
| `dangerRpm` | 9000 rpm | 转速危险（红色区）起始值 | 数字输入 |
| `maxSpeed` | 240 km/h | 车速表最大量程 | Dropdown（160/200/240/300） |
| `warnSpeed` | 120 km/h | 车速警告起始值 | 数字输入 |
| `dangerSpeed` | 180 km/h | 车速危险起始值 | 数字输入 |
| `flashThreshold` | 100 km/h | 车速数字闪烁阈值 | 数字输入 |
| `maxCoolantTemp` | 120 °C | 水温进度条最大值 | 数字输入 |
| `maxIntakeTemp` | 80 °C | 进气温度进度条最大值 | 数字输入 |
| `coolantWarnTemp` | 100 °C | 水温警告阈值 | 数字输入 |
| `intakeWarnTemp` | 50 °C | 进气温度警告阈值 | 数字输入 |

---

## 7. 骑行记录过滤

> 来源：`lib/providers/riding_stats_provider.dart`（`_saveRidingRecord`）

| 参数名 | 当前值 | 说明 | 建议设置类型 |
|--------|--------|------|-------------|
| 最小有效距离 | 20 m | 低于此距离的骑行记录自动丢弃 | 数字输入（0-100m） |
| 事件历史上限 | 100 条 | `_eventHistory.length > 100` 硬编码上限 | Dropdown（50/100/200/不限） |

---

## 8. 语音提醒配置

> 来源：`lib/models/event_voice_config.dart`、`assets/audio/`、`assets/audio2/`

项目中已有 `audio/` 和 `audio2/` 两套音频包（不同音色），其中 `audio2/` 额外包含 `extreme_lean.mp3`（`audio/` 目录目前无此文件）。

可设置项：
- **全局语音提醒开关**（Toggle）
- **语音包选择**：audio（当前）vs audio2（第二套音色）
- **每个事件的独立启用/禁用**（见第 4.3 节）
- **语音焦点策略**：Android 当前为 `gainTransient`（临时占用焦点），可选 `gainTransientMayDuck`（降低背景音乐音量叠加播放）

---

## 9. 其他你没想到的点

### 9.1 单位制

| 可配置项 | 当前状态 | 建议 |
|---------|---------|------|
| 速度单位 km/h vs mph | 硬编码 km/h | Toggle（公制/英制） |
| 温度单位 °C vs °F | 硬编码 °C | Toggle |

### 9.2 OBD 车速修正系数

`speed = (raw_speed * 1.08).toInt()` 硬编码在 `lib/services/obd_service.dart` 第 124 行，不同轮胎规格或轮胎磨损时需要校正，建议可在设置中调整（推荐范围 0.90~1.20）。

### 9.3 扫描设备名称优先级关键词

`_getDevicePriority` 中的关键词列表（`OBD/ELM/VAG/SCAN/CAR` 等）决定设备排序优先级，进阶用户可能需要手动绑定常用设备。
→ 建议增加「常用设备白名单/收藏」设置。

### 9.4 高德 API 搜索参数

- `radius=100`：POI 搜索半径（硬编码 100m，较小）
- `extensions=all`：返回详细信息（改成 `base` 会更快但字段少）

---

## 10. 实现优先级建议

| 优先级 | 设置分组 | 核心原因 |
|--------|---------|---------|
| 🔴 P0 | **高德 API Key** | 安全风险，Key 硬编码暴露在 GitHub |
| 🔴 P0 | **车辆传动比参数** | 换车必须修改，否则档位全错 |
| 🟠 P1 | **骑行事件阈值 & 冷却时间** | 用户需求最强，个性化差异大 |
| 🟠 P1 | **各事件语音开关 & 语音包选择** | 高频需求，两套 audio 已就位 |
| 🟡 P2 | **蓝牙扫描/重连参数** | 连接问题排查时需要 |
| 🟡 P2 | **仪表盘量程（转速/车速红线）** | 不同车型红线不同 |
| 🟢 P3 | **车速修正系数** | 轮胎磨损后校正 |
| 🟢 P3 | **单位制（km/mph，°C/°F）** | 出口市场需求 |
| 🟢 P3 | **GPS 过滤 & 采样间隔** | 高级用户调优 |
| 🟢 P3 | **倾角滤波参数** | 信号质量调优 |
