package com.coyoteatento.motogps

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.coyoteatento.motogps/background"
    private val EVENT_CHANNEL  = "com.coyoteatento.motogps/location"

    private var eventSink: EventChannel.EventSink? = null
    private var localBroadcast: LocalBroadcastManager? = null

    private val locationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != LocationForegroundService.ACTION_LOCATION) return
            val lat     = intent.getDoubleExtra(LocationForegroundService.EXTRA_LAT,     0.0)
            val lng     = intent.getDoubleExtra(LocationForegroundService.EXTRA_LNG,     0.0)
            val speed   = intent.getFloatExtra(LocationForegroundService.EXTRA_SPEED,   0f)
            val bearing = intent.getFloatExtra(LocationForegroundService.EXTRA_BEARING, 0f)
            runOnUiThread {
                eventSink?.success(mapOf(
                    "latitude"  to lat,
                    "longitude" to lng,
                    "speed"     to speed,
                    "heading"   to bearing
                ))
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        localBroadcast = LocalBroadcastManager.getInstance(this)
    }

    override fun onDestroy() {
        localBroadcast?.unregisterReceiver(locationReceiver)
        eventSink = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── MethodChannel: comandos Flutter → Android ────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_START
                    }
                    startForegroundService(intent)
                    result.success(null)
                }
                "stopService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(null)
                }
                "updateInstruction" -> {
                    val instruction = call.argument<String>("instruction") ?: "Navegando..."
                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_UPDATE_TXT
                        putExtra(LocationForegroundService.EXTRA_INSTRUCTION, instruction)
                    }
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── EventChannel: GPS Android → Flutter ──────────────────────
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                localBroadcast?.registerReceiver(
                    locationReceiver,
                    IntentFilter(LocationForegroundService.ACTION_LOCATION)
                )
            }
            override fun onCancel(arguments: Any?) {
                localBroadcast?.unregisterReceiver(locationReceiver)
                eventSink = null
            }
        })
    }
}
