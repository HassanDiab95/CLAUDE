# 02 · Hardware Components (Bill of Materials)

The project focuses on the **main idea**: a smart-farming system that shows the feelings of each crop with **emoji** and **sound**. This list is for **one sensor device**, which can be moved from crop to crop; add one set (items 1–11) per extra device. It is powered
by a simple **5 V USB power bank** (or a USB phone charger) connected to the ESP32's USB port, so no solar panel,
battery charger or voltage converter is needed.

## 2.1 Bill of materials

Prices are **approximate** (SAR) and depend on the shop. Buy 1 spare sensor in case one is damaged.

| # | Component | Exact model / spec to ask for | Qty | Purpose | ≈ SAR |
|---|---|---|---|---|---|
| 1 | Microcontroller | **ESP32 DevKit V1** (ESP-WROOM-32, 30 or 38 pin) | 1 | Brain + Wi-Fi | 35–55 |
| 2 | USB cable | Micro-USB or USB-C **data** cable (to match the board) | 1 | Programming + power | 10 |
| 3 | Soil moisture sensor | **Capacitive** soil moisture sensor **v1.2** (analog). *Not* the resistive fork type; it rusts | 1 (+1 spare) | Soil water % | 10–20 |
| 4 | Light sensor | **BH1750** (GY-302) I2C module | 1 | Light in lux | 10–20 |
| 5 | Temperature + humidity | **DHT22 / AM2302** module (3 pins) | 1 | Air temp + humidity | 20–35 |
| 6 | Buzzer | **Passive buzzer** (module KY-006 or bare 12 mm passive buzzer) | 1 | Sound alerts (melodies) | 3–8 |
| 7 | Resistor | 100 Ω (for the buzzer) (+10 kΩ only if the DHT22 is a bare 4-pin sensor) | 1–2 | Protection | 1 |
| 8 | Push button | 6 × 6 mm tactile button | 1 | Play the mood melody | 1–3 |
| 9 | Breadboard + wires | 830-point breadboard, jumper wires M-M and F-M | 1 set | Connections | 20–35 |
| 10 | Power | **5 V USB power bank** (5,000–10,000 mAh) **or** a 5 V USB phone charger | 1 | Power | 0–60 |
| 11 | Enclosure | Small plastic box (≈ 100 × 70 × 40 mm) with holes for the buzzer and the USB cable, or a 3D-printed case | 1 | Protection | 10–30 |
| 12 | Crop to test with | A pot or small planting (strawberry, mint, tomato…) | 1 | 🌿 | 15–30 |
| | | | | **Total (approx.)** | **≈ 135 – 305** |

> **Passive vs active buzzer:** buy a **passive** buzzer. It can play different notes, so it can play melodies.
> An *active* buzzer only makes one fixed "beep". The passive one usually has no sticker on top, and its bottom shows
> the green circuit board.

## 2.2 Why each component

* **ESP32:** it has built-in Wi-Fi to send data to the server (MySQL), an ADC to read the analog soil sensor, and PWM to play
  notes on the buzzer. It is cheap and programmed with the Arduino IDE. (The ESP8266 has only one analog pin and less
  memory for secure HTTPS, so the ESP32 is the better choice.)
* **Capacitive soil sensor:** it has no exposed metal in the soil, so it does not corrode like cheap resistive sensors.
* **BH1750:** it gives real **lux** values, which are better than an LDR for deciding "needs light".
* **DHT22:** it is more accurate than the DHT11 (±0.5 °C) and has a wider range. That is useful in Saudi summers.
* **Passive buzzer:** this is the "voice" of the crop. Each mood has its own melody (sad melody when thirsty,
  happy melody when watered, alarm when hot, lullaby at night…). It costs a few riyals and needs only one wire.

## 2.3 Power consumption

| Part | Current @ 5 V (average) |
|---|---|
| ESP32 with Wi-Fi connected | ≈ 70 mA |
| ESP32 board (regulator, USB chip, LED) | ≈ 10 mA |
| Sensors (soil + DHT22 + BH1750) | ≈ 7 mA |
| Buzzer (only while playing, a few seconds) | ≈ 1 mA average |
| **Total** | **≈ 88 mA ≈ 0.45 W** |

* A **10,000 mAh power bank** stores ≈ 37 Wh. With ≈ 85 % conversion efficiency, that gives about 31 Wh ÷ 0.5 W ≈
  **60 hours (≈ 2.5 days)**. A 5,000 mAh bank lasts about 1 day.
* For permanent use, plug the ESP32 into any **5 V USB phone charger**.
* ⚠️ Some power banks **turn off automatically** when the current is low (less than ~100 mA). If yours turns off
  after a few seconds, use another one (many have a "low-current / always-on" mode), or use a phone charger.

## 2.4 Optional extras (if time allows)

* **Multimeter**, useful for checking connections.
* **DFPlayer Mini MP3 module + speaker**, to play *recorded spoken sentences* ("I'm thirsty!") instead of melodies.
  This is listed as future work in [10](10-report-outline.md).
* **Water pump + relay** for automatic watering (future work).
