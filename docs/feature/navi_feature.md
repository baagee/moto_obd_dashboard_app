# 高德导航功能集成计划

## 背景与目标

在现有的 Flutter OBD Dashboard 应用中新增一个导航页面，内嵌高德地图导航功能。需要：
1. 新增导航菜单项（NAVIGATION）
2. 创建导航页面（NaviScreen）
3. 集成高德地图 Flutter SDK

---

## 调研结论

### ⚠️ 重要说明

**高德官方 Flutter SDK 不包含导航功能！**

官方文档 (https://lbs.amap.com/api/flutter/summary) 明确只包含：
- **定位插件** - amap_flutter_location
- **地图插件** - amap_flutter_map（仅显示地图、POI搜索、路线规划）

导航功能需要使用**第三方插件**。

---

### 可行性：⚠️ 有风险

发现第三方插件 **xbr_gaode_navi_amap**，包含完整导航功能：
- 内置地图、定位、搜索、导航
- 使用方式：`XbrNavi.startNavi(points, strategy, emulator)`

**风险点**：
- 第三方非官方插件，维护状态不明（最新版本4.0.0，2年前发布）
- 包体积较大（包含所有功能）
- 可能存在兼容性问题

### 实现难度：中等偏高

主要工作量：
1. 使用第三方插件（非官方）
2. 配置高德开发者账号和 API Key
3. 添加 Gradle 依赖和 Android 配置
4. 申请定位权限
5. 编写导航页面 UI

---

## 实施方案

### 1. 添加依赖 (pubspec.yaml)

```yaml
dependencies:
  xbr_gaode_navi_amap: ^4.0.0  # 第三方导航插件（包含地图+定位+导航）
  permission_handler: ^11.0.0  # 权限管理
```

### 替代方案（仅地图+唤起App）

如果不需要内嵌导航，可以：
1. 使用官方 `amap_flutter_map` 显示地图
2. 点击目的地后调用系统意图唤起高德App

### 2. Android 配置

#### android/app/build.gradle
```gradle
dependencies {
    implementation('com.amap.api:3dmap:9.4.0')
    implementation('com.amap.api:location:5.2.0')
    implementation('com.amap.api:navi:3dmap:9.4.0')
}
```

#### android/app/src/main/AndroidManifest.xml
```xml
<!-- 权限 -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_LOCATION_EXTRA_COMMANDS"/>

<!-- API Key -->
<meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="YOUR_API_KEY"/>
```

### 3. 代码修改

#### 3.1 新增导航页面 `lib/screens/navi_screen.dart`

```dart
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_tools/amap_flutter_tools.dart';

class NaviScreen extends StatefulWidget {
  const NaviScreen({super.key});

  @override
  State<NaviScreen> createState() => _NaviScreenState();
}

class _NaviScreenState extends State<NaviScreen> {
  late AMapController _mapController;
  late AMapFlutterLocation _locationPlugin;

  @override
  void initState() {
    super.initState();
    // 初始化定位
    AMapFlutterLocation.setApiKey("iOS_KEY", "Android_KEY");
    _locationPlugin = AMapFlutterLocation();
    _locationPlugin.startLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AMapWidget(
        apiKey: AMapApiKey(iosKey: "iOS_KEY", androidKey: "Android_KEY"),
        onMapCreated: (controller) => _mapController = controller,
        myLocationStyle: MyLocationStyle(
          showLocation: true,
          myLocationType: MyLocationType.LOCATION_TYPE_MAP_FOLLOW,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNavi,
        child: const Icon(Icons.navigation),
      ),
    );
  }

  void _startNavi() {
    // 调用导航
    AmapNaviCourse.startNavi(
      lat: 39.904989,  // 目标纬度
      lon: 116.427428, // 目标经度
      naviType: AmapNaviType.drive,
    );
  }
}
```

#### 3.2 修改导航栏 `lib/widgets/top_navigation_bar.dart`

添加 NAVIGATION 菜单项：
```dart
static const List<String> navItems = ['DASHBOARD', 'LOGS', 'DEVICES', 'NAVIGATION'];
```

#### 3.3 修改主容器 `lib/screens/main_container.dart`

1. 导入导航页面
2. 添加到页面列表
3. 处理新增索引

---

## 关键文件

| 文件 | 操作 |
|-----|------|
| `pubspec.yaml` | 添加依赖 |
| `android/app/build.gradle` | 添加高德SDK依赖 |
| `android/app/src/main/AndroidManifest.xml` | 添加权限和API Key |
| `lib/widgets/top_navigation_bar.dart` | 添加导航菜单项 |
| `lib/screens/main_container.dart` | 注册新页面 |
| `lib/screens/navi_screen.dart` | **新增** - 导航页面 |

---

## 验证方法

1. 运行 `flutter pub get` 确保依赖下载成功
2. 在 Android 设备上运行应用
3. 点击 NAVIGATION 菜单切换到导航页面
4. 验证：
   - 地图是否正常显示
   - 定位是否正常工作
   - 点击导航按钮是否能唤起高德导航（或内嵌导航）

---

## API Key 申请流程

### 1. 注册高德开放平台账号

访问 [高德开放平台](https://lbs.amap.com/)，注册账号并完成开发者认证。

### 2. 创建应用并获取 Key

1. 登录后进入「控制台」→「应用管理」→「创建应用」
2. 添加「Key」：
   - 绑定的包名：`com.example.dashboard_test01`（或你的实际包名）
   - 安全码（SHA1）：需要获取项目的签名指纹

### 3. 获取 Android SHA1 签名

```bash
# 方法1：使用 keytool
keytool -list -v -keystore your_keystore.jks -alias your_alias

# 方法2：Android Studio 调试自动获取
# 运行一次应用后在 AS 右侧 Gradle 面板中查看
```

### 4. 启用导航服务

在 Key 配置页面，需要确保启用了：
- **地图服务**（3D地图）
- **定位服务**
- **导航服务**（如使用内嵌导航）

### 5. 配置 Key 到项目

将获取的 Key 填入 `AndroidManifest.xml`：
```xml
<meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="你的Android_Key"/>
```

---

## 注意事项

1. **API Key**：需要到高德开放平台申请 **Android Key**，需要绑定包名和SHA1签名
2. **iOS**：本次仅实现 Android，无需配置 iOS
3. **内嵌导航**：需要确保 Key 已启用导航服务权限
4. **隐私合规**：v6.4.0+ 版本需要调用 `updatePrivacyShow`、`updatePrivacyAgree` 接口
5. **测试限制**：未购买许可的 Key 仅供测试使用，有配额限制
