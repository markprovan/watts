package com.markprovan.watts

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes the battery values Flutter plugins don't: current, voltage, temperature and charge counter.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "watts/battery")
            .setMethodCallHandler { call, result ->
                if (call.method == "snapshot") result.success(readSnapshot()) else result.notImplemented()
            }
    }

    private fun readSnapshot(): Map<String, Any> {
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val manager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        return mapOf(
            "levelPercent" to if (level >= 0 && scale > 0) level * 100 / scale else 0,
            "status" to status,
            "voltageMv" to (intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) ?: 0),
            "currentRaw" to manager.getLongProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW),
            "chargeCounterUah" to manager.getLongProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER),
            "temperatureTenthsC" to (intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0),
            "plugged" to (intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0),
            // The system's own estimate to full charge, in milliseconds; -1 if unknown.
            "systemChargeTimeMs" to systemChargeTimeMs(manager),
        )
    }

    private fun systemChargeTimeMs(manager: BatteryManager): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.computeChargeTimeRemaining()
        } else {
            -1L
        }
}
