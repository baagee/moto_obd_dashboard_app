package com.example.obd_dashboard.debug

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Plan B 探针：通知监听服务。
 *
 * 由系统在用户授予「通知使用权」后自动绑定，无需手动启动。
 * 收到通知后原样丢给 [NotificationProbeBus]，由 Flutter 侧展示。
 *
 * 仅 debug 构建在 AndroidManifest 中声明（见 android/app/src/debug/AndroidManifest.xml）。
 */
class NotificationProbeService : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        NotificationProbeBus.emitLocal("通知监听已连接（权限生效）")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        NotificationProbeBus.emitLocal("通知监听已断开")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        NotificationProbeBus.emit(NotificationProbeParser.parse(sbn, applicationContext))
    }
}
