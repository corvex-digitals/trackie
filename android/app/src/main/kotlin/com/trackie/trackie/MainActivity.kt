package com.trackie.trackie

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes battery-optimisation status and system settings shortcuts to Dart
 * (lib/core/platform/system_settings.dart), so onboarding and Settings can
 * guide the user to keep reminders reliable on aggressive OEM builds.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "trackie/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openBatteryOptimizationSettings" -> {
                        open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        open(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                .setData(Uri.fromParts("package", packageName, null))
                        )
                        result.success(null)
                    }
                    "manufacturer" -> result.success(Build.MANUFACTURER ?: "")
                    else -> result.notImplemented()
                }
            }
    }

    /** Falls back to the app's details page if a settings screen is missing. */
    private fun open(intent: Intent) {
        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.fromParts("package", packageName, null))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}
