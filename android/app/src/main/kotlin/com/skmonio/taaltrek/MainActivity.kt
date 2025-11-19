package com.skmonio.taaltrek

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.skmonio.taaltrek/sound_mode"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isDeviceNotSilent") {
                val isNotSilent = checkIfDeviceNotSilent()
                result.success(isNotSilent)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun checkIfDeviceNotSilent(): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return when (audioManager.ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> false
            AudioManager.RINGER_MODE_VIBRATE -> true  // Vibrate mode is considered "not silent" for sound purposes
            AudioManager.RINGER_MODE_NORMAL -> true
            else -> true  // Default to playing sound if unknown
        }
    }
}
