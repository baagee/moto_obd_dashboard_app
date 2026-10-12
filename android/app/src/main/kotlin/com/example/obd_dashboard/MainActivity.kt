package com.example.obd_dashboard

import android.os.Bundle
import android.view.WindowManager
import com.example.obd_dashboard.debug.AmapProbeChannel
import com.example.obd_dashboard.debug.NotificationProbeChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 保持屏幕常亮（摩托车骑行时长时间使用）
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 调试探针，仅 debug 构建注册，不影响 release
        if (BuildConfig.DEBUG) {
            // Phase 0：高德导航广播抓包
            AmapProbeChannel(applicationContext).register(flutterEngine)
            // Plan B：高德导航通知抓包
            NotificationProbeChannel(applicationContext).register(flutterEngine)
        }
    }
}
