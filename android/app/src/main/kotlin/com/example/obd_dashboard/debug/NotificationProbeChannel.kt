package com.example.obd_dashboard.debug

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Plan B 探针通道。
 *
 * - [METHOD_CHANNEL]：权限检查 / 跳转设置 / 清空 / 取快照与统计 / 切换「显示全部应用」
 * - [EVENT_CHANNEL]：通知事件流（由 [NotificationProbeService] 经 [NotificationProbeBus] 推送）
 *
 * 仅在 debug 构建由 MainActivity 注册。
 */
class NotificationProbeChannel(private val appContext: Context) : EventChannel.StreamHandler {

    override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
        NotificationProbeBus.sink = sink
    }

    override fun onCancel(args: Any?) {
        NotificationProbeBus.sink = null
    }

    fun register(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> result.success(isPermissionGranted())
                "openSettings" -> {
                    openNotificationSettings()
                    result.success(true)
                }
                "clear" -> {
                    NotificationProbeBus.clear()
                    result.success(true)
                }
                "getSnapshot" -> result.success(NotificationProbeBus.snapshot())
                "getStats" -> result.success(NotificationProbeBus.stats())
                "setShowAll" -> {
                    NotificationProbeBus.showAllPackages = call.arguments as? Boolean ?: false
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 是否已获得「通知使用权」 */
    private fun isPermissionGranted(): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(appContext)
            .contains(appContext.packageName)

    /** 跳转系统「通知使用权」设置页（部分 OEM 路径不同，做兜底） */
    private fun openNotificationSettings() {
        val intents = listOf(
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )
        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                appContext.startActivity(intent)
                return
            } catch (_: ActivityNotFoundException) {
                // 尝试下一个
            }
        }
    }

    companion object {
        const val EVENT_CHANNEL = "notification_probe/events"
        const val METHOD_CHANNEL = "notification_probe/method"
    }
}
