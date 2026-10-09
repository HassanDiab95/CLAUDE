# 10 · Graduation Report Outline, Presentation and Future Work

## 10.1 Suggested report chapters

1. **Introduction:** the idea, the problem (crops are damaged by forgotten or excessive watering and wrong light/temperature, and water is wasted), smart farming,
   objectives ([01](01-requirements.md) §1.2), importance (from the proposal), scope, and report organization.
2. **Background / literature review:** IoT, microcontrollers (ESP32 vs ESP8266 vs Arduino UNO), sensors (capacitive vs
   resistive soil sensors, BH1750 vs LDR, DHT22 vs DHT11), databases and servers (MySQL / XAMPP vs cloud platforms like Firebase, [04](04-database-mysql-xampp.md) §4.1),
   buzzers and PWM sound, and similar existing products (smart pots, farm monitoring systems).
3. **System analysis:** functional and non-functional requirements, use-case diagram, context diagram, mood rules
   ([01](01-requirements.md)).
4. **System design:**
   * block diagram / architecture (README)
   * hardware design: component selection ([02](02-hardware-bom.md)), wiring diagram + pin table ([03](03-wiring.md)),
     power consumption ([02](02-hardware-bom.md) §2.3)
   * software design: firmware flowchart ([05](05-firmware.md) §5.4), database: ERD, relational model, normalization and the real MySQL tables ([04](04-database-mysql-xampp.md) §4.2), the PHP API (§4.3),
     security rules, user-interface designs (web + Android screenshots)
5. **Implementation:** photos of each step, important code snippets (mood engine, ESP32 HTTP request, PHP API with prepared statements, SQL queries),
   web and Android implementation, enclosure.
6. **Testing and results:** the test plan with results ([08](08-testing-calibration.md)), calibration tables,
   24-hour charts (moisture, temperature, light), power-bank running time, screenshots.
7. **Conclusion and future work.**
8. **References** and **appendices** (full code, BOM with prices, user manual).

## 10.2 Presentation and demo tips

* Start with the **story**: "Crops can't talk… until now 🌱😊". Show **My crops** with several crops (strawberry, tomato, mint).
* **Live demo:** pull out the soil sensor → the device plays its sad "thirsty" melody and the emoji changes on the web
  dashboard and the phone at the same time → water it → the joyful "thank you" melody 😊. This is the most impressive moment.
* Press **"Play"** from the phone in front of the committee: the device plays the melody.
* **Move the device** from the strawberry crop to the cactus crop in the app: with the same dry soil the emoji changes from 😫 to 😊, because each crop has its own ideal values.
* Create a new account from the phone, and show the admin **Users** page.
* Show the **history chart** of a full day (prepare it the day before) to show how the soil dries over time.
* Bring a **backup video** of the demo and a **charged power bank**. Use a **phone hotspot**.

## 10.3 Future work

* 💦 **Automatic watering:** a small 5 V pump + relay/MOSFET when a crop is thirsty (one valve per crop), with a water-tank level sensor.
* 🔔 **Push notifications** on the phone (e.g. Firebase Cloud Messaging, or a PHP script that sends e-mail / Telegram messages).
* 🌈 **A small screen on the device** (e.g. colour TFT ST7789) to show the emoji next to the crop too.
* 🧠 **AI:** predict when each crop will need water from the history, or detect plant diseases with a camera (ESP32-CAM).
* 🗣️ **Spoken sentences** instead of melodies with a DFPlayer Mini MP3 module + speaker (recorded voice: "I'm thirsty!"),
  and voice commands with a microphone.
* ☀️ **Solar power:** solar panel + Li-ion battery + charger so each device is fully independent in the field and eco-friendly.
* 🔐 HTTPS hosting, sharing a crop with other users (family / farm workers), e-mail password reset.
* 🔋 A custom PCB and a 3D-printed pot with the electronics built in.
* 🌍 Several devices per crop (large fields), a map of the farm, and reports per season.
