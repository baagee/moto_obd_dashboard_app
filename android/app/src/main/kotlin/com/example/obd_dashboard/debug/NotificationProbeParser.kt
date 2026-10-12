package com.example.obd_dashboard.debug

import android.app.Notification
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.service.notification.StatusBarNotification
import android.widget.RemoteViews
import java.nio.ByteBuffer
import java.util.zip.CRC32

/**
 * Plan B 探针解析器：把一条通知原样转成可序列化 Map。
 *
 * 与广播探针不同，这里**不做任何字段筛选**——因为高德导航通知里到底有哪些
 * 字段（是走标准 EXTRA_TEXT 还是自定义 RemoteViews）事先完全未知，
 * 必须先把全部信息 dump 出来，才能判断方案是否可行。
 *
 * 针对「通知只有『正在导航』」这一情况，额外做两件事：
 * 1. 反射读取 RemoteViews 的动作列表，捞出对方自定义布局里设置的文本；
 * 2. 对大图标位图取内容校验值，用于判断它是否随转向变化（可能是转向箭头图）。
 */
object NotificationProbeParser {

    fun parse(sbn: StatusBarNotification, context: Context): Map<String, Any?> {
        val n = sbn.notification
        val extras: Bundle = n.extras ?: Bundle.EMPTY

        val map = LinkedHashMap<String, Any?>()
        map["_ts"] = System.currentTimeMillis()
        map["_kind"] = "notification"

        // ── 通知元信息 ──
        map["pkg"] = sbn.packageName
        map["id"] = sbn.id
        map["tag"] = sbn.tag
        map["postTime"] = sbn.postTime
        map["isOngoing"] = sbn.isOngoing
        map["isClearable"] = sbn.isClearable
        map["channelId"] = n.channelId
        map["category"] = n.category
        map["priority"] = n.priority
        map["flags"] = n.flags
        map["tickerText"] = n.tickerText?.toString()

        // ── 自定义视图存在性（决定还有没有戏）──
        map["hasCustomView"] = n.contentView != null
        map["hasBigContentView"] =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) n.bigContentView != null else false
        map["hasHeadsUpContentView"] =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) n.headsUpContentView != null else false

        // ── 标准文本字段 ──
        map["EXTRA_TITLE"] = text(extras, Notification.EXTRA_TITLE)
        map["EXTRA_TEXT"] = text(extras, Notification.EXTRA_TEXT)
        map["EXTRA_BIG_TEXT"] = text(extras, Notification.EXTRA_BIG_TEXT)
        map["EXTRA_SUB_TEXT"] = text(extras, Notification.EXTRA_SUB_TEXT)
        map["EXTRA_INFO_TEXT"] = text(extras, Notification.EXTRA_INFO_TEXT)
        map["EXTRA_SUMMARY_TEXT"] = text(extras, Notification.EXTRA_SUMMARY_TEXT)
        map["EXTRA_TITLE_BIG"] = text(extras, "android.title.big")
        map["EXTRA_TEMPLATE"] = text(extras, "android.template")

        // ── 按钮 ──
        map["actions"] = n.actions?.map { it.title?.toString() }

        // ── 大图标（可能是转向箭头图，用校验值判断是否变化）──
        map["largeIconInfo"] = describeLargeIcon(extras, context)

        // ── 全量 extras（含类型信息）──
        val all = LinkedHashMap<String, String>()
        for (key in extras.keySet()) {
            val v = extras.get(key)
            all[key] = "${v?.javaClass?.simpleName ?: "null"}:$v"
        }
        map["extrasAll"] = all

        // ── 自定义视图内反射出的文本（始终至少返回一条诊断信息）──
        map["remoteViewsText"] = extractRemoteViewsText(n)

        return map
    }

    // ────────────────────────────────────────────────────────────
    // RemoteViews 反射
    // ────────────────────────────────────────────────────────────

    /**
     * 反射读取 RemoteViews 内部动作列表，提取所有设置的内容。
     *
     * 原理：RemoteViews 内部用 `mActions`(ArrayList<Action>) 记录待执行操作，
     * 其中 `ReflectionAction` 保存了 methodName 与 value。对 setTextViewText 而言，
     * value 就是文本本身——这让我们能读到对方自定义布局里写的文字。
     *
     * 依赖私有字段，Android 9+ 隐藏 API 策略下可能被拦截，失败时返回错误信息而非崩溃。
     * 返回列表**始终非空**，便于区分「没有自定义视图」「反射失败」「动作列表为空」。
     */
    private fun extractRemoteViewsText(n: Notification): List<String> {
        val result = mutableListOf<String>()
        val views = mutableListOf<Pair<String, RemoteViews?>>()
        views.add("contentView" to n.contentView)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            views.add("bigContentView" to n.bigContentView)
            views.add("headsUpContentView" to n.headsUpContentView)
        }

        var foundAny = false
        for ((name, rv) in views) {
            if (rv == null) continue
            foundAny = true
            val actions = readActions(rv)
            result.add("[$name] 动作 ${actions.size} 项")
            result.addAll(actions.map { "  $it" })
        }
        if (!foundAny) {
            result.add("(无自定义视图：contentView/bigContentView/headsUpContentView 均为 null)")
        }
        return result
    }

    private fun readActions(rv: RemoteViews): List<String> {
        val out = mutableListOf<String>()
        try {
            val field = RemoteViews::class.java.getDeclaredField("mActions")
            field.isAccessible = true
            val actions = field.get(rv) as? List<*> ?: return out
            for (action in actions) {
                action ?: continue
                try {
                    val cls = action.javaClass
                    val methodName = cls.getDeclaredField("methodName")
                        .apply { isAccessible = true }
                        .get(action) as? String
                    val value = runCatching {
                        cls.getDeclaredField("value")
                            .apply { isAccessible = true }
                            .get(action)
                    }.getOrNull()
                    out.add("${methodName ?: cls.simpleName}=$value")
                } catch (_: Throwable) {
                    // 单个 action 解析失败忽略
                }
            }
        } catch (t: Throwable) {
            out.add("反射失败: ${t.javaClass.simpleName}: ${t.message}")
        }
        return out
    }

    // ────────────────────────────────────────────────────────────
    // 大图标
    // ────────────────────────────────────────────────────────────

    /**
     * 描述大图标：尺寸 + 像素内容 CRC。
     *
     * 若 CRC 随路口变化，说明这张图就是转向箭头，可考虑用图片匹配还原转向。
     */
    private fun describeLargeIcon(extras: Bundle, context: Context): String? {
        val raw = extras.get("android.largeIcon") ?: return null
        val bmp: Bitmap? = when (raw) {
            is Bitmap -> raw
            // Icon.getBitmap() 是 @hide 隐藏 API，公共 SDK 不可用，
            // 改用公共 API loadDrawable() 再自行渲染成位图（需 API 23+）
            is Icon -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                drawableToBitmap(runCatching { raw.loadDrawable(context) }.getOrNull())
            } else {
                null
            }
            else -> null
        }
        bmp ?: return "${raw.javaClass.simpleName}(非位图)"
        return "${bmp.width}x${bmp.height} crc=${crcOf(bmp)}"
    }

    private fun drawableToBitmap(drawable: Drawable?): Bitmap? {
        drawable ?: return null
        val w = drawable.intrinsicWidth.takeIf { it > 0 } ?: 64
        val h = drawable.intrinsicHeight.takeIf { it > 0 } ?: 64
        return try {
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, w, h)
            drawable.draw(canvas)
            bmp
        } catch (_: Throwable) {
            null
        }
    }

    private fun crcOf(bmp: Bitmap): String = try {
        val buffer = ByteBuffer.allocate(bmp.byteCount)
        bmp.copyPixelsToBuffer(buffer)
        val crc = CRC32()
        crc.update(buffer.array())
        java.lang.Long.toHexString(crc.value)
    } catch (t: Throwable) {
        "err(${t.javaClass.simpleName})"
    }

    private fun text(extras: Bundle, key: String): String? =
        extras.getCharSequence(key)?.toString()?.takeIf { it.isNotEmpty() }
}
