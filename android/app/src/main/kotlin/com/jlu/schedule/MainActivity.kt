package com.jlu.schedule

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingCourseId: String? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitialCourseId" -> {
                        val id = pendingCourseId
                        pendingCourseId = null
                        result.success(id)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingCourseId = intent?.extractCourseId()
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val id = intent.extractCourseId()
        if (id != null) {
            channel?.invokeMethod("onCourseTap", id)
        }
    }

    private fun Intent.extractCourseId(): String? =
        getStringExtra("courseId")?.takeIf { it.isNotEmpty() }

    companion object {
        private const val CHANNEL = "com.jlu.schedule/widget"
    }
}
