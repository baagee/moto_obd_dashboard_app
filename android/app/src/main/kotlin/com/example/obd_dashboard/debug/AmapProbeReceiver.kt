package com.example.obd_dashboard.debug

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Phase 0 探针广播接收器。
 *
 * 职责单一：把高德导航广播 [ACTION_SEND] 的 extras 全量转成可序列化 Map 往上抛，
 * 不做任何字段筛选 / 归一化（那是后续 Phase 3 NaviProvider 的职责）。
 *
 * 高德同名字段在不同版本可能是 Int / String / float / int[]，
 * 这里统一转成 EventChannel 可序列化的类型，避免序列化崩溃。
 */
class AmapProbeReceiver(
    private val onBroadcast: (Map<String, Any?>) -> Unit,
) : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != ACTION_SEND) return
        val extras = intent.extras ?: return
        val map = HashMap<String, Any?>()
        map["_action"] = intent.action
        map["_ts"] = System.currentTimeMillis()
        for (key in extras.keySet()) {
            map[key] = when (val v = extras.get(key)) {
                null -> null
                is IntArray -> v.toList()
                is LongArray -> v.toList()
                is FloatArray -> v.toList()
                is DoubleArray -> v.toList()
                is BooleanArray -> v.toList()
                is Number, is String, is Boolean -> v
                else -> v.toString() // 兜底：不可序列化对象转字符串
            }
        }
        onBroadcast(map)
    }

    companion object {
        /** 高德导航向外发送的标准广播 action */
        const val ACTION_SEND = "AUTONAVI_STANDARD_BROADCAST_SEND"
    }
}
