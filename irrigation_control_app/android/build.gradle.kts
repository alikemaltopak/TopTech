// Top-level build file where you can add configuration options common to all sub-projects/modules.

plugins {
    // Android Gradle Plugin
    id("com.android.application") version "8.7.3" apply false

    // Kotlin Android Plugin — versiyon 2.1.0 olacak şekilde güncellendi
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false

    // Flutter Gradle Plugin
    id("dev.flutter.flutter-gradle-plugin") apply false

    // Firebase Google Services Plugin
    id("com.google.gms.google-services") version "4.4.2" apply false
}

// Alt projeler için repository tanımları
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Temizleme görevi (opsiyonel)
tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
