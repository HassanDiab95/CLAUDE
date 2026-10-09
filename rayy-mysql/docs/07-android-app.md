# 07 · Android Application

Code: [`android/Rayy/`](../android/Rayy), a **native Android app** in **Kotlin + Jetpack Compose (Material 3)**
that talks to the **PHP API on the XAMPP computer** (MySQL database) with plain HTTP + JSON.
It needs **no extra library** for the server: it uses `HttpURLConnection` and `org.json`, which are built into Android.
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

* **Android Studio Panda (2025.3.1) or newer**: <https://developer.android.com/studio>. It includes the JDK and Android SDK.
  The project uses **Gradle 9.1.0 + Android Gradle Plugin 9.0.1 + Kotlin 2.2.21**, which run on **Java 17 up to Java 25**,
  so the Java that comes with a recent Android Studio works without changing any setting.
* The XAMPP computer running (Apache + MySQL) and the phone in the **same Wi-Fi** ([04](04-database-mysql-xampp.md)).

## 7.2 Open, build and run

> ⚠️ **Folder path: English letters only.** Put the project in a folder whose full path has **no Arabic letters**,
> for example `E:\Rayy-Project\android\Rayy`. A path like `E:\Ray ري\...` gives the error
> *"Your project path contains non-ASCII characters"*. The project includes `android.overridePathCheck=true`
> in `gradle.properties` to skip this check, but other build tools can still fail on such paths, so moving the
> folder is the safe fix.

1. Open **`app/src/main/java/com/rayy/app/Model.kt`** and set the address of the XAMPP computer:
   ```kotlin
   const val SERVER_URL = "http://192.168.1.10/rayy/api"   // the computer's IPv4 address (cmd → ipconfig)
   ```
   For the Android **emulator** running on the same computer use `http://10.0.2.2/rayy/api`.
2. Android Studio → **File → Open** → select the **`android/Rayy`** folder (Android Studio shows the project name **Rayy**) → wait for "Gradle sync" to finish
   (the first time it downloads Gradle 9.1.0 and the libraries, so an internet connection is required).
3. Connect a phone with **USB debugging** enabled (Settings → About phone → tap "Build number" 7 times →
   Developer options → USB debugging), or create an emulator (Device Manager).
4. Press **▶ Run**. Sign in with `team@rayy.app` / `Rayy@2026` (from `database/rayy.sql`).

**Make an APK to install on any phone:** **Build → Build App Bundle(s) / APK(s) → Build APK(s)** →
`android/Rayy/app/build/outputs/apk/debug/app-debug.apk`. Send it to the phone and install it ("allow unknown sources").

> **"The project is using an incompatible version of the Android Gradle plugin"**: your Android Studio is older than
> Panda (2025.3.1). Update Android Studio (**Help → Check for Updates**).

> **"Server not reachable"** on the login screen: check `SERVER_URL` in `Model.kt`, that the phone is in the same Wi-Fi,
> that Apache is green in XAMPP, and that `http://192.168.1.10/rayy/` opens in the phone's browser.
> The app uses `http://` (not https) on the local network; `android:usesCleartextTraffic="true"` in the manifest allows it.

## 7.3 Code structure

```
android/Rayy/                 ← open this folder in Android Studio (project "Rayy")
├── settings.gradle.kts, build.gradle.kts, gradle.properties, gradlew   (Gradle 9.1.0, AGP 9.0.1, Kotlin 2.2.21)
└── app/
    ├── build.gradle.kts                 dependencies: Compose BoM 2024.09.00, coroutines 1.8.1
    └── src/main/
        ├── AndroidManifest.xml          INTERNET permission + cleartext HTTP for the local server
        ├── java/com/rayy/app/
        │   ├── MainActivity.kt          shows Login or Main screen
        │   ├── PlantViewModel.kt        login + polling of the API every 5 s (StateFlow)
        │   ├── ApiClient.kt             HTTP + JSON calls to the PHP API (token header)
        │   ├── Model.kt                 SERVER_URL + PLANT_ID + data classes + JSON parsing
        │   └── ui/
        │       ├── LoginScreen.kt
        │       ├── MainScreen.kt        bottom navigation: Plant / History / Diary
        │       ├── LineChart.kt         small chart drawn with Canvas
        │       ├── Moods.kt             mood → emoji + texts, time format
        │       └── Theme.kt             green Material 3 theme (light / dark)
        └── res/values/strings.xml (English) · res/values-ar/strings.xml (Arabic)
```

**How it works:** `PlantViewModel` signs in with `api/login.php` and keeps the token (SharedPreferences, so the app
stays signed in). Then it **polls** the API with coroutines: `live.php` every 5 s, `events.php` every 15 s and
`history.php` every 5 min, and puts the results in `StateFlow`s. The Compose screens collect these flows and
**redraw automatically**. "Play" calls `command.php`, and "Mute" calls `settings.php`. If the token expires (HTTP 401),
the app goes back to the login screen.

## 7.4 Notes

* `PLANT_ID` in `Model.kt` must match the firmware (`plant01`).
* The network code (`ApiClient`, `Model`) was compiled and **tested against the real PHP API + MySQL** while
  writing this project. The full Android build (Compose screens) could not run in that environment (Android SDK
  download blocked), so build it in Android Studio. If Studio asks to update the Android Gradle Plugin or Kotlin
  version, accept it: the code uses only standard, stable APIs.
* Possible extensions: notifications when the plant is thirsty (WorkManager checking `live.php`), a home-screen
  widget, and a settings screen like the web.
