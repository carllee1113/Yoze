package com.yoze.yoze

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.yoze.yoze/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "clearScheduledNotificationCache" -> {
                        clearScheduledNotificationCache()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun clearScheduledNotificationCache() {
        val preferences = getSharedPreferences("scheduled_notifications", Context.MODE_PRIVATE)
        preferences.edit().remove("scheduled_notifications").apply()
    }
}
