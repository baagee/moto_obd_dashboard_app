# 用手机编程控制 GoPro —— 路书

> 整理日期：2026-10-10　来源：gopro.github.io/labs、gopro.github.io/OpenGoPro

---

## 一、先分清这是两个东西

| | **GoPro Labs** | **Open GoPro（OGP）** |
|---|---|---|
| 是什么 | 官方**实验固件** + 二维码控制 | 官方**API 规范**（MIT 免费） |
| 要刷固件吗 | 要（刷完不影响原功能，额外功能默认全关） | **不用**，市售标准固件就行 |
| 控制方式 | 二维码 / USB 命令行 / WiFi 下也能收 OGP 命令 | BLE + WiFi(HTTP) + USB(HTTP) |
| 适合谁 | 不想写 App，只想让相机按指令跑 | 要写 App / 脚本做集成 |
| 支持机型 | HERO5 Session 起，一直到 MISSION 1 PRO | HERO9 Black 起（固件 v01.70.00+），含 MAX2 / LIT HERO / MISSION 系列 |

**一句话：Labs 是"给相机加功能"，Open GoPro 是"给程序员开口子"。** 两个可以叠加用。

---

## 二、关键前提（不搞清这两条会白折腾）

1. **BLE 是入口，WiFi 是水管。** 相机 WiFi 默认是关的，必须先用 BLE 发指令打开并读出 SSID/密码。所以"只走 WiFi"这条路的真实前提是：你已经在相机上手动开过热点，或者刷了 Labs 用开机命令自动开 WiFi。
2. **相机忙的时候会拒绝命令。** 录像中（Encoding Active）或加载预设中（System Busy）时，改设置之类的命令会被拒。另外必须**周期性发 keep_alive**，否则连接会掉。

---

## 三、三条路线，按你的野心选

### 路线 A：Labs 二维码 —— 最省事，不算编程但最快出结果

**原理**：二维码内容就是一串命令文本，相机拿摄像头读它，然后执行。

例：`mVr4p60x-.5cFw55$BITR=150$LEVL=6`
拆开是：`mV`=视频模式，`r4`=4K，`p60`=60fps，`x-.5`=曝光补偿-0.5，`cF`=平面色彩，`w55`=白平衡5500K，`$BITR=150`=码率150Mb/s，`$LEVL=6`=水平仪。

**怎么做**：
1. 到 gopro.github.io/labs 下载对应机型的 Labs 固件，按官方手动升级流程刷进去
2. 相机里打开「二维码读取」（QR Control）
3. 用任意二维码生成器（网页、Python `qrcode` 库、手机 App）把命令串做成二维码
4. 相机对着屏幕扫一下，执行

**进阶**：官方有可视化脚本工具（Visual Script Tool，支持 M1P/M1/MAX2/H13/H12/H11/H11Mini/H10/Max），不用背命令语法，拖出来生成二维码。

**隐藏桥梁**：OGP 有个 HTTP 端点 `GET /gopro/qrcode?data=<命令串>`，可以**不扫码**直接把 Labs 命令通过 WiFi 发给相机。这条把 A 和 B 打通了。

---

### 路线 B：WiFi + HTTP —— 推荐从这里起步

**为什么推荐**：任何能发 HTTP 请求的东西都能控相机。手机上甚至不用写 App。

**连接方式**（两种模式二选一）：
- **AP 模式**：手机连相机自己开的热点。SSID 形如 `GP12345678`，**密码是相机序列号**（可在相机「配对模式」右上角信息按钮看，或 BLE 读出来）
- **STA / COHN 模式**：让相机连你家路由器，手机和相机同一个网段

**地址**（官方文档明确写的）：
- WiFi 连接：`http://10.5.5.9:8080`
- USB 连接：`http://172.2X.1YZ.51:8080`（XYZ = 序列号后三位；例：序列号尾号 789 → `172.27.189.51`）
- USB 也可以走 mDNS 发现，相机注册 `_gopro-web` 服务

**常用端点**（共 111 个，挑最常用的）：

| 干什么 | 请求 |
|---|---|
| 开始录像/拍照 | `GET /gopro/camera/shutter/start` |
| 停止录像 | `GET /gopro/camera/shutter/stop` |
| 查相机状态（是否在录、电量） | `GET /gopro/camera/state` |
| 保活（必须周期发） | `GET /gopro/camera/keep_alive` |
| 读某个设置 | `GET /gopro/camera/setting?setting=2`（2=分辨率）|
| 读预设列表 | `GET /gopro/camera/presets/get` |
| 切换预设 | `GET /gopro/camera/presets/load?id=<presetId>` |
| 媒体列表 | `GET /gopro/media/list` |
| 下载文件 | `GET /videos/DCIM/{目录}/{文件名}` |
| 让相机说话（Labs 命令） | `GET /gopro/qrcode?data=<命令串>` |
| 开机 / 关机（USB/WiFi 通用先要 BLE） | 关机：`GET /gp/gpControl/command/system/sleep` |

**手机上怎么发请求（从易到难）**：
1. **iOS 快捷指令**：用「获取 URL 内容」动作 + 个人自动化。零代码，五分钟能做一个"一键开录"按钮。注意语法是 `http://10.5.5.9:8080/gopro/camera/shutter/start`
2. **Android**：Tasker，或免费的 HTTP Request Shortcuts
3. **手机浏览器 / PWA**：写个本地 HTML，用 `fetch()` 发请求。**坑**：连相机热点时手机没有外网，页面必须离线可用（或存在本地文件里打开）
4. **写 App**：见路线 C

---

### 路线 C：BLE —— 真正意义上的"编程遥控"

**要玩真的（唤醒睡眠中的相机、自动开 WiFi、脱离相机手动操作）只能走这条。**

