// Top-level build file.
// Versions chosen for Android Studio running Gradle on Java 25:
//   Gradle 9.1.0 (first Gradle that runs on Java 25) + Android Gradle Plugin 9.0.1.
// AGP 9 compiles Kotlin by itself ("built-in Kotlin"), so the kotlin-android plugin is
// only listed here (apply false) to pick the Kotlin version 2.2.21 (supports JDK 25).
plugins {
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.21" apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
}
