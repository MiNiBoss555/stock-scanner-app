package com.scanproduct.stockscanner

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stock_scanner/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playScanBeep" -> {
                        playScanBeep()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }

    private fun playScanBeep() {
        try {
            val generator = toneGenerator
                ?: ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100).also {
                    toneGenerator = it
                }
            generator.startTone(ToneGenerator.TONE_PROP_BEEP2, 180)
        } catch (_: RuntimeException) {
        }
    }
}
