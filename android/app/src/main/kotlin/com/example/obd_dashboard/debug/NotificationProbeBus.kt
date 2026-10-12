package com.example.obd_dashboard.debug

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.ArrayDeque

/**
 * Plan B 探针的事件总线。
 *
 * [NotificationProbeService] 与 Flutter 通道同进程，通过该单例桥接：
 * - 缓存最近的通知（App 切到后台再返回时可回看）
 * - 按包名统计通知条数（用于判断监听是否生效、高德是否在发通知）
 */
object NotificationProbeBus {

    /** 高德相关包名（手机版 / 车机版） */
    val AMAP_PACKAGES = setOf(
        "com.autonavi.minimap", // 高德地图 手机版
        "com.autonavi.amapauto", // 高德地图 车机版
        "com.autonavi.amap",
    )

    private const val MAX_BUFFER = 300
    private const val LOCAL_PKG = "_local"

    private val lock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Flutter 侧事件 sink（未注册时为 null） */
    @Volatile
    var sink: EventChannel.EventSink? = null

    /** 是否记录所有应用的通知（默认只记录高德，避免刷屏） */
    @Volatile
    var showAllPackages: Boolean = false

    private val buffer = ArrayDeque<Map<String, Any?>>()
    private val packageCounts = LinkedHashMap<String, Int>()

    fun isAmap(pkg: String): Boolean = pkg in AMAP_PACKAGES

    /** 记录一条通知；非高德且未开启「显示全部」时直接丢弃 */
    fun emit(map: Map<String, Any?>) {
        val pkg = map["pkg"] as? String ?: ""
        if (!showAllPackages && !isAmap(pkg)) return
        push(map)
    }

    /** 记录一条本地状态消息（不受包名过滤，用于显示监听连接状态等） */
    fun emitLocal(message: String) {
        push(
            linkedMapOf(
                "_ts" to System.currentTimeMillis(),
                "_kind" to "local",
                "pkg" to LOCAL_PKG,
                "EXTRA_TITLE" to message,
            )
        )
    }

    private fun push(map: Map<String, Any?>) {
        synchronized(lock) {
            buffer.addLast(map)
            while (buffer.size > MAX_BUFFER) buffer.removeFirst()
            val pkg = map["pkg"] as? String
            if (!pkg.isNullOrEmpty() && pkg != LOCAL_PKG) {
                packageCounts[pkg] = (packageCounts[pkg] ?: 0) + 1
            }
        }
        // EventChannel 必须在主线程回调
        mainHandler.post { sink?.success(map) }
    }

    /** 当前缓存的通知快照（按时间正序） */
    fun snapshot(): List<Map<String, Any?>> = synchronized(lock) { buffer.toList() }

    /** 各包名通知计数 */
    fun stats(): Map<String, Int> = synchronized(lock) { LinkedHashMap(packageCounts) }

    fun clear() {
        synchronized(lock) {
            buffer.clear()
            packageCounts.clear()
        }
    }
}
