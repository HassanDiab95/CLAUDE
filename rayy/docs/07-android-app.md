# 07 · Android Application

Code: [`android/Rayy/`](../android/Rayy), a **native Android app** in **Kotlin + Jetpack Compose (Material 3)**
using the official **Firebase Android SDK** (Authentication + Realtime Database).
It shows the same data as the web dashboard in a simple, phone-friendly design. It is in **Arabic or English**
automatically, following the phone language.

| Screen | Contents |
|---|---|
| **Login** | Email + password (the same accounts as the web) |
| **🏠 Plant** | Big emoji + mood message, last update, online/offline, moisture, temperature, humidity, light, Wi-Fi signal; **Play** button with the melody list; **Mute** switch |
| **📈 History** | Last 24 hours line chart. Choose moisture / temp / humidity / light. Min / average / max |
| **📔 Diary** | List of mood changes with emoji and time |

Minimum Android version: **7.0 (API 24)**. Target: API 34.

## 7.1 Requirements

* **Android Studio** (Koala 2024.1 or newer): <https://developer.android.com/studio>. It includes the JDK and Android SDK.
* The `google-services.json` file from your Firebase project ([04](04-firebase-setup.md), step 5).

## 7.2 Open, build and run

1. Copy **`google-services.json`** into **`android/Rayy/app/`**. Without it the build fails with
   *"File google-services.json is missing"*.
2. Android Studio → **File → Open** → select the **`android/Rayy`** folder (Android Studio shows the project name **Rayy**) → wait for "Gradle sync" to finish
   (the first time it downloads Gradle 8.9 and the libraries, so an internet connection is required).
3. Connect a phone with **USB debugging** enabled (Settings → About phone → tap "Build number" 7 times →
   Developer options → USB debugging), or create an emulator (Device Manager).
4. Press **▶ Run**. Sign in with a user from Firebase Authentication.

**Make an APK to install on any phone:** **Build → Build App Bundle(s) / APK(s) → Build APK(s)** →
`android/Rayy/app/build/outputs/apk/debug/app-debug.apk`. Send it to the phone and install it ("allow unknown sources").

> If the app shows no data but the web does, your database is probably not in the US region. Put its URL in
> `DATABASE_URL` in `app/src/main/java/com/rayy/app/Model.kt`.

## 7.3 Code structure

```
android/Rayy/                 ← open this folder in Android Studio (project "Rayy")
├── settings.gradle.kts, build.gradle.kts, gradle.properties, gradlew   (Gradle 8.9, AGP 8.5, Kotlin 2.0)
└── app/
    ├── build.gradle.kts                 dependencies: Firebase BoM 33, Compose BoM 2024.09
    ├── google-services.json             ← YOU add this file
    └── src/main/
        ├── AndroidManifest.xml          INTERNET permission
        ├── java/com/rayy/app/
        │   ├── MainActivity.kt          shows Login or Main screen
        │   ├── PlantViewModel.kt        Firebase login + real-time listeners (StateFlow)
        │   ├── Model.kt                 data classes + PLANT_ID + parsing of snapshots
        │   └── ui/
        │       ├── LoginScreen.kt
        │       ├── MainScreen.kt        bottom navigation: Plant / History / Diary
        │       ├── LineChart.kt         small chart drawn with Canvas
        │       ├── Moods.kt             mood → emoji + texts, time format
        │       └── Theme.kt             green Material 3 theme (light / dark)
        └── res/values/strings.xml (English) · res/values-ar/strings.xml (Arabic)
```

**How it works:** `PlantViewModel` listens to Firebase with `addValueEventListener` on `live`, `history`
(`limitToLast(288)`), `events` (`limitToLast(30)`) and `config`, and puts the results in `StateFlow`s.
The Compose screens collect these flows and **redraw automatically** when the plant sends new data.
"Play" writes `command/play`, and "Mute" writes `config/muted`.

## 7.4 Notes

* `PLANT_ID` in `Model.kt` must match the firmware (`plant01`).
* This app code was written for this project, but it **could not be compiled in the environment where it was
  written** (the Android SDK download was blocked there). Build it in Android Studio. If Studio asks to update the
  Android Gradle Plugin or Kotlin version, accept it: the code uses only standard, stable APIs.
* Possible extensions: push notifications when the plant is thirsty (Firebase Cloud Messaging + Cloud Functions;
  needs the paid "Blaze" plan, so it is listed as future work), a home-screen widget, and a settings screen like the web.
