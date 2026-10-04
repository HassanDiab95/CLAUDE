# 01 · Requirements and System Analysis

## 1.1 Project idea (from the proposal)

An interactive plant that **expresses its feelings with emoji and sound** using **Internet of Things (IoT)**
technology. The plant's live readings (**soil moisture, light and temperature**) become digital
**facial expressions (emoji)** and **sound alerts (melodies)**.

> **Scope decision:** to focus on the main idea, the solar energy part of the original proposal is replaced by a
> simple **5 V USB power bank / charger**, and the sound is made by a **buzzer** that plays a different melody for each
> mood. (Update the proposal text with your supervisor if needed. Solar power is listed as future work.)

**Importance**

* **Keeps plants alive:** it watches watering and soil moisture so the plant never reaches drought or death.
* **Environmental awareness and smart interaction:** a fun, innovative way to "talk" with plants through IoT,
  emoji and sound alerts.
* **Learning value:** it combines sensors, embedded programming, cloud databases, web and mobile development in one system.

**Duration:** 6 weeks. **Team:** 6 members.

## 1.2 Objectives

1. Measure soil moisture, light intensity, air temperature and humidity automatically.
2. Show the plant's state as an **animated emoji face** on a display next to the plant.
3. Play **sound alerts**: a different buzzer melody for each mood (sad melody when thirsty, happy melody after watering…).
4. Send the data to the **cloud** (Firebase) and show it on a **web dashboard** and an **Android app**.
5. Run from a simple **5 V USB power bank** (portable) or a USB charger.
6. Let the user change the plant thresholds, mute the sound, and play a sound on the plant from the apps.

## 1.3 Why the ESP32 (and not the ESP8266)

| Need of this project | ESP32 | ESP8266 |
|---|---|---|
| Analog input for the soil sensor | ✅ 18 ADC channels (12-bit) | ⚠️ only **1** ADC pin (10-bit, 0–1 V on some boards) |
| HTTPS (Firebase) memory | ✅ 520 KB RAM | ⚠️ 80 KB, often unstable with TLS |
| PWM for buzzer melodies, I2C, many GPIO | ✅ plenty | ⚠️ few free pins |
| Dual-core CPU (smooth face animation + Wi-Fi) | ✅ 240 MHz × 2 | ❌ single core 80 MHz |
| Price | ~ same | ~ same |

➡️ **Use the ESP32 DevKit V1 (ESP-WROOM-32).**

## 1.4 Functional requirements

| ID | Requirement |
|---|---|
| FR-1 | The system shall read soil moisture (%) every 2 seconds. |
| FR-2 | The system shall read light intensity (lux), air temperature (°C) and humidity (%). |
| FR-3 | The system shall decide the plant mood: *happy, thirsty, drowning (too wet), hot, cold, needs light, sleeping*. |
| FR-4 | The system shall display an animated emoji face for the mood on the OLED screen, and a data screen. |
| FR-5 | The system shall play a buzzer melody when the mood changes, and repeat a complaint every 30 min (configurable). |
| FR-6 | The system shall stay silent during quiet hours (default 22:00–07:00) and when muted. |
| FR-7 | The system shall upload the live readings to Firebase every 30 s, a history point every 5 min, and an event on each mood change. |
| FR-8 | The system shall keep showing the face and playing sounds when there is no internet (offline mode). |
| FR-9 | The system shall report its Wi-Fi signal strength and online/offline status. |
| FR-10 | The web and Android apps shall require a login (email + password). |
| FR-11 | The apps shall show the emoji mood, all live values, online/offline status, last-update time. |
| FR-12 | The apps shall show a 24-hour history chart and the "plant diary" (list of mood changes). |
| FR-13 | The apps shall let the user play a chosen melody on the plant ("Play") and mute it. |
| FR-14 | The web app shall let the user edit thresholds (moisture, temperature, light) and quiet hours. |
| FR-15 | The apps shall support Arabic and English. |
| FR-16 | A push button on the plant: short press = change screen, long press = play the current mood's melody. |

