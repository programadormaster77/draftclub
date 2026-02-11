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

android {
    namespace = "com.example.draftclub_mobile" // <-- usa el nombre real de tu paquete si luego cambiaslo
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.draftclub_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // 🧩 evita errores de métodos excedidos
    }

    compileOptions {
        // Compatibilidad con Java moderno
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // Usa tu configuración real de firma si la tienes (para Play Store)
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            // Configuración ligera para desarrollo
            isDebuggable = true
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🔥 Firebase BoM — controla versiones compatibles entre servicios
    implementation(platform("com.google.firebase:firebase-bom:34.4.0"))

    // 📊 Firebase Analytics (puedes agregar más módulos si los usas)
    implementation("com.google.firebase:firebase-analytics")

    // 🔧 Compatibilidad multidex (para proyectos grandes con muchos imports)
    implementation("androidx.multidex:multidex:2.0.1")
    
    // ☕ Desugaring para Java 8+ APIs (Timezone, etc)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

configurations.all {
    resolutionStrategy {
        force("androidx.core:core-ktx:1.15.0")
        force("androidx.core:core:1.15.0")
        force("androidx.activity:activity:1.9.3")
        force("androidx.navigationevent:navigationevent-android:1.0.0")
    }
}
