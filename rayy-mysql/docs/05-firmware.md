# 05 · ESP32 Firmware

Code: [`firmware/Rayy/`](../firmware/Rayy). It was compiled successfully for **ESP32 Dev Module** with
esp32 core 3.0.7 (≈ 84 % flash, 14 % RAM, no warnings).

## 5.1 Install the tools

1. Install **Arduino IDE 2.x**: <https://www.arduino.cc/en/software>.
2. USB driver if the board is not detected: **CP210x** (Silicon Labs) or **CH340**, depending on the chip near the USB port.
3. **File → Preferences → Additional boards manager URLs**, paste:
   `https://espressif.github.io/arduino-esp32/package_esp32_index.json`
4. **Tools → Board → Boards Manager** → search **esp32** → install **"esp32 by Espressif Systems"** (version **3.x**).
5. **Tools → Manage Libraries** → install:

| Library (search name) | Author |
|---|---|
| DHT sensor library | Adafruit (accept "install all": Adafruit Unified Sensor) |
| BH1750 | Christopher Laws |
| ArduinoJson | Benoit Blanchon (version **7.x**) |

> The code uses the esp32 core **3.x** buzzer functions (`ledcAttach`, `ledcWriteTone`). With the old core 2.x the
> compile fails, so update the core in the Boards Manager.

## 5.2 Configure and upload

1. Open `firmware/Rayy/Rayy.ino` (the other files open as tabs).
2. Edit **`config.h`**: Wi-Fi name/password, **`SERVER_URL`** = `http://<IP of the XAMPP computer>/rayy/api`
   (no `/` at the end, never `localhost`), **`DEVICE_KEY`** (same as in `database/rayy.sql`), and **`DEVICE_ID`** (`rayy-01`). The crop is chosen in the apps, not in the code.
3. **Tools → Board → esp32 → ESP32 Dev Module**, **Port** = the COM port of the board.
4. Click **Upload (→)**. If you see `Failed to connect… Timed out waiting for packet header`, **hold the BOOT
   button** on the ESP32 until "Connecting…" turns into "Writing…".
5. **Tools → Serial Monitor** at **115200 baud** shows:
```
=== Rayy (ري) smart farming: device rayy-01 ===
[sound] melody 9
[wifi] 192.168.1.23
[server] connected to http://192.168.1.10/rayy/api
soil=46% (raw 2190)  temp=27.4C  hum=38%  lux=5400  mood=happy  wifi=1 server=1
[mood] happy -> thirsty
[sound] melody 1
```
Note: the ESP32 supports **2.4 GHz Wi-Fi only**. A phone hotspot works well for demos.

After uploading, unplug the USB cable from the computer and plug the ESP32 into the **power bank**. The program
starts by itself.

## 5.3 Code structure

| File | Responsibility |
|---|---|
| `Rayy.ino` | Main program: `setup()`, `loop()`, timing, button |
| `config.h` | **All settings** (Wi-Fi, server address, device key, intervals, soil calibration, time zone) |
| `pins.h` | Pin map |
| `mood.h / mood.cpp` | The crop "brain": readings → mood, and which melody to play (pure C++, unit-tested) |
| `sensors.h / .cpp` | Soil (ADC + calibration), DHT22, BH1750 |
| `status.h` | The current state of the measured crop (readings, mood, Wi-Fi/cloud, mute) shared with the server upload |
| `sound.h / .cpp` | Buzzer: 9 melodies played **in the background** (non-blocking), so the face keeps moving |
| `cloud.h / .cpp` | Wi-Fi reconnect, clock (NTP or server hour), one HTTP request to `api/device.php`: upload live/history/events, receive settings + "Play" command |

## 5.4 Program flow

```mermaid
flowchart TD
  A[Power on] --> B[Init sensors, buzzer]
  B --> C[Play 'hello' melody]
  C --> D[Connect Wi-Fi + NTP clock]
  D --> L[loop]
  L --> S{2 s passed?}
  S -- yes --> R[Read sensors → evaluate mood]
  R --> V{Mood changed or<br/>complaint repeat due?}
  V -- yes, not muted / quiet hours --> P[Start melody]
  V -- no --> U
  P --> U{30 s passed?}
  S -- no --> U
  U -- yes --> F[POST api/device.php: live + event + history every 5 min<br/>answer: settings + Play command]
  U -- no --> O
  F --> O[Update melody<br/>handle button]
  O --> L
```

