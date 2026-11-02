package PACKAGE_NAME

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

class AlarmService : Service() {
    companion object {
        @Volatile var ringingAid: Int = -1
        @Volatile var ringingName: String = ""
        const val CHANNEL = "alarma_radio"
        const val NOTIF_ID = 4242
    }

    private var player: MediaPlayer? = null
    private var wake: PowerManager.WakeLock? = null
    private var watchdog: Runnable? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            stopSelf()
            return START_NOT_STICKY
        }
        val aid = intent?.getIntExtra("aid", -1) ?: -1
        val name = intent?.getStringExtra("name") ?: "Radio Mundo"
        val url = intent?.getStringExtra("url") ?: ""
        ringingAid = aid
        ringingName = name
        startForeground(NOTIF_ID, buildNotification(name))
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "radiomundo:alarm")
            wake?.acquire(30 * 60 * 1000L)
        } catch (e: Exception) {
        }
        raiseVolume()
        startAudio(url)
        try {
            MainActivity.channel?.invokeMethod("ringing", mapOf("aid" to aid, "name" to name))
        } catch (e: Exception) {
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(name: String): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            val ch = NotificationChannel(CHANNEL, "Despertador", NotificationManager.IMPORTANCE_HIGH)
            ch.setSound(null, null)
            ch.enableVibration(false)
            ch.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            nm.createNotificationChannel(ch)
        }
        val imm = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
        val openIntent = Intent(this, MainActivity::class.java)
        openIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val open = PendingIntent.getActivity(this, 1, openIntent, imm or PendingIntent.FLAG_UPDATE_CURRENT)
        val stopIntent = Intent(this, AlarmService::class.java)
        stopIntent.action = "STOP"
        val stop = PendingIntent.getService(this, 2, stopIntent, imm or PendingIntent.FLAG_UPDATE_CURRENT)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        b.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
        b.setContentTitle("Despertador - Radio Mundo")
        b.setContentText(name)
        b.setContentIntent(open)
        b.setFullScreenIntent(open, true)
        b.setOngoing(true)
        b.setCategory(Notification.CATEGORY_ALARM)
        b.setPriority(Notification.PRIORITY_HIGH)
        b.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Detener", stop)
        return b.build()
    }

    private fun raiseVolume() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val cur = am.getStreamVolume(AudioManager.STREAM_ALARM)
            if (cur < max / 2) {
                am.setStreamVolume(AudioManager.STREAM_ALARM, (max * 0.6).toInt(), 0)
            }
        } catch (e: Exception) {
        }
    }

    private fun startAudio(url: String) {
        stopAudio()
        if (url.isEmpty()) {
            fallback()
            return
        }
        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            mp.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            mp.setDataSource(url)
            mp.setOnPreparedListener { p -> p.start() }
            mp.setOnErrorListener { _, _, _ ->
                fallback()
                true
            }
            mp.prepareAsync()
            player = mp
            val w = Runnable {
                if (player?.isPlaying != true) {
                    fallback()
                }
            }
            watchdog = w
            handler.postDelayed(w, 20000)
        } catch (e: Exception) {
            fallback()
        }
    }

    /** Si la emisora no responde, suena el tono de alarma del teléfono. */
    private fun fallback() {
        stopAudio()
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            mp.setDataSource(this, uri)
            mp.isLooping = true
            mp.prepare()
            mp.start()
            player = mp
        } catch (e: Exception) {
        }
    }

    private fun stopAudio() {
        watchdog?.let { handler.removeCallbacks(it) }
        watchdog = null
        try {
            player?.stop()
        } catch (e: Exception) {
        }
        try {
            player?.release()
        } catch (e: Exception) {
        }
        player = null
    }

    override fun onDestroy() {
        stopAudio()
        try {
            if (wake?.isHeld == true) {
                wake?.release()
            }
        } catch (e: Exception) {
        }
        ringingAid = -1
        ringingName = ""
        super.onDestroy()
    }
}
