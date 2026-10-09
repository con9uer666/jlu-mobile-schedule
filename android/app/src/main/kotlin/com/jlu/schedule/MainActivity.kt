package com.jlu.schedule

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingDeepLink: String? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitialDeepLink" -> {
                        val uri = pendingDeepLink
                        pendingDeepLink = null
                        result.success(uri)
                    }
                    "consumeInitialCourseId" -> {
                        val id = pendingDeepLink
                            ?.let(Uri::parse)
                            ?.getQueryParameter("id")
                        pendingDeepLink = null
                        result.success(id)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingDeepLink = intent?.extractDeepLink()
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val deepLink = intent.extractDeepLink()
        if (deepLink != null) {
            pendingDeepLink = deepLink
            channel?.invokeMethod("onDeepLink", deepLink)
        }
    }

    private fun Intent.extractDeepLink(): String? {
        data?.takeIf { it.scheme == "schedule" }?.let { return it.toString() }
        getStringExtra("deepLink")?.takeIf { it.isNotEmpty() }?.let { return it }
        getStringExtra("courseId")?.takeIf { it.isNotEmpty() }?.let {
            return Uri.Builder()
                .scheme("schedule")
                .authority("course")
                .appendQueryParameter("id", it)
                .build()
                .toString()
        }
        return null
    }

    companion object {
        private const val CHANNEL = "com.jlu.schedule/widget"
    }
}
