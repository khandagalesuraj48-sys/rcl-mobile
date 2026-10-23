package `in`.rachana.rcl.rcl_mobile

import android.app.Activity
import android.app.DownloadManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

/* (3.31.4) THE UPDATE IN THE BACKGROUND (asked 23-10-2026: "app madhun baher al ki updet hoych band hot … background la app updet
 * chaluch asel ani complte al ki konte hi screen war aso mi install karaychi as ek pop up eil"). Channel "rcl/update"
 * (lib/core/update.dart):
 *   start {url, file, version, build, sha} – Android's own Download Manager downloads the update: it goes on when the app is left or
 *     closed and after the network comes back (it is not started again from 0); its progress shows in the phone's notifications;
 *   state – the download kept here: {id, path, version, build, sha, status: pending | running | paused | done | failed | gone, got, total};
 *   install {path} – Android's installer with the file (the app checked its fingerprint first); "permission" = Android's page
 *     "Install unknown apps" was opened instead;
 *   forget – the download and its file go (installed, or a newer one);
 *   clearNote – the notification "Update ready" goes (the app shows its own box).
 * UpdateDoneReceiver: the download ended while the app was away – the notification "Update ready – tap to install" opens the app,
 * which then asks "Install?". */
object UpdateKit {
    private const val PREFS = "rcl_update"
    private const val CHANNEL = "rcl_update"
    private const val NOTE = 7311
    const val APK = "application/vnd.android.package-archive"

    fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun dm(c: Context) = c.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    fun start(c: Context, url: String, file: String, version: String, build: Int, sha: String): Long {
        val p = prefs(c)
        val old = p.getLong("id", -1L)
        if (old >= 0) try { dm(c).remove(old) } catch (e: Exception) { /* already gone */ }
        val dir = c.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: throw IllegalStateException("no place for the file")
        val f = File(dir, file)
        if (f.exists()) f.delete()
        val r = DownloadManager.Request(Uri.parse(url))
            .setTitle("RCL ERP $version")
            .setDescription("Update · अपडेट")
            .setMimeType(APK)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .setDestinationInExternalFilesDir(c, Environment.DIRECTORY_DOWNLOADS, file)
        val id = dm(c).enqueue(r)
        p.edit().putLong("id", id).putString("path", f.absolutePath).putString("version", version).putInt("build", build)
            .putString("sha", sha).apply()
        return id
    }

    fun state(c: Context): Map<String, Any?> {
        val p = prefs(c)
        val id = p.getLong("id", -1L)
        if (id < 0) return emptyMap()
        val out = mutableMapOf<String, Any?>("id" to id, "path" to (p.getString("path", "") ?: ""), "version" to (p.getString("version", "") ?: ""),
            "build" to p.getInt("build", 0), "sha" to (p.getString("sha", "") ?: ""), "status" to "gone", "got" to 0L, "total" to -1L, "reason" to 0)
        try {
            dm(c).query(DownloadManager.Query().setFilterById(id))?.use { cur ->
                if (cur.moveToFirst()) {
                    out["status"] = when (cur.getInt(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))) {
                        DownloadManager.STATUS_SUCCESSFUL -> "done"
                        DownloadManager.STATUS_FAILED -> "failed"
                        DownloadManager.STATUS_PAUSED -> "paused"
                        DownloadManager.STATUS_PENDING -> "pending"
                        else -> "running"
                    }
                    out["got"] = cur.getLong(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                    out["total"] = cur.getLong(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                    out["reason"] = cur.getInt(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                }
            }
        } catch (e: Exception) { /* the Download Manager cannot be asked: "gone" */ }
        return out
    }

    fun forget(c: Context) {
        val p = prefs(c)
        val id = p.getLong("id", -1L)
        if (id >= 0) try { dm(c).remove(id) } catch (e: Exception) { /* already gone */ }
        p.getString("path", null)?.let { try { File(it).delete() } catch (e: Exception) { /* not there */ } }
        p.edit().clear().apply()
        clearNote(c)
    }

    fun install(a: Activity, path: String): String {
        if (Build.VERSION.SDK_INT >= 26 && !a.packageManager.canRequestPackageInstalls()) {
            a.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + a.packageName)))
            return "permission"
        }
        val f = File(path)
        if (!f.exists()) return "missing"
        val uri = FileProvider.getUriForFile(a, a.packageName + ".ota_update_provider", f)
        a.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, APK)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
        return "ok"
    }

    fun note(c: Context, ok: Boolean, version: String) {
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "App update", NotificationManager.IMPORTANCE_HIGH))
        }
        val open = Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pi = PendingIntent.getActivity(c, NOTE, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else Notification.Builder(c)
        b.setSmallIcon(c.applicationInfo.icon).setContentIntent(pi).setAutoCancel(true)
        if (ok) b.setContentTitle("RCL ERP $version – update ready").setContentText("Tap to install · install करण्यासाठी टॅप करा")
        else b.setContentTitle("RCL ERP – update not downloaded").setContentText("Open the app and press Update again · ॲप उघडून पुन्हा Update दाबा")
        try { nm.notify(NOTE, b.build()) } catch (e: Exception) { /* notifications not allowed: the app asks when it is opened */ }
    }

    fun clearNote(c: Context) {
        try { (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTE) } catch (e: Exception) { /* none */ }
    }
}

/** (3.31.4) The Download Manager ended a download – ours: "Update ready – tap to install" (or "not downloaded"). */
class UpdateDoneReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        if (i.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
        val id = i.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
        if (id < 0 || id != UpdateKit.prefs(c).getLong("id", -2L)) return
        val s = UpdateKit.state(c)
        UpdateKit.note(c, s["status"] == "done", (s["version"] ?: "").toString())
    }
}
