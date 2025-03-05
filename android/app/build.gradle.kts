plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin must be applied after Android & Kotlin
    id("com.google.gms.google-services") // Google services plugin
}

android {
    namespace = "com.example.pu_circle"
    compileSdk = 35 // Replace with your actual compileSdk version

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.pu_circle"
        minSdk = 21  // Adjust as needed
        //noinspection OldTargetApi
        targetSdk = 34 // Adjust as needed
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

// Ensure dependencies are correctly configured
dependencies {
//    implementation(platform("com.google.firebase:firebase-bom:33.10.0"))
    implementation("com.google.android.gms:play-services-auth:21.3.0") // Example dependency, adjust as needed
//    implementation("com.google.firebase:firebase-appcheck-playintegrity")
}

// Apply Google Services at the bottom to ensure correct application
apply(plugin = "com.google.gms.google-services")
