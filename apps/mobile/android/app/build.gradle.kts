// ============================================================
// ⚙️ APP BUILD.GRADLE — DraftClub (Optimizado Kotlin DSL)
// ============================================================

plugins {
    // Plugins principales
    id("com.android.application")
    id("org.jetbrains.kotlin.android")

    // Plugins de Firebase
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")

    // Plugin de Flutter
    id("dev.flutter.flutter-gradle-plugin")
}

// ============================================================
// 🧩 Configuración base de Android
// ============================================================
android {
    namespace = "com.example.draftclub_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.draftclub_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // ✅ evita límite de métodos en builds grandes
    }

    compileOptions {
        // Compatibilidad moderna con Java
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // ✅ Desugaring: soporte de APIs modernas en Android viejos
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            isDebuggable = true
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

// ============================================================
// 🧠 Integración Flutter
// ============================================================
flutter {
    source = "../.."
}

// ============================================================
// 📦 Dependencias
// ============================================================
dependencies {
    // 🔥 Firebase BoM (gestiona versiones compatibles entre servicios)
    implementation(platform("com.google.firebase:firebase-bom:34.4.0"))
    implementation("com.google.firebase:firebase-analytics")

    // 🔧 Multidex (proyectos grandes)
    implementation("androidx.multidex:multidex:2.0.1")

    // ✅ Desugaring para APIs modernas
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // 🟦 Forzar versiones compatibles de librerías AndroidX (evita conflicto con Facebook SDK)
    configurations.all {
        resolutionStrategy {
            force("androidx.activity:activity:1.8.0")
            force("androidx.fragment:fragment:1.6.1")
            force("androidx.appcompat:appcompat:1.6.1")
        }
    }
}
