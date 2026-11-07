package com.jlu.schedule.widget

import android.content.Context
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object WidgetPayloadStore {
    fun load(context: Context): JSONObject {
        val prefs = HomeWidgetPlugin.getData(context)
        val root = runCatching { JSONObject(prefs.getString("today_payload", "{}") ?: "{}") }
            .getOrDefault(JSONObject())
        val now = Calendar.getInstance()
        val key = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now.time)
        root.optJSONObject("days")?.optJSONObject(key)?.let { return it }
        if (root.optString("date") == key ||
            (root.optJSONObject("days") == null && prefs.getString("today_date", "") == key)) return root
        val weekdays = arrayOf("周日", "周一", "周二", "周三", "周四", "周五", "周六")
        return JSONObject().apply {
            put("weekLabel", "请打开应用更新")
            put("dayLabel", weekdays[now.get(Calendar.DAY_OF_WEEK) - 1])
            put("dateShort", "${now.get(Calendar.MONTH) + 1}.${now.get(Calendar.DAY_OF_MONTH)}")
            put("courses", JSONArray())
            put("tomorrowCourses", JSONArray())
        }
    }
}
