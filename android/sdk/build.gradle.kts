plugins {
  id("com.android.library")
  id("org.jetbrains.kotlin.plugin.compose")
  id("org.jetbrains.kotlin.plugin.serialization")
}

android {
  namespace = "dev.pororoca.ota"
  compileSdk = 36
  defaultConfig { minSdk = 26 }
  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  buildFeatures {
    compose = true
    aidl = false
    buildConfig = false
    shaders = false
  }
}

kotlin { jvmToolchain(17) }

dependencies {
  val composeBom = platform("androidx.compose:compose-bom:2026.03.01")
  implementation(composeBom)
  implementation("androidx.compose.foundation:foundation")
  implementation("androidx.compose.material3:material3")
  implementation("androidx.compose.ui:ui")
  implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
  implementation("com.google.crypto.tink:tink-android:1.23.0")
  testImplementation("junit:junit:4.13.2")
}
