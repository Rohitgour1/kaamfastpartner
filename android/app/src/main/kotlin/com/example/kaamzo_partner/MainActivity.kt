package com.kaamfast.partner

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "kaamfast.partner/launch"
        private const val OVERLAY_ENGINE_ID = "myCachedEngine"
        private const val JOB_CHANNEL_ID = "kaamfast_jobs"
        private const val UPDATE_CHANNEL_ID = "kaamfast_updates"
        private var player: MediaPlayer? = null
        private var vibrating = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureJobChannel()
        bindLaunchChannel(flutterEngine)
        bindLaunchChannelToOverlayEngine()
    }

    override fun onResume() {
        super.onResume()
        bindLaunchChannelToOverlayEngine()
    }

    private fun bindLaunchChannelToOverlayEngine() {
        val overlayEngine = FlutterEngineCache.getInstance().get(OVERLAY_ENGINE_ID) ?: return
        bindLaunchChannel(overlayEngine)
    }

    private fun bindLaunchChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bringToForeground" -> {
                        OverlayLaunch.bringToForeground(applicationContext)
                        result.success(true)
                    }
                    "attachOverlayLaunch" -> {
                        bindLaunchChannelToOverlayEngine()
                        result.success(true)
                    }
                    "playJobAlert" -> {
                        playJobAlert()
                        result.success(true)
                    }
                    "stopJobAlert" -> {
                        stopJobAlert()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playJobAlert() {
        stopJobAlert()
        try {
            val media = MediaPlayer()
            val afd = openRingtoneAsset()
            if (afd != null) {
                media.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
            } else {
                val uri = jobRingtoneUri()
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                media.setDataSource(applicationContext, uri)
            }
            media.isLooping = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                media.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            } else {
                @Suppress("DEPRECATION")
                media.setAudioStreamType(AudioManager.STREAM_RING)
            }
            media.prepare()
            media.start()
            player = media
        } catch (_: Exception) {
            player = null
        }
        vibrateLoop()
    }

    private fun openRingtoneAsset(): AssetFileDescriptor? {
        val paths = arrayOf(
            "flutter_assets/assets/audio/ringtone.wav",
            "assets/audio/ringtone.wav",
        )
        for (path in paths) {
            try {
                return assets.openFd(path)
            } catch (_: Exception) {
            }
        }
        return null
    }

    private fun jobRingtoneUri(): Uri? {
        return try {
            Uri.parse("android.resource://${packageName}/${R.raw.job_ringtone}")
        } catch (_: Exception) {
            null
        }
    }

    private fun stopJobAlert() {
        try {
            player?.stop()
            player?.release()
        } catch (_: Exception) {
        }
        player = null
        stopVibrate()
    }

    private fun vibrateLoop() {
        val pattern = longArrayOf(0, 700, 280, 700, 280, 700, 900)
        vibrating = true
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(VibratorManager::class.java)
                vm?.defaultVibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun stopVibrate() {
        if (!vibrating) return
        vibrating = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(VibratorManager::class.java)?.defaultVibrator?.cancel()
            } else {
                @Suppress("DEPRECATION")
                (getSystemService(VIBRATOR_SERVICE) as? Vibrator)?.cancel()
            }
        } catch (_: Exception) {
        }
    }

    private fun ensureJobChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        val sound = jobRingtoneUri() ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(
            JOB_CHANNEL_ID,
            "New jobs",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Rings until the partner accepts or rejects a new order"
            setSound(sound, attrs)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 600, 250, 600)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(channel)
        val updates = NotificationChannel(
            UPDATE_CHANNEL_ID,
            "Job updates",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Status updates after you accept or complete a job"
            enableVibration(false)
            setSound(null, null)
        }
        nm.createNotificationChannel(updates)
    }
}