## 1.5 Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-1 | **Availability:** the face and sounds must work even without Wi-Fi/internet (local decision on the ESP32). |
| NFR-2 | **Energy:** low consumption (≈ 0.5 W); ≥ 2 days on a 10,000 mAh power bank. |
| NFR-3 | **Security:** only signed-in users can read or write the database (Firebase rules). Passwords are never stored in the apps. |
| NFR-4 | **Performance:** live data appears in the apps less than 35 s after a change. |
| NFR-5 | **Usability:** the apps are simple, bilingual, and work on phones (responsive design). |
| NFR-6 | **Cost:** total hardware cost around 150–340 SAR. |
| NFR-7 | **Maintainability:** clear modular code, configuration in one file (`config.h`). |
| NFR-8 | **Safety:** only safe low voltage (5 V USB). The electronics are protected from water in a box. |

## 1.6 Hardware requirements (summary; details in [02](02-hardware-bom.md))

ESP32 DevKit V1 · capacitive soil moisture sensor v1.2 · BH1750 light sensor · DHT22 temperature/humidity
sensor · 0.96" OLED SSD1306 (I2C) · passive buzzer + 100 Ω resistor · push button · breadboard + wires ·
5 V USB power bank (or USB charger) · small enclosure.

## 1.7 Software requirements

| Part | Tool / technology |
|---|---|
| Firmware | Arduino IDE 2.x + "esp32 by Espressif" core 3.x, C++ |
| Arduino libraries | Adafruit SSD1306, Adafruit GFX, DHT sensor library, Adafruit Unified Sensor, BH1750 (Christopher Laws), ArduinoJson 7 |
| Cloud / database | **Firebase**: Realtime Database, Authentication (email/password), Hosting |
| Web app | HTML5, CSS3, JavaScript (ES modules), Firebase JS SDK 10, Chart.js 4 |
| Android app | Android Studio (Koala or newer), Kotlin, Jetpack Compose (Material 3), Firebase Android SDK (BoM 33) |
| Tools | Node.js + `firebase-tools` (deploy), Git (optional) |

## 1.8 Users and use cases

```mermaid
flowchart LR
  U((Plant owner / user))
  P((Plant device))
  U --- UC1([Sign in])
  U --- UC2([View live mood and readings])
  U --- UC3([View history chart and diary])
  U --- UC4([Change thresholds / mute])
  U --- UC5([Play a sound on the plant])
  U --- UC6([Water the plant and hear the 'thank you' melody])
  P --- UC7([Read sensors])
  P --- UC8([Show emoji + play melody])
  P --- UC9([Upload data to Firebase])
  P --- UC10([Read settings from the apps])
```

## 1.9 Mood rules (the "brain" of the plant)

Rules are checked **in this order** (the first that matches wins). Thresholds can be changed from the web app.

| Priority | Condition (defaults) | Mood | Face | Melody |
|---|---|---|---|---|
| 1 | soil moisture < 30 % | Thirsty | 😫 | 1: sad "help!" notes (played twice) |
| 2 | soil moisture > 85 % | Too wet (drowning) | 🥴 | 2: fast "bubbling" notes |
| 3 | temperature > 35 °C | Hot | 🥵 | 3: alarm beeps |
| 4 | temperature < 10 °C | Cold | 🥶 | 4: "shivering" trill |
| 5 | night (18:00–06:00) | Sleeping | 😴 | 8: lullaby (once) |
| 6 | day and light < 200 lux | Needs light | 😞 | 5: "where is the sun?" |
| 7 | otherwise | Happy | 😊 | 6: happy arpeggio / 7: joyful "thank you" after watering |

* **Hysteresis:** a problem is "solved" only when the value is better by a margin (5 % moisture, 1 °C, 50 lux).
  This stops the face from flickering around a threshold.
* **Sound:** a melody plays when the mood changes. A complaint repeats every 30 min. The plant is silent during quiet hours or when muted.
  Melody 9 is the start-up "hello".

## 1.10 Context diagram

```mermaid
flowchart TB
  ENV[Environment: soil, sun, air] -->|measurements| SYS[Rayy system]
  PWR[5 V power bank] -->|energy| SYS
  SYS -->|emoji + melodies| USER[User near the plant]
  SYS <-->|live data, history, events, settings| CLOUD[(Firebase)]
  CLOUD <-->|dashboard| REMOTE[Remote user: web / Android]
```
