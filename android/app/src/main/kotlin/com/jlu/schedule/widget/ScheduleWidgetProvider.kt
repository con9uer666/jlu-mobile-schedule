package com.jlu.schedule.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import com.jlu.schedule.MainActivity
import com.jlu.schedule.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

/** 三种尺寸共享的渲染逻辑。
 *
 * Dart 侧把整天课程序列化进 SharedPreferences (key=today_payload) 后,
 * 发 APPWIDGET_UPDATE 广播过来;这里读、渲染就行。
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
        val weekLabel = prefs.getString("today_week_label", "") ?: ""
        val dayLabel = prefs.getString("today_day_label", "") ?: ""

        val payload = raw?.let { runCatching { JSONObject(it) }.getOrNull() }
        val courses = payload?.optJSONArray("courses")

        for (id in ids) {
            val views = RemoteViews(context.packageName, layoutRes)
            when (variant) {
                Variant.SMALL -> renderSmall(context, views, courses, weekLabel, dayLabel)
                Variant.MEDIUM, Variant.LARGE -> renderList(context, views, id, courses, weekLabel, dayLabel)
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
        courses: org.json.JSONArray?,
        weekLabel: String,
        dayLabel: String
    ) {
        views.setTextViewText(R.id.widget_week, "$weekLabel · $dayLabel")
        val next = nextCourse(courses)
        if (next == null) {
            views.setTextViewText(R.id.widget_small_main, "今天没课")
            views.setTextViewText(R.id.widget_small_sub, "")
        } else {
            views.setTextViewText(R.id.widget_small_main, next.optString("name"))
            val s = next.optInt("startSection")
            val e = next.optInt("endSection")
            val loc = next.optString("location")
            val sub = buildString {
                append("第${s}-${e}节")
                if (loc.isNotEmpty()) append(" · ").append(loc)
            }
            views.setTextViewText(R.id.widget_small_sub, sub)
        }
        views.setOnClickPendingIntent(R.id.widget_small_main, openAppIntent(context))
        views.setOnClickPendingIntent(R.id.widget_small_sub, openAppIntent(context))
        views.setOnClickPendingIntent(R.id.widget_title, openAppIntent(context))
        views.setOnClickPendingIntent(R.id.widget_week, openAppIntent(context))
    }

    private fun renderList(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        courses: org.json.JSONArray?,
        weekLabel: String,
        dayLabel: String
    ) {
        views.setTextViewText(R.id.widget_week, weekLabel)
        views.setTextViewText(R.id.widget_day, dayLabel)
        views.setOnClickPendingIntent(R.id.widget_title, openAppIntent(context))
        views.setOnClickPendingIntent(R.id.widget_week, openAppIntent(context))
        views.setOnClickPendingIntent(R.id.widget_day, openAppIntent(context))

        val hasCourses = courses != null && courses.length() > 0
        views.setViewVisibility(R.id.widget_empty, if (hasCourses) android.view.View.GONE else android.view.View.VISIBLE)
        views.setViewVisibility(R.id.widget_list, if (hasCourses) android.view.View.VISIBLE else android.view.View.GONE)

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

    private fun nextCourse(arr: org.json.JSONArray?): JSONObject? {
        if (arr == null || arr.length() == 0) return null
        return arr.optJSONObject(0)
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
