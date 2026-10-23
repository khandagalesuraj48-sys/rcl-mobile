package `in`.rachana.rcl.rcl_mobile

import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
        // (3.31.4) the update in the background – Android's Download Manager (UpdateKit.kt)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rcl/update").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> result.success(UpdateKit.start(this, call.argument<String>("url") ?: "", call.argument<String>("file") ?: "rcl-erp.apk",
                        call.argument<String>("version") ?: "", call.argument<Int>("build") ?: 0, call.argument<String>("sha") ?: ""))
                    "state" -> result.success(UpdateKit.state(this))
                    "install" -> result.success(UpdateKit.install(this, call.argument<String>("path") ?: ""))
                    "forget" -> { UpdateKit.forget(this); result.success(true) }
                    "clearNote" -> { UpdateKit.clearNote(this); result.success(true) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("update", e.message ?: e.toString(), null)
            }
        }
    }
}
