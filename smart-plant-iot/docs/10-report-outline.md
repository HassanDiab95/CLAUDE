# 10 · Graduation Report Outline, Presentation and Future Work

## 10.1 Suggested report chapters

1. **Introduction:** the idea, the problem (plants die from forgotten watering and wrong light/temperature),
   objectives ([01](01-requirements.md) §1.2), importance (from the proposal), scope, and report organization.
2. **Background / literature review:** IoT, microcontrollers (ESP32 vs ESP8266 vs Arduino UNO), sensors (capacitive vs
   resistive soil sensors, BH1750 vs LDR, DHT22 vs DHT11), cloud platforms (Firebase vs others, [04](04-firebase-setup.md)),
   solar energy and Li-ion batteries, and similar existing products (smart pots, plant monitors).
3. **System analysis:** functional and non-functional requirements, use-case diagram, context diagram, mood rules
   ([01](01-requirements.md)).
4. **System design:**
   * block diagram / architecture (README)
   * hardware design: component selection ([02](02-hardware-bom.md)), wiring diagram + pin table ([03](03-wiring.md)),
     power budget and solar sizing ([02](02-hardware-bom.md) §2.3)
   * software design: firmware flowchart ([05](05-firmware.md) §5.4), database structure ([04](04-firebase-setup.md) §4.2),
     security rules, user-interface designs (web + Android screenshots)
5. **Implementation:** photos of each step, important code snippets (mood engine, Firebase REST, face drawing),
   web and Android implementation, enclosure.
6. **Testing and results:** the test plan with results ([08](08-testing-calibration.md)), calibration tables,
   24-hour charts (moisture, battery/solar), energy measurements, screenshots.
7. **Conclusion and future work.**
8. **References** and **appendices** (full code, BOM with prices, user manual).

## 10.2 Presentation and demo tips

* Start with the **story**: "Plants can't talk… until now 🌱😊".
* **Live demo:** pull out the soil sensor → the plant shouts "I'm thirsty!" and the face changes on the OLED, the web
  and the phone at the same time → water it → "Thank you!" 😊. This is the most impressive moment.
* Press **"Speak now"** from the phone in front of the committee.
* Show the **history chart** of a full day (prepare it the day before) to prove that the solar system works day and night.
* Bring a **backup video** of the demo and a **charged power bank**. Use a **phone hotspot**.

## 10.3 Future work

* 💦 **Automatic watering:** a small 5 V pump + relay/MOSFET when the plant is thirsty, with a water-tank level sensor.
* 🔔 **Push notifications** on the phone (Firebase Cloud Messaging + Cloud Functions).
* 🌈 **Colour TFT display** (ST7789 240×240) with colourful animated emoji.
* 🧠 **AI:** predict when the plant will need water from the history, or detect plant diseases with a camera (ESP32-CAM).
* 🗣️ Voice commands ("How are you, plant?") with a microphone.
* 🔐 Certificate validation for HTTPS, per-user rules, and multiple plants per user.
* ⚡ An MPPT solar charger (CN3791) for higher efficiency, and a custom PCB.
* 🌍 Multi-plant dashboard for schools / greenhouses.
