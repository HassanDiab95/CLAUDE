# 10 · Graduation Report Outline, Presentation and Future Work

## 10.1 Suggested report chapters

1. **Introduction:** the idea, the problem (plants die from forgotten watering and wrong light/temperature),
   objectives ([01](01-requirements.md) §1.2), importance (from the proposal), scope, and report organization.
2. **Background / literature review:** IoT, microcontrollers (ESP32 vs ESP8266 vs Arduino UNO), sensors (capacitive vs
   resistive soil sensors, BH1750 vs LDR, DHT22 vs DHT11), cloud platforms (Firebase vs others, [04](04-firebase-setup.md)),
   buzzers and PWM sound, and similar existing products (smart pots, plant monitors).
3. **System analysis:** functional and non-functional requirements, use-case diagram, context diagram, mood rules
   ([01](01-requirements.md)).
4. **System design:**
   * block diagram / architecture (README)
   * hardware design: component selection ([02](02-hardware-bom.md)), wiring diagram + pin table ([03](03-wiring.md)),
     power consumption ([02](02-hardware-bom.md) §2.4), **solar power system**: components, energy calculation and
     wiring ([11](11-solar-power.md))
   * software design: firmware flowchart ([05](05-firmware.md) §5.4), database structure ([04](04-firebase-setup.md) §4.2),
     security rules, user-interface designs (web + Android screenshots)
5. **Implementation:** photos of each step, important code snippets (mood engine, Firebase REST, face drawing),
   web and Android implementation, enclosure.
6. **Testing and results:** the test plan with results ([08](08-testing-calibration.md)), calibration tables,
   24-hour charts (moisture, temperature, light, **battery**), solar charging results, screenshots.
7. **Conclusion and future work.**
8. **References** and **appendices** (full code, BOM with prices, user manual).

## 10.2 Presentation and demo tips

* Start with the **story**: "Plants can't talk… until now 🌱😊".
* **Live demo:** pull out the soil sensor → the plant plays its sad "thirsty" melody and the emoji changes on the web
  dashboard and the phone at the same time → water it → the joyful "thank you" melody 😊. This is the most impressive moment.
* Press **"Play"** from the phone in front of the committee: the plant plays the melody.
* Show the **history chart** of a full day (prepare it the day before) to show how the soil dries over time.
* Show the **solar part**: cover the panel with your hand → the apps change from "Charging from the sun ☀️" to "Not charging now".
* Bring a **backup video** of the demo, **charged batteries** and a **power bank** as backup. Use a **phone hotspot**.

## 10.3 Future work

* 💦 **Automatic watering:** a small 5 V pump + relay/MOSFET when the plant is thirsty, with a water-tank level sensor.
* 🔔 **Push notifications** on the phone (Firebase Cloud Messaging + Cloud Functions).
* 🌈 **A small screen on the plant** (e.g. colour TFT ST7789) to show the emoji next to the plant too.
* 🧠 **Artificial intelligence (planned):** predict when the plant will need water from the history, TinyML on the
  ESP32, friendly messages written by generative AI, or plant-disease detection with a camera (ESP32-CAM).
  The project is already prepared for it: full plan in [12 · Future AI](12-future-ai.md).
* 🗣️ **Spoken sentences** instead of melodies with a DFPlayer Mini MP3 module + speaker (recorded voice: "I'm thirsty!"),
  and voice commands with a microphone.
* 🔐 Certificate validation for HTTPS, per-user rules, and multiple plants per user.
* 🔋 A custom PCB and a 3D-printed pot with the electronics built in.
* 🌍 Multi-plant dashboard for schools / greenhouses.
