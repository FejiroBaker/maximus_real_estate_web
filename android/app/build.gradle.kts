plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.maximus_real_estate"

    compileSdk = 36  // Back to 36 - works with updated ML Kit

    ndkVersion = "27.3.13750724"

    defaultConfig {
        applicationId = "com.example.maximus_real_estate"
        minSdk = flutter.minSdkVersion  // ML Kit requirement
        targetSdk = 36  // Updated to match compileSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.multidex:multidex:2.0.1")  // Added for multidex support
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}

flutter {
    source = "../.."
}

afterEvaluate {
    tasks.matching { it.name.startsWith("assemble") }.configureEach {
        doLast {
            val androidApkDir = file("$buildDir/outputs/flutter-apk")
            val flutterApkDir = file("${rootProject.projectDir}/build/app/outputs/flutter-apk")

            if (androidApkDir.exists()) {
                flutterApkDir.mkdirs()
                androidApkDir.listFiles()?.forEach { apk ->
                    apk.copyTo(flutterApkDir.resolve(apk.name), overwrite = true)
                }
                androidApkDir.deleteRecursively()
            }
        }
    }
}
