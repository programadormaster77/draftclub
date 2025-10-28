import com.android.build.gradle.LibraryExtension

pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false

    // FlutterFire configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    id("com.google.firebase.crashlytics") version("2.8.1") apply false

    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

// ---------------------------------------------------------
// 🔗 Módulos incluidos en la compilación
// ---------------------------------------------------------
include(":app")

// ---------------------------------------------------------
// 🔧 Ajuste opcional de Gradle
// (sin parches de namespace manuales)
// ---------------------------------------------------------

gradle.beforeProject {
    // Puedes colocar aquí cualquier configuración global
    // por ejemplo, logging o variables compartidas
}
