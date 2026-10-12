package com.example.obd_dashboard.debug

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Phase 0 探针通道。
 *
 * - [METHOD_CHANNEL]：接收 start / stop / queryState 一次性命令
 * - [EVENT_CHANNEL]：把每条高德广播的原始字段 Map 主动推给 Dart
 *
 * 仅在 debug 构建中由 [com.example.obd_dashboard.MainActivity] 注册，
 * 不影响 release，也不参与任何业务逻辑。
 */
class AmapProbeChannel(private val appContext: Context) : EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var receiver: AmapProbeReceiver? = null

    fun register(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startReceiver()
                    result.success(true)
                }
                "stop" -> {
                    stopReceiver()
                    result.success(true)
                }
                "queryState" -> {
                    queryAmapState()
                    result.success(true)
                }
                "selfTest" -> {
                    sendSelfTest()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    override fun onCancel(args: Any?) {
        eventSink = null
    }

    private fun startReceiver() {
        if (receiver != null) return
        receiver = AmapProbeReceiver { map ->
            // EventChannel.success 必须在主线程调用
            mainHandler.post { eventSink?.success(map) }
        }
        // Android 13+ 动态注册隐式广播必须显式声明导出属性
        ContextCompat.registerReceiver(
            appContext,
            receiver,
            IntentFilter(AmapProbeReceiver.ACTION_SEND),
            ContextCompat.RECEIVER_EXPORTED,
        )
    }

    private fun stopReceiver() {
        receiver?.let { r -> runCatching { appContext.unregisterReceiver(r) } }
        receiver = null
    }

    /** 主动向高德查询当前导航状态，触发它回一条广播（对应源码 KEY_TYPE=13030） */
    private fun queryAmapState() {
        appContext.sendBroadcast(
            Intent().apply {
                action = ACTION_RECV
                putExtra("KEY_TYPE", 13030)
                putExtra("SOURCE_APP", appContext.packageName)
                putExtra("PACKAGE", appContext.packageName)
            }
        )
    }

    /**
     * 自测：从本应用发一条伪造的高德广播（同 action）。
     *
     * 用于二分定位问题：
     * - 自测数据出现在列表 → 接收链路（注册/EventChannel/UI）完全正常，
     *   收不到真数据 = 高德侧没发广播
     * - 自测数据也不出现 → 是探针自身的问题
     */
    private fun sendSelfTest() {
        appContext.sendBroadcast(
            Intent().apply {
                action = AmapProbeReceiver.ACTION_SEND
                putExtra("KEY_TYPE", 10001)
                putExtra("ICON", 3)
                putExtra("NEXT_ROAD_NAME", "自测道路（本机回环）")
                putExtra("SEG_REMAIN_DIS_AUTO", "123")
                putExtra("_SELF_TEST", true)
            }
        )
    }

    companion object {
        const val EVENT_CHANNEL = "amap_probe/events"
        const val METHOD_CHANNEL = "amap_probe/method"
        const val ACTION_RECV = "AUTONAVI_STANDARD_BROADCAST_RECV"
    }
}
