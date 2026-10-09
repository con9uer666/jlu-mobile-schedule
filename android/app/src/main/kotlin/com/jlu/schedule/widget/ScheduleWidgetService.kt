package com.jlu.schedule.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.jlu.schedule.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class ScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        ScheduleRemoteViewsFactory(applicationContext)
}

class ScheduleRemoteViewsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<JSONObject> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString("today_payload", null)
        items = if (raw == null) emptyList() else {
            runCatching {
                val arr = JSONObject(raw).optJSONArray("courses") ?: JSONArray()
                BaseScheduleWidgetProvider.filterUpcoming(arr)
            }.getOrDefault(emptyList())
        }
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val item = items[position]
        val views = RemoteViews(context.packageName, R.layout.widget_schedule_item)

        val name = item.optString("name")
        val teacher = item.optString("teacher")
        val location = item.optString("location")
        val startTime = item.optString("startTime")
        val endTime = item.optString("endTime")
        val accentHex = item.optString("colorAccent")

        views.setTextViewText(R.id.item_name, name)
        val sub = buildString {
            if (teacher.isNotEmpty()) append(teacher)
            if (location.isNotEmpty()) {
                if (isNotEmpty()) append(" · ")
                append(location)
            }
        }
        views.setTextViewText(R.id.item_sub, sub)

        val start = item.optInt("startSection")
        val end = item.optInt("endSection")
        val timeText = when {
            startTime.isNotEmpty() && endTime.isNotEmpty() -> "$startTime – $endTime"
            startTime.isNotEmpty() -> startTime
            else -> "第 ${start}-${end} 节"
        }
        views.setTextViewText(R.id.item_time, timeText)

        views.setInt(
            R.id.item_accent,
            "setColorFilter",
            parseColor(accentHex, Color.parseColor("#FF3D5AFE")),
        )

        // 传 courseId 给 template
        val fill = Intent().apply {
            putExtra("courseId", item.optString("id"))
            data = Uri.parse("schedule://course?id=${Uri.encode(item.optString("id"))}")
        }
        views.setOnClickFillInIntent(R.id.item_root, fill)
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    private fun parseColor(hex: String?, fallback: Int): Int {
        if (hex.isNullOrEmpty()) return fallback
        return runCatching { Color.parseColor(hex) }.getOrDefault(fallback)
    }
}
