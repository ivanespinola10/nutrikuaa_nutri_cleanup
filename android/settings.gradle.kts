pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val propertiesFile = java.io.File("local.properties")
        if (propertiesFile.exists()) {
            properties.load(java.io.FileInputStream(propertiesFile))
        }
        properties.getProperty("flutter.sdk")
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
    id("com.android.application") version "8.6.0" apply false // <--- CAMBIA A 8.6.0
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false // <--- CAMBIA A 2.0.20
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")