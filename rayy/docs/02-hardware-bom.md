# 02 · Hardware Components (Bill of Materials)

The project has two parts: the **main part** (a plant that shows its feelings with **emoji** and **sound**) and the
**solar part** (a solar panel and a rechargeable battery that power it). The solar components are listed
**separately** in 2.2 so they can be bought and tested as a separate step. A 5 V USB power bank can power the main
part alone while you build and test it.

## 2.1 Main part: bill of materials

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
| 10 | Test power | **5 V USB power bank** **or** a 5 V USB phone charger (for building and testing indoors; you probably already have one) | 1 | Power while testing | 0–60 |
| 11 | Enclosure | Plastic box (≈ 150 × 100 × 60 mm, room for the batteries) with holes for the buzzer, the sensor wires and the panel cable | 1 | Protection | 15–35 |
| 12 | Plant | Small potted plant (basil, mint, pothos…) | 1 | 🌿 | 15–30 |
| | | | | **Main part total (approx.)** | **≈ 140 – 317** |

## 2.2 Solar part: bill of materials (separate)

| # | Component | Exact model / spec to ask for | Qty | Purpose | ≈ SAR |
|---|---|---|---|---|---|
| S1 | Solar panel | **6 V, 6 W** monocrystalline mini panel (≈ 1 A) | 1 | Produces the energy | 35–50 |
| S2 | Solar charger | **CN3791 MPPT** Li-ion solar charger module, **6 V** version | 1 | Charges the battery safely | 15–25 |
| S3 | Battery | **18650 Li-ion 3.7 V 3000 mAh, protected** (same model) | 2 | Stores energy for the night | 40–60 |
| S4 | Battery holder | **2 × 18650** holder, **parallel** (3.7 V output) | 1 | Holds the batteries | 8–12 |
| S5 | Boost converter | **MT3608** DC-DC step-up module (set to 5.1 V) | 1 | 3.7 V → 5 V for the ESP32 | 8–12 |
| S6 | Resistors | **100 kΩ** ¼ W | 5 | Voltage dividers (battery ÷ 2, panel ÷ 3) | 2–5 |
| S7 | Switch | ON/OFF rocker or slide switch | 1 | Turns the plant off | 3–5 |
| S8 | Connectors + wire | JST-PH 2-pin connectors + 22 AWG red/black wire | 1 set | Power connections | 10–15 |
| | | | | **Solar part total (approx.)** | **≈ 121 – 184** |

**Whole project (main + solar): ≈ 261 – 501 SAR.** Wiring, calculations and safety: [11 · Solar power](11-solar-power.md).

> **Passive vs active buzzer:** buy a **passive** buzzer. It can play different notes, so it can play melodies.
> An *active* buzzer only makes one fixed "beep". The passive one usually has no sticker on top, and its bottom shows
> the green circuit board.

## 2.3 Why each component

* **ESP32:** it has built-in Wi-Fi to send data to Firebase, an ADC to read the analog soil sensor, and PWM to play
  notes on the buzzer. It is cheap and programmed with the Arduino IDE. (The ESP8266 has only one analog pin and less
  memory for secure HTTPS, so the ESP32 is the better choice.)
* **Capacitive soil sensor:** it has no exposed metal in the soil, so it does not corrode like cheap resistive sensors.
* **BH1750:** it gives real **lux** values, which are better than an LDR for deciding "needs light".
* **DHT22:** it is more accurate than the DHT11 (±0.5 °C) and has a wider range. That is useful in Saudi summers.
* **Passive buzzer:** this is the "voice" of the plant. Each mood has its own melody (sad melody when thirsty,
  happy melody when watered, alarm when hot, lullaby at night…). It costs a few riyals and needs only one wire.
* **Solar panel 6 V 6 W:** in Saudi sun it gives ≈ 23 Wh per day, about twice what Rayy uses (≈ 12 Wh).
* **CN3791 MPPT charger:** made for solar panels: it takes the most power from the panel and charges the Li-ion
  battery with the correct 4.2 V limit (a TP4056 also works but wastes more energy from the panel).
* **2 × 18650 batteries:** ≈ 22 Wh, enough for about 39 hours without any sun.
* **MT3608 boost converter:** the battery gives 3.0–4.2 V; the ESP32 board needs 5 V on its VIN pin.
* **100 kΩ dividers:** the ESP32 pins accept max 3.3 V, so the battery and panel voltages are divided before measuring.

## 2.4 Power consumption

| Part | Current @ 5 V (average) |
|---|---|
| ESP32 with Wi-Fi connected | ≈ 70 mA |
| ESP32 board (regulator, USB chip, LED) | ≈ 10 mA |
| Sensors (soil + DHT22 + BH1750) | ≈ 7 mA |
| Buzzer (only while playing, a few seconds) | ≈ 1 mA average |
| **Total** | **≈ 88 mA ≈ 0.45 W** |

* **Solar:** the 2 × 18650 battery stores ≈ 22 Wh (≈ 19.5 Wh after the boost converter) → **≈ 39 hours** without sun.
  The 6 W panel refills it every sunny day (≈ 23 Wh/day). Full calculation in [11](11-solar-power.md).
* **Testing on a power bank:** a 10,000 mAh power bank stores ≈ 37 Wh → about **60 hours**.
* ⚠️ Some power banks **turn off automatically** when the current is low (less than ~100 mA). If yours turns off
  after a few seconds, use another one (many have a "low-current / always-on" mode), or use a phone charger.

## 2.5 Optional extras (if time allows)

* **Multimeter**: needed for the solar part (to set the boost converter to 5.1 V) and useful for checking connections.
* **DFPlayer Mini MP3 module + speaker**, to play *recorded spoken sentences* ("I'm thirsty!") instead of melodies.
  This is listed as future work in [10](10-report-outline.md).
* **Water pump + relay** for automatic watering (future work).
