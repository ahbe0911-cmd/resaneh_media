import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties().apply {
    if (releasePropertiesFile.exists()) {
        releasePropertiesFile.inputStream().use { load(it) }
    }
}
val signingKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val configuredReleaseSigning = signingKeys.all {
    !releaseProperties.getProperty(it).isNullOrBlank()
}

android {
    namespace = "com.resaneh.mediahub"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.resaneh.mediahub"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", "رسانه")
    }

    flavorDimensions += "brand"
    productFlavors {
        create("ketabkhaneh") {
            dimension = "brand"
            applicationId = "com.resaneh.ketabkhaneh"
            resValue("string", "app_name", "رسانه کتابخانه")
        }
        create("kafinet") {
            dimension = "brand"
            applicationId = "com.resaneh.kafinet"
            resValue("string", "app_name", "رسانه کافی‌نت")
        }
    }

    signingConfigs {
        if (configuredReleaseSigning) {
            create("resanehRelease") {
                storeFile = file(releaseProperties.getProperty("storeFile"))
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // CI always creates key.properties. For local development without
            // that file, allow installation of a debug-signed release APK only.
            signingConfig = if (configuredReleaseSigning) {
                signingConfigs.getByName("resanehRelease")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
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
