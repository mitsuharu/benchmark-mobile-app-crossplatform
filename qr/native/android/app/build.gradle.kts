plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.plugin.compose")
}

android {
  namespace = "com.example.benchmark.qr.nativeapp"
  compileSdk = 37

  defaultConfig {
    applicationId = "com.example.benchmark.qr.nativeapp"
    minSdk = 24
    targetSdk = 36
    versionCode = 1
    versionName = "1.0"
  }

  buildTypes {
    release {
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      // Signed with the debug key so the release build installs on a device.
      signingConfig = signingConfigs.getByName("debug")
    }
  }

  buildFeatures { compose = true }

  testOptions { unitTests.isIncludeAndroidResources = true }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
}

dependencies {
  implementation("androidx.core:core-ktx:1.19.0")
  implementation("androidx.activity:activity-compose:1.13.0")
  implementation(platform("androidx.compose:compose-bom:2026.09.00"))
  implementation("androidx.compose.foundation:foundation")
  implementation("androidx.compose.ui:ui")
  implementation("androidx.compose.material3:material3")

  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")

  // The bundled model, so nothing is downloaded from Play Services at runtime
  // and every run decodes with the same version.
  implementation("com.google.mlkit:barcode-scanning:17.3.0")

  testImplementation("junit:junit:4.13.2")
  testImplementation("org.robolectric:robolectric:4.17")
  testImplementation("androidx.test:core:1.7.0")
}
