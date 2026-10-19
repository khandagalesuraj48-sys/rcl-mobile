package `in`.rachana.rcl.rcl_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/* (3.26.0) THE NOTIFICATION "CALL IS ON" – a foreground service while a call with the web goes on (MainActivity, channel "rcl/call").
 * Its kinds follow what the call uses: the microphone, the camera, the screen ("media projection" – Android shows a screen only
 * with it). A kind Android refuses (a permission not given yet) is left out, so the call itself never stops for it. A tap on the
 * notification opens the app (the call's screen). */
class CallService : Service() {
    companion object {
        var onReady: ((Boolean) -> Unit)? = null
        var running = false
        private const val ID = 7101
        private const val CHANNEL = "rcl_call_on"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val mic = intent?.getBooleanExtra("mic", false) ?: false
        val cam = intent?.getBooleanExtra("cam", false) ?: false
        val screen = intent?.getBooleanExtra("screen", false) ?: false
        val title = intent?.getStringExtra("title")?.takeIf { it.isNotEmpty() } ?: "Call is on"
        val text = intent?.getStringExtra("text")?.takeIf { it.isNotEmpty() } ?: "Tap to go back to the call"
        val n = note(title, text)
        var ok = false
        // the kinds to ask for, the most first: all that is used → without the camera → without the microphone → only the screen → none
        val tries = mutableListOf<Int>()
        if (Build.VERSION.SDK_INT >= 30) {
            var all = 0
            if (mic) all = all or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            if (cam) all = all or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            if (screen) all = all or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            tries.add(all)
            tries.add(all and ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA.inv())
            tries.add(all and ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA.inv() and ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE.inv())
        } else if (Build.VERSION.SDK_INT >= 29) {
            tries.add(if (screen) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION else 0)
        }
        for (t in tries.distinct()) {
            try {
                if (t == 0 && Build.VERSION.SDK_INT >= 34) continue // (Android 14: a kind is needed – the next try is the plain one below)
                if (Build.VERSION.SDK_INT >= 29) startForeground(ID, n, t) else startForeground(ID, n)
                ok = true
                break
            } catch (e: Exception) {
                // that kind is not allowed now: one less
            }
        }
        if (!ok && Build.VERSION.SDK_INT < 34) {
            try {
                startForeground(ID, n)
                ok = true
            } catch (e: Exception) {
            }
        }
        val cb = onReady
        onReady = null
        cb?.invoke(ok || running)
        if (ok) running = true else if (!running) stopSelf() // (already on with its earlier kinds: it stays on)
        return START_NOT_STICKY
    }

    private fun note(title: String, text: String): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Call is on", NotificationManager.IMPORTANCE_LOW))
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.apply { addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP) }
        val pi = if (open != null) PendingIntent.getActivity(this, 0, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT) else null
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        b.setContentTitle(title).setContentText(text).setSmallIcon(applicationInfo.icon).setOngoing(true).setCategory(Notification.CATEGORY_CALL)
        if (pi != null) b.setContentIntent(pi)
        return b.build()
    }

    override fun onDestroy() {
        running = false
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }
}
