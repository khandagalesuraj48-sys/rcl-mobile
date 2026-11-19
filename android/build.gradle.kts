allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// (3.11.0) file_picker 11 – and (3.15.0) speech_to_text 7.5 – leave their Kotlin code to AGP 9's built-in Kotlin, which this
// project keeps off (the Flutter template's android.builtInKotlin=false – the other plugins bring the Kotlin plugin themselves):
// without it their plugin classes are not compiled and the app does not build. Their Kotlin is compiled with the Kotlin plugin.
subprojects {
    if (name == "file_picker" || name == "speech_to_text" || name == "record_android") {      // (3.132.0) record too, if it leaves its Kotlin the same way
        pluginManager.withPlugin("com.android.library") {
            if (!pluginManager.hasPlugin("org.jetbrains.kotlin.android")) pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}

/* (3.146.0, asked 19-11-2026: "app install hotana mobile madhe khup time ghet aahe" – Android's "Installing…" copies, checks and
 * (Play Protect) scans every byte of the app; his answer: the app smaller, 79 → ~50 MB) THE CAMERA'S READERS FROM GOOGLE PLAY
 * SERVICES: ML Kit's text reading (number plate, meter) and face finding (attendance) are no longer packed inside the app (11 MB +
 * 8.5 MB of native code and their models for every processor) – the same API from Google Play services, which fetches its part
 * once per phone (MlReady.kt asks for it when the app opens; the manifest names them too). The QR scanner: gradle.properties. */
subprojects {
    configurations.all {
        resolutionStrategy.dependencySubstitution {
            substitute(module("com.google.mlkit:text-recognition")).using(module("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1"))
            substitute(module("com.google.mlkit:face-detection")).using(module("com.google.android.gms:play-services-mlkit-face-detection:17.1.0"))
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
