# 🌱 ري (Rayy): smart farming that shows the feelings of your crops (MySQL + XAMPP version)

> **Graduation project.** **ري (Rayy, "watering / quenching thirst")** is a smart-farming system. One account manages
> **many crops (زراعات)**: a strawberry field, tomatoes, mint, palm seedlings… A sensor device placed in a crop turns
> its live readings (**soil moisture, light and temperature**) into **emoji faces** in the **web dashboard** and the
> **Android app**, and **sound alerts** (a different buzzer melody for each feeling).
>
> * Every crop has a **crop type** with its ideal values (12 types included).
> * The sensor device can be **moved from one crop to another** from the apps.
> * Anyone can **create an account**; the **admin** manages users.
> * The data is stored in **MySQL** on a computer running **XAMPP** (Apache + PHP + MySQL). The device is powered by a
>   **5 V USB power bank**.

| 😊 Happy | 😫 Thirsty | 🥴 Too wet | 🥵 Too hot | 🥶 Cold | 😞 Needs light | 😴 Sleeping |
|---|---|---|---|---|---|---|

---

## 1. Start here

👉 **[docs/00-step-by-step-guide.md](docs/00-step-by-step-guide.md)**: the complete guide from buying the parts to the
final demo, step by step.

🗄️ **[docs/04-database-mysql-xampp.md](docs/04-database-mysql-xampp.md)**: XAMPP, the MySQL tables, the PHP API,
security and useful SQL.

📄 **[docs/Rayy-Documentation-MySQL.docx](docs/Rayy-Documentation-MySQL.docx)**: all the documentation in one Word file.

📝 **[docs/forms/](docs/forms)**: the college forms filled in for this version: نموذج (1) مقترح المشروع، نموذج (2) خطة المشروع (use cases, class diagram, ERD, relational model, normalization, wiring, prototype), نموذج (3) تسليم المشروع.

## 2. What is in this folder

| Folder / file | What it contains | Where it goes |
|---|---|---|
| [`database/rayy.sql`](database/rayy.sql) | Creates the MySQL database `rayy`: 12 tables, crop library, admin user, device `rayy-01` | phpMyAdmin → Import |
| [`server/rayy/`](server/rayy) | Web dashboard (HTML/CSS/JS) + **PHP API** (`api/`) | Copy to `C:\xampp\htdocs\rayy` |
| [`firmware/Rayy/`](firmware/Rayy) | ESP32 program (Arduino IDE): sensors, moods, buzzer melodies, HTTP to the API | Upload to the ESP32 |
| [`android/Rayy/`](android/Rayy) | Android Studio project **Rayy** (Kotlin + Jetpack Compose, Arabic / English) | Build in Android Studio |
| [`tests/`](tests) | Unit tests of the "mood" logic (PC) + automatic test of the PHP API (`test_api.sh`, 44 checks) | — |
| [`docs/`](docs) | Full documentation (chapters 00 → 10 + Word file + diagrams) | — |

## 3. Documentation index

0. [Step-by-step guide (start here)](docs/00-step-by-step-guide.md)
1. [Requirements and system analysis](docs/01-requirements.md)
2. [Hardware components (bill of materials) and power](docs/02-hardware-bom.md)
3. [Wiring and assembly](docs/03-wiring.md)
4. [Database: MySQL with XAMPP, the PHP API and the setup](docs/04-database-mysql-xampp.md)
5. [ESP32 firmware: installation, how the code works, the melodies](docs/05-firmware.md)
6. [Web application](docs/06-web-app.md)
7. [Android application](docs/07-android-app.md)
8. [Calibration and testing](docs/08-testing-calibration.md)
9. [6-week project plan and team roles](docs/09-project-plan.md)
10. [Graduation report outline, presentation and future work](docs/10-report-outline.md)

## 4. System architecture

```mermaid
flowchart LR
  subgraph Plant["📡 Sensor device rayy-01"]
    S1[Soil moisture sensor] --> ESP
    S2[BH1750 light sensor] --> ESP
    S3[DHT22 temperature + humidity] --> ESP
    ESP --> BZ[Buzzer melodies 🔊]
    PB[🔋 5 V USB power bank] --> ESP
    ESP -. "placed in one crop,<br/>movable" .- CROP[🍓 Crop]
  end
  subgraph PC["💻 Computer with XAMPP"]
    API[PHP API<br/>Apache] <--> DB[(MySQL<br/>database rayy)]
  end
  ESP <-- "Wi-Fi / HTTP + JSON<br/>every 30 s" --> API
  API <-- "every 5 s" --> WEB[💻 Web dashboard]
  API <-- "every 5 s" --> APP[📱 Android app]
```

* The user adds crops in the apps; each crop gets the ideal values of its **crop type**.
* The **ESP32** device is placed in one crop and chosen in the apps. It reads the sensors every 2 s, chooses the
  crop's mood **with that crop's thresholds** and plays its melody. There is **no screen on the device**: the emoji
  is shown in the apps. Without the server the device still decides the mood and plays its melodies.
* Every 30 s it sends **one HTTP request** to `api/device.php`: the live values, a **history** point every 5 min and an
  **event** when the mood changes, all saved for **the crop it is on now**. The answer brings back that crop's
  **thresholds** and any **"Play"** request. Moving the device to another crop in the app takes effect within 30 s.
* The **web** and **Android** apps: create account / sign in, **My crops**, crop page (live values, chart, diary,
  settings, device), **Devices** (move a device), and **Users** for the admin. They ask for new data every 5–10 s.
* The XAMPP computer, the ESP32 and the phone must be on the **same Wi-Fi**; **no internet is required**.

## 5. Quick start (summary)

1. Buy the parts ([docs/02](docs/02-hardware-bom.md)) and wire them ([docs/03](docs/03-wiring.md)).
2. Install **XAMPP**, start **Apache** and **MySQL**, copy `server/rayy` to `C:\xampp\htdocs\`, and import
   `database/rayy.sql` in <http://localhost/phpmyadmin> ([docs/04](docs/04-database-mysql-xampp.md)).
3. Find the computer's IP (`ipconfig`, e.g. `192.168.1.10`).
4. Edit `firmware/Rayy/config.h` (Wi-Fi, `SERVER_URL = "http://192.168.1.10/rayy/api"`, `DEVICE_ID`, `DEVICE_KEY`) and
   upload it with the Arduino IDE ([docs/05](docs/05-firmware.md)).
5. Open `http://192.168.1.10/rayy/`, sign in with **`admin@rayy.app` / `Rayy@2026`** (or create an account), add your
   crops and **move the device** to the crop where it is placed ([docs/06](docs/06-web-app.md)).
6. Set `SERVER_URL` in `android/Rayy/app/src/main/java/com/rayy/app/Model.kt`, open `android/Rayy/` in Android
   Studio and press ▶ ([docs/07](docs/07-android-app.md)).
7. Calibrate the soil sensor and run the tests ([docs/08](docs/08-testing-calibration.md)).

> 💡 **See the dashboard without any hardware:** open `server/rayy/index.html` directly in the browser (demo data),
> or send fake readings with the `curl` command in [docs/04](docs/04-database-mysql-xampp.md) §4.4.
