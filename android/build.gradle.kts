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

// (3.11.0) file_picker 11 leaves its Kotlin code to AGP 9's built-in Kotlin, which this project keeps off (the Flutter template's
// android.builtInKotlin=false – the other plugins bring the Kotlin plugin themselves): without it FilePickerPlugin is not compiled
// and the app does not build. Its Kotlin is compiled with the Kotlin plugin, as the other plugins do.
subprojects {
    if (name == "file_picker") {
        pluginManager.withPlugin("com.android.library") {
            if (!pluginManager.hasPlugin("org.jetbrains.kotlin.android")) pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
