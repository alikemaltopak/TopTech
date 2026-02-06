import com.android.build.api.variant.ApplicationVariant
import org.gradle.api.provider.Provider
import org.gradle.api.Action

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // CRITICAL: Firebase/Google Services plugin added.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.irrigation_control_app"
    compileSdk = flutter.compileSdkVersion

    // Manual adjustment for NDK compatibility.
    // This is required for packages using native code like shared_preferences and url_launcher.
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Required for flutter_local_notifications (and others).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.irrigation_control_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Added to resolve class deletion/crash issues that may occur with ProGuard (R8).
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt")
            )
        }
    }
} // <--- ANDROID BLOĞU BURADA BİTİYOR

flutter {
    source = "../.."
}

// Dependency required for coreLibraryDesugaring feature to work.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
