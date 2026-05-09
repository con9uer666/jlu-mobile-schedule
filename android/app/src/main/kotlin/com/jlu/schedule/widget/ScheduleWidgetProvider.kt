package com.jlu.schedule.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.jlu.schedule.MainActivity
import com.jlu.schedule.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/** 三种尺寸共享的渲染逻辑。
 *
 * Dart 侧把整天课程序列化进 SharedPreferences (key=today_payload) 后,
 * 发 APPWIDGET_UPDATE 广播过来;这里读、按当前时间过滤、渲染。
 */
abstract class BaseScheduleWidgetProvider : AppWidgetProvider() {

    abstract val layoutRes: Int
    abstract val variant: Variant

    enum class Variant { SMALL, MEDIUM, LARGE }

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString("today_payload", null)
        val payload = raw?.let { runCatching { JSONObject(it) }.getOrNull() }

        val weekLabel = payload?.optString("weekLabel")?.takeIf { it.isNotEmpty() }
            ?: prefs.getString("today_week_label", "") ?: ""
        val dayLabel = payload?.optString("dayLabel")?.takeIf { it.isNotEmpty() }
            ?: prefs.getString("today_day_label", "") ?: ""
        val dateShort = payload?.optString("dateShort") ?: ""

        val courses = payload?.optJSONArray("courses")

        for (id in ids) {
            val views = RemoteViews(context.packageName, layoutRes)
            when (variant) {
                Variant.SMALL -> renderSmall(context, views, courses, weekLabel, dayLabel)
                Variant.MEDIUM, Variant.LARGE ->
                    renderList(context, views, id, courses, weekLabel, dayLabel, dateShort)
            }
            manager.updateAppWidget(id, views)
            if (variant != Variant.SMALL && courses != null && courses.length() > 0) {
                manager.notifyAppWidgetViewDataChanged(id, R.id.widget_list)
            }
        }
    }

    private fun renderSmall(
        context: Context,
        views: RemoteViews,
        courses: JSONArray?,
        weekLabel: String,
        dayLabel: String
    ) {
        views.setTextViewText(R.id.widget_week, weekLabel)
        views.setTextViewText(R.id.widget_day, dayLabel)

        val shown = filterUpcoming(courses).take(2)
        bindSmallRow(views, 0, shown.getOrNull(0))
        bindSmallRow(views, 1, shown.getOrNull(1))
        views.setViewVisibility(
            R.id.small_empty,
            if (shown.isEmpty()) View.VISIBLE else View.GONE
        )

        views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
    }

    private fun bindSmallRow(views: RemoteViews, idx: Int, c: JSONObject?) {
        val ids = smallRowIds(idx)
        if (c == null) {
            views.setViewVisibility(ids.row, View.GONE)
            return
        }
        views.setViewVisibility(ids.row, View.VISIBLE)
        views.setTextViewText(ids.name, c.optString("name"))
        val loc = c.optString("location")
        views.setTextViewText(ids.loc, loc)
        views.setViewVisibility(
            ids.loc,
            if (loc.isEmpty()) View.GONE else View.VISIBLE
        )
        val start = c.optString("startTime")
        val timeText = if (start.isNotEmpty()) {
            start
        } else {
            "第 ${c.optInt("startSection")}-${c.optInt("endSection")} 节"
        }
        views.setTextViewText(ids.time, timeText)
        val accent = parseColor(c.optString("colorAccent"), Color.WHITE)
        views.setInt(ids.dot, "setColorFilter", accent)
    }

    private data class SmallRowIds(
        val row: Int,
        val dot: Int,
        val name: Int,
        val loc: Int,
        val time: Int,
    )

    private fun smallRowIds(idx: Int): SmallRowIds = when (idx) {
        0 -> SmallRowIds(
            R.id.small_row1,
            R.id.small_row1_dot,
            R.id.small_row1_name,
            R.id.small_row1_loc,
            R.id.small_row1_time,
        )
        else -> SmallRowIds(
            R.id.small_row2,
            R.id.small_row2_dot,
            R.id.small_row2_name,
            R.id.small_row2_loc,
            R.id.small_row2_time,
        )
    }

    private fun renderList(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        courses: JSONArray?,
        weekLabel: String,
        dayLabel: String,
        dateShort: String
    ) {
        views.setTextViewText(R.id.widget_date, dateShort)
        views.setTextViewText(R.id.widget_day, dayLabel)
        views.setTextViewText(R.id.widget_week, weekLabel)
        views.setOnClickPendingIntent(R.id.widget_date, openAppIntent(context))
        views.setOnClickPendingIntent(R.id.widget_day, openAppIntent(context))
        views.setOnClickPendingIntent(R.id.widget_week, openAppIntent(context))

        val upcoming = filterUpcoming(courses)
        val hasCourses = upcoming.isNotEmpty()
        views.setViewVisibility(
            R.id.widget_empty,
            if (hasCourses) View.GONE else View.VISIBLE
        )
        views.setViewVisibility(
            R.id.widget_list,
            if (hasCourses) View.VISIBLE else View.GONE
        )

        if (hasCourses) {
            val svc = Intent(context, ScheduleWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            // 每个 widgetId 唯一 data,不然 Android 会复用同一个 factory
            svc.data = Uri.parse("widget://schedule/$widgetId")
            views.setRemoteAdapter(R.id.widget_list, svc)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            // 列表项点击:用 template + fillInIntent 传 courseId
            val clickTpl = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val tplPending = PendingIntent.getActivity(
                context,
                widgetId,
                clickTpl,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_list, tplPending)
        }
    }

    private fun openAppIntent(context: Context): PendingIntent {
        val i = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    companion object {
        fun parseColor(hex: String?, fallback: Int): Int {
            if (hex.isNullOrEmpty()) return fallback
            return runCatching { Color.parseColor(hex) }.getOrDefault(fallback)
        }

        /// endTime(HH:mm)解析后 >= now 的才保留;解析失败默认放行,避免掉课。
        fun filterUpcoming(
            arr: JSONArray?,
            now: Calendar = Calendar.getInstance()
        ): List<JSONObject> {
            if (arr == null) return emptyList()
            val nowMin = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            val out = mutableListOf<JSONObject>()
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val end = o.optString("endTime")
                if (end.isEmpty()) {
                    out.add(o); continue
                }
                val parts = end.split(":")
                if (parts.size != 2) {
                    out.add(o); continue
                }
                val h = parts[0].toIntOrNull()
                val m = parts[1].toIntOrNull()
                if (h == null || m == null) {
                    out.add(o); continue
                }
                if (h * 60 + m >= nowMin) out.add(o)
            }
            return out
        }
    }
}

class ScheduleWidgetProvider : BaseScheduleWidgetProvider() {
    override val layoutRes: Int get() = R.layout.widget_schedule_medium
    override val variant: Variant get() = Variant.MEDIUM
}

class ScheduleWidgetProviderLarge : BaseScheduleWidgetProvider() {
    override val layoutRes: Int get() = R.layout.widget_schedule_large
    override val variant: Variant get() = Variant.LARGE
}

class ScheduleWidgetProviderSmall : BaseScheduleWidgetProvider() {
    override val layoutRes: Int get() = R.layout.widget_schedule_small
    override val variant: Variant get() = Variant.SMALL
}
