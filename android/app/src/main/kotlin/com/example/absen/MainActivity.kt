package com.example.absen

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "absen.dev_options"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "isDeveloperOptionsEnabled") {
                    try {
                        val enabled = Settings.Global.getInt(
                            contentResolver,
                            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                            0,
                        ) == 1
                        result.success(enabled)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
