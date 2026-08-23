import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyProperties = Properties()
val releaseKeyFile = rootProject.file("key.properties")
if (releaseKeyFile.exists()) {
    releaseKeyFile.inputStream().use { stream -> releaseKeyProperties.load(stream) }
}
fun releaseSecret(name: String, environment: String): String? =
    releaseKeyProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: System.getenv(environment)?.takeIf { it.isNotBlank() }
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "com.sisapedia.sisapedia"
    // Use the latest stable Android platform available to the Flutter toolchain.
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sisapedia.sisapedia"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storePath = releaseSecret("storeFile", "ANDROID_KEYSTORE_FILE")
            val storePasswordValue = releaseSecret("storePassword", "ANDROID_KEYSTORE_PASSWORD")
            val aliasValue = releaseSecret("keyAlias", "ANDROID_KEY_ALIAS")
            val keyPasswordValue = releaseSecret("keyPassword", "ANDROID_KEY_PASSWORD")
            if (storePath != null && storePasswordValue != null && aliasValue != null && keyPasswordValue != null) {
                storeFile = file(storePath)
                storePassword = storePasswordValue
                keyAlias = aliasValue
                keyPassword = keyPasswordValue
            }
        }
    }

    buildTypes {
        release {
            val configured = releaseSecret("storeFile", "ANDROID_KEYSTORE_FILE") != null &&
                releaseSecret("storePassword", "ANDROID_KEYSTORE_PASSWORD") != null &&
                releaseSecret("keyAlias", "ANDROID_KEY_ALIAS") != null &&
                releaseSecret("keyPassword", "ANDROID_KEY_PASSWORD") != null
            if (!configured && releaseTaskRequested) {
                throw GradleException("Release signing requires android/key.properties or ANDROID_KEYSTORE_* environment variables")
            }
            signingConfig = signingConfigs.getByName("release")
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
