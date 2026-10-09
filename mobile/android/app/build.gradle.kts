plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val expectedGoogleWebClientId =
    "318821887059-iukcc2mai6klc7ml1a1h121ev37rvsvm.apps.googleusercontent.com"
val expectedGoogleAndroidPackage = "com.example.ello_mobile"

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.example.ello_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.ello_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Evita a etapa R8, que fica excessivamente lenta neste projeto
            // por causa das dependencias de Firebase durante os builds de teste.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

val verifyGoogleOAuthConfig by tasks.registering {
    group = "verification"
    description = "Verifies the Google OAuth IDs required by Android sign-in."

    val stringsFile = file("src/main/res/values/strings.xml")
    val googleServicesFile = file("google-services.json")
    val dartConfigFile = rootProject.file("../lib/core/config/app_config.dart")

    inputs.files(stringsFile, googleServicesFile, dartConfigFile)

    doLast {
        check(android.defaultConfig.applicationId == expectedGoogleAndroidPackage) {
            "Google OAuth package mismatch: expected $expectedGoogleAndroidPackage."
        }
        check(stringsFile.readText().contains(expectedGoogleWebClientId)) {
            "default_web_client_id is missing or incorrect in strings.xml."
        }
        check(dartConfigFile.readText().contains(expectedGoogleWebClientId)) {
            "Google Web Client ID is missing or incorrect in AppConfig."
        }
        check(googleServicesFile.readText().contains(
            "\"package_name\": \"$expectedGoogleAndroidPackage\"",
        )) {
            "google-services.json does not match the Android application ID."
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn(verifyGoogleOAuthConfig)
}
