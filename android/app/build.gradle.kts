import java.util.Properties
import java.io.FileInputStream

val keyProps = Properties().apply { val f = rootProject.file("key.properties"); if (f.exists()) FileInputStream(f).use { load(it) } }

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// (3.42.0) Firebase (the notifications at once, also with the app closed): only when the build put its settings here (the GitHub
// secret GOOGLE_SERVICES_JSON – never in git, the repository is public). Without them the app is built as before.
if (file("google-services.json").exists()) apply(plugin = "com.google.gms.google-services")

android {
    namespace = "in.rachana.rcl.rcl_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "in.rachana.rcl.rcl_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(24, flutter.minSdkVersion)      // (3.27.0) the app lock (local_auth) needs Android 7 or newer
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // (3.19.1, asked 17-10-2026: "android warti app updet krtana khup slow hote te speed up kr") only the phones' processors are
    // packed: the emulators' parts (x86_64 – 18 MB of ML Kit) are left out. The release also makes one file per processor
    // (RCL_ABIS, the same version code): a phone's update downloads only its own (lib/core/update.dart). (ndk.abiFilters is not
    // used: the build check showed it left every processor in – the native libraries are left out when packed.)
    val keepAbis = (System.getenv("RCL_ABIS") ?: "armeabi-v7a,arm64-v8a").split(",").map { it.trim() }
    packaging {
        jniLibs {
            excludes += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64").filter { it !in keepAbis }.map { "**/$it/**" }
        }
    }

    signingConfigs {
        create("release") {
            if (keyProps.isNotEmpty()) {
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
                storeFile = rootProject.file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = if (keyProps.isNotEmpty()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")      // (3.1.8) ML Kit
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.1")      // (3.27.0) the AppCompat themes the fingerprint box needs
}
