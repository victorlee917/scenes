import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase: google-services.json을 처리해 FirebaseOptions 리소스를 생성.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리스 서명 정보는 git에 안 올리는 android/key.properties에서 읽는다
// (storePassword/keyPassword/keyAlias/storeFile). 파일이 없으면 debug 서명으로
// fallback → 개발/CI 빌드는 그대로 동작.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.tapas.scenes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Play 상 앱 정체성. namespace(com.tapas.scenes, R클래스용)와 의도적으로
        // 다르다 — com.tapas.scenes는 이전 Play 계정에 등록됐다 삭제돼 영구 예약됐고
        // (Google Play는 삭제해도 패키지명을 반납하지 않음), 새 계정으로 출시하려면
        // 재사용 불가하므로 새 applicationId를 쓴다. 이 값도 첫 업로드 후 영구 고정.
        applicationId = "com.tapas.scenesapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties가 있으면 업로드 키로 서명, 없으면 debug로 fallback.
            signingConfig =
                signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
