package `in`.rachana.rcl.rcl_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager

/* (3.26.0) A call with the web (lib/core/rtc_kit.dart, channel "rcl/call"):
 *   start {mic, cam, screen, title, text} – the notification "Call is on" (CallService, a foreground service): Android shows the phone's
 *     screen only while it is on, and keeps the microphone (and the camera) working while another app is open. The answer comes once
 *     the service is really in the foreground (Android 14: before the screen is taken), at most after 3 s;
 *   stop – the notification goes;
 *   awake {on} – the screen stays on while a call is on (it may sleep again after it). */
// (3.27.0) a FragmentActivity: the app lock (local_auth – the phone's fingerprint / face box) needs it
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MlReady.ask(applicationContext)      // (3.146.0) the camera's readers from Google Play services – fetched once if missing
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rcl/call").setMethodCallHandler { call, result ->
            when (call.method) {
                "awake" -> {
                    if (call.argument<Boolean>("on") == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(true)
                }
                "start" -> {
                    val i = Intent(this, CallService::class.java)
                        .putExtra("mic", call.argument<Boolean>("mic") ?: false)
                        .putExtra("cam", call.argument<Boolean>("cam") ?: false)
                        .putExtra("screen", call.argument<Boolean>("screen") ?: false)
                        .putExtra("title", call.argument<String>("title") ?: "")
                        .putExtra("text", call.argument<String>("text") ?: "")
                    var done = false
                    val answer = { ok: Boolean -> if (!done) { done = true; result.success(ok) } }
                    CallService.onReady = { ok -> answer(ok) }
                    try {
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                    } catch (e: Exception) {
                        CallService.onReady = null
                        answer(false)
                    }
                    Handler(Looper.getMainLooper()).postDelayed({ answer(false) }, 3000)
                }
                "stop" -> {
                    CallService.onReady = null
                    stopService(Intent(this, CallService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        /* (3.103.0, HR attendance – lib/core/attend.dart, channel "rcl/attend"): what only the phone itself can say –
         *   info – this phone's own number for this app (ANDROID_ID: the same until the phone is reset), its make and Android;
         *   devOptions – are Developer Options switched on (then no punch – only attendance is stopped);
         *   elapsed – the milliseconds since the phone was switched on (a counter the person cannot set): the moment of a punch
         *     taken without a network is worked out from it. */
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rcl/attend").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "info" -> result.success(mapOf(
                        "id" to (Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: ""),
                        "model" to (Build.MANUFACTURER + " " + Build.MODEL).trim(),
                        "os" to ("Android " + Build.VERSION.RELEASE)))
                    "devOptions" -> result.success(Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) != 0)
                    "elapsed" -> result.success(SystemClock.elapsedRealtime())
                    /* (3.153.0, asked 20-11-2026: "attendance pdf download … direct phone madhe download hoil, user la warti disel notification")
                     * saveDownload {name, mime, bytes, text} – the file is put in the phone's Downloads (Android 10 and newer: no
                     * permission is needed for the app's own file) and a notification says so; a touch on it opens the file.
                     * false: an older Android – the app hands the file to the share sheet as before. */
                    "saveDownload" -> {
                        val name = call.argument<String>("name") ?: "file.pdf"
                        val mime = call.argument<String>("mime") ?: "application/pdf"
                        val text = call.argument<String>("text") ?: "Downloaded"
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            result.success(false)
                        } else {
                            val values = ContentValues()
                            values.put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                            values.put(MediaStore.MediaColumns.MIME_TYPE, mime)
                            values.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                            values.put(MediaStore.MediaColumns.IS_PENDING, 1)
                            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                            if (uri == null) {
                                result.success(false)
                            } else {
                                contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                                val done = ContentValues()
                                done.put(MediaStore.MediaColumns.IS_PENDING, 0)
                                contentResolver.update(uri, done, null, null)
                                try {
                                    val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                                    nm.createNotificationChannel(NotificationChannel("rcl_downloads", "Downloads", NotificationManager.IMPORTANCE_HIGH))
                                    val open = Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                                    val tap = PendingIntent.getActivity(this, name.hashCode(), open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                                    val note = Notification.Builder(this, "rcl_downloads").setSmallIcon(android.R.drawable.stat_sys_download_done)
                                        .setContentTitle(name).setContentText(text).setContentIntent(tap).setAutoCancel(true).build()
                                    nm.notify(name.hashCode(), note)
                                } catch (e: Exception) { /* notifications not allowed: the file is in Downloads all the same */ }
                                result.success(true)
                            }
                        }
                    }
                    // (3.136.0, rcl-hr step 16) the phone's own proof (Google Play Integrity, the standard request): a token bound
                    // to this punch; any fault gives "" – the punch goes as before and the HR server decides
                    "integrity" -> {
                        val project = (call.argument<Any>("project") as? Number)?.toLong() ?: 0L
                        val hash = call.argument<String>("hash") ?: ""
                        if (project <= 0L) { result.success(""); return@setMethodCallHandler }
                        val done = java.util.concurrent.atomic.AtomicBoolean(false)
                        val give: (String) -> Unit = { t -> if (done.compareAndSet(false, true)) result.success(t) }
                        IntegrityManagerFactory.createStandard(applicationContext)
                            .prepareIntegrityToken(StandardIntegrityManager.PrepareIntegrityTokenRequest.builder().setCloudProjectNumber(project).build())
                            .addOnSuccessListener { provider ->
                                provider.request(StandardIntegrityManager.StandardIntegrityTokenRequest.builder().setRequestHash(hash).build())
                                    .addOnSuccessListener { t -> give(t.token()) }
                                    .addOnFailureListener { give("") }
                            }
                            .addOnFailureListener { give("") }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("attend", e.message ?: e.toString(), null)
            }
        }
        // (3.31.4) the update in the background – Android's Download Manager (UpdateKit.kt)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rcl/update").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> result.success(UpdateKit.start(this, call.argument<String>("url") ?: "", call.argument<String>("file") ?: "rcl-erp.apk",
                        call.argument<String>("version") ?: "", call.argument<Int>("build") ?: 0, call.argument<String>("sha") ?: "", call.argument<String>("alt") ?: ""))
                    "state" -> result.success(UpdateKit.state(this))
                    "install" -> result.success(UpdateKit.install(this, call.argument<String>("path") ?: ""))
                    "forget" -> { UpdateKit.forget(this); result.success(true) }
                    "clearNote" -> { UpdateKit.clearNote(this); result.success(true) }
                    "self" -> result.success(UpdateKit.self(this))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("update", e.message ?: e.toString(), null)
            }
        }
    }
}