## 5.5 The sound alerts (buzzer melodies)

A **passive buzzer** plays a note when the ESP32 sends it a square wave with the note's frequency (PWM).
`sound.cpp` contains each melody as a list of *(frequency, duration)* notes, for example the "thank you" melody:
`G5 120 ms, C6 120 ms, E6 120 ms, G6 200 ms, …`. The `soundLoop()` function moves to the next note when the time of the
current note is over, so the melody plays **without stopping** the face animation or the sensors.

| # | Melody | When |
|---|---|---|
| 1 | Sad "help!" (played twice) | Thirsty 😫 |
| 2 | Fast bubbling notes | Too wet 🥴 |
| 3 | Alarm beeps | Hot 🥵 |
| 4 | Shivering trill | Cold 🥶 |
| 5 | Rising notes then a low note ("where is the sun?") | Needs light 😞 |
| 6 | Happy arpeggio | Becomes happy 😊 |
| 7 | Joyful "thank you" | Happy **after watering** |
| 8 | Slow lullaby | Night starts 😴 |
| 9 | Short "hello" | Power on |

You can compose your own melodies by changing the notes in `sound.cpp`.

## 5.6 How the server connection works (HTTP + PHP + MySQL)

The firmware uses **plain HTTP requests** (`HTTPClient` + `ArduinoJson`) to the PHP API on the XAMPP computer.
Every 30 s it makes **one** request that does everything:

1. `POST {SERVER_URL}/device.php?device=rayy-01` with the header **`X-Device-Key`** and a JSON body: the live values,
   `"history": true` every 5 minutes, and `"event": {...}` when the mood changed.
2. The PHP code saves them in MySQL (tables `live_status`, `readings`, `mood_events`).
3. The answer says **which crop the device is assigned to now**, with that crop's **thresholds** (`crops` table), the next **"Play"** melody (`play_commands`
   table, 0 = none) and the **server hour**.
4. The ESP32 applies the settings, plays the melody, and uses the server hour as its clock if the Wi-Fi has no
   internet (no NTP time), so "night" still works on a local network.

If the request fails (Apache stopped, wrong IP), the device keeps working alone (moods + melodies), the blue LED
blinks, and the diary event / history point is sent again with the next request.

### Moving the device to another crop

The firmware does not know crop names or crop IDs. When the user moves the device in the apps
(`device_assign.php`), the next answer of `device.php` names the new crop and brings its thresholds. The Serial
Monitor prints `[server] measuring crop 2: نعناع الحديقة`, and from then on the moods are decided with the new crop's
values (e.g. a cactus is happy in dry soil, a strawberry is thirsty). If the device is not assigned to any crop, it
prints `not assigned to a crop yet` and keeps its last thresholds.

## 5.7 The emoji faces (in the apps, not on the device)

The project has **no screen**. The ESP32 sends the mood name (`happy`, `thirsty`, …) to the server (MySQL) and the **web dashboard**
and **Android app** show the matching emoji: 😊 happy · 😫 thirsty · 🥴 too wet · 🥵 hot · 🥶 cold · 😞 needs light · 😴 sleeping.
On the device itself, the mood is expressed by the **melody** of the buzzer. A press on the push button plays the current mood's melody.

## 5.8 Changing behaviour

* **Thresholds, quiet hours, mute:** from the web app (no re-upload needed). The ESP32 reads them every 30 s.
* **Intervals, soil calibration:** `config.h`.
* **Add a new mood:** add it to `enum Mood`, `evaluateMood()`, `moodName()`, a melody in
  `sound.cpp`, and the texts in the apps.

## 5.9 Unit tests of the mood logic (on a PC)

```bash
cd tests
g++ -std=c++17 -I../firmware/Rayy test_mood.cpp ../firmware/Rayy/mood.cpp -o test_mood
./test_mood          # → "33 checks, 0 failures"
```