**官方现成的东西（照抄就行）**：

| 平台 | 资源 | 成熟度 |
|---|---|---|
| **Android** | 官方 Kotlin Multiplatform SDK（KMP）| ✅ 完整支持。**但还没上 Maven**，目前只能 clone 仓库跑 demo app |
| **iOS** | 官方 Swift demo `demos/swift/EnableWiFiDemo` | ⚠️ 只是个示例，用 CoreBluetooth 手写，没有打包成 SDK |
| **iOS/Android 跨平台** | 官方 Ionic + Capacitor demo `demos/ionic/file_transfer` | ✅ **手机上抄作业的最佳对象**。已实现完整链路：BLE 连相机 → 拍照/关机/拿 WiFi 凭证 → 连 WiFi → 下载文件。用 `capacitor-community/bluetooth-le` + `community-capacitor-wifi` |
| **Flutter** | 无官方 | 用 `flutter_blue_plus` 自己实现协议 |
| **Python** | `pip install open-gopro` | ✅ 完整 SDK（功能最全）。但手机上跑 Python 得靠 Termux，BLE 支持一般 |

**Kotlin SDK 用法（5 行看懂）**：
```kotlin
val sdk = OgpSdk(Dispatchers.IO, appContext)
val device = sdk.discover(NetworkType.BLE).first()
val goproId = sdk.connect(device).getOrThrow()
val gopro = sdk.getGoPro(goproId).getOrThrow()
gopro.commands.setShutter(true)   // 按下快门
```

**Ionic demo 跑起来**：
```bash
git clone https://github.com/gopro/OpenGoPro.git
cd OpenGoPro/demos/ionic/file_transfer
npm install && ionic build && ionic cap sync
ionic cap open ios       # 或 android，插真机点运行
```

**自己从零实现 BLE 的话，这些参数是必须的**：

| 项目 | 值 |
|---|---|
| 扫描过滤 Service UUID | `0xFEA6` |
| 厂商 ID（Manufacturer Data）| `0xF202` |
| GoPro 128-bit UUID 前缀 | `GP-XXXX` = `b5f9XXXX-aa8d-11e3-9046-0002a5d5c51b` |
| 发命令 / 收响应 | GP-0072 写 / GP-0073 通知 |
| 读设置 / 收响应 | GP-0074 写 / GP-0075 通知 |
| 发查询 / 收响应 | GP-0076 写 / GP-0077 通知 |
| 读 WiFi SSID / 密码 | GP-0002 读 / GP-0003 读；GP-0004 写（开热点）|

**分片规则**：BLE 单包 20 字节，长消息要拆包。第一包用 start header，后续用 continuation header。**发消息时一律用 Extended 13-bit 包头**，可以少踩坑。

**配对前提**：相机必须先进入配对模式（相机 UI 里操作），之后相机会持续广播，即使休眠了连上去也能唤醒。

---

## 四、我会怎么选

- **只想让相机按剧本跑**（延时、多机同步、开机自动设参数）→ 路线 A，刷 Labs 做二维码
- **想用手机按一下就录、录完自动传**（不想写 App）→ 路线 B + iOS 快捷指令
- **想做一个自己的相机 App** → 先 clone 官方 Ionic demo 跑通，看清 BLE 全流程，再决定用什么技术栈重写
- **Android 且想省事** → 直接用官方的 Kotlin KMP SDK（注意它还没发布到 Maven，得连仓库一起用）

---

## 五、附：官方资源索引

| 资源 | 地址 |
|---|---|
| Labs 主页（固件下载） | https://gopro.github.io/labs/ |
| Labs 命令语言完整文档 | https://gopro.github.io/labs/control/tech/ |
| Labs 功能总览与机型兼容表 | https://gopro.github.io/labs/control/ |
| Labs 可视化脚本工具 | https://gopro.github.io/labs/control/extensions |
| Open GoPro 首页（兼容机型表） | https://gopro.github.io/OpenGoPro/docs/ |
| BLE API 规范 | https://gopro.github.io/OpenGoPro/docs/ble |
| BLE 连接与 GATT 特征 | https://gopro.github.io/OpenGoPro/docs/ble/protocol/ble_setup |
| BLE 数据协议（分片/解析） | https://gopro.github.io/OpenGoPro/docs/ble/protocol/data_protocol |
| HTTP API 规范（可交互） | https://gopro.github.io/OpenGoPro/http/ |
| HTTP OpenAPI 原始文件 | https://gopro.github.io/OpenGoPro/http/openapi.json |
| Python SDK 文档 | https://gopro.github.io/OpenGoPro/python_sdk/ |
| Kotlin SDK 文档 | https://gopro.github.io/OpenGoPro/kotlin_sdk/ |
| FAQ | https://gopro.github.io/OpenGoPro/docs/faq |
| 官方 demo 代码 | https://github.com/gopro/OpenGoPro/tree/main/demos |
| Labs 讨论区 | https://github.com/gopro/labs/discussions |

---

## 六、容易踩的坑

1. **WiFi 一次只能连一个设备**，BLE 最多同时 4 个连接
2. **不发 keep_alive 会掉线**，长任务必须定时发
3. **录像中改设置会被拒**，先停录再改
4. **手机连上相机热点后就没外网了**，网页版控制台必须离线可用
5. **Kotlin SDK 还没上 Maven**，别指望一行 gradle 依赖引入，得把仓库一起 vendor 进去
6. **iOS 连相机 WiFi 要用 NetworkExtension**（`NEHotspotConfigurationManager`），不是普通的 WiFi 连接 API
7. **别指望多机精确同步到毫秒**：通过网络发同一命令，时间差 20~500ms 不等。要精确对齐得靠 GPS 时间同步（需 Labs 固件）+ 后期按 GPMF 元数据处理
