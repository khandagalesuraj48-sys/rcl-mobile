package si.sketchline.lion

import android.content.Context
import com.google.android.gms.common.api.OptionalModuleApi
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

/* (3.146.0, asked 19-11-2026: "app install hotana … khup time ghet aahe" – his answer: the app smaller) THE CAMERA'S READERS FROM
 * GOOGLE PLAY SERVICES. Text reading (number plate, meter), face finding (attendance) and the QR scanner are no longer packed inside
 * the app: Google Play services keeps them, once per phone, for every app. When the app opens, Play services is asked to fetch the
 * three at once if this phone does not have them yet (nothing is asked when it has them). Until a part is there, its reading says
 * so (lib/core/ml_ready.dart). A phone without Play services: those three readers do not work (everything else does). */
object MlReady {
    fun ask(c: Context) {
        try {
            val apis = listOf<Any>(
                TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS),
                FaceDetection.getClient(),
                BarcodeScanning.getClient(),
            )
            val wanted = apis.mapNotNull { it as? OptionalModuleApi }
            val close = { apis.forEach { a -> try { (a as? java.io.Closeable)?.close() } catch (e: Exception) { /* closed */ } } }
            if (wanted.isEmpty()) { close(); return }
            val req = ModuleInstallRequest.newBuilder().apply { wanted.forEach { addApi(it) } }.build()
            ModuleInstall.getClient(c).installModules(req).addOnCompleteListener { close() }
        } catch (e: Throwable) { /* no Play services on this phone: the readers say so when used */ }
    }
}
