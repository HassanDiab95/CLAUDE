# 02 · Hardware Components (Bill of Materials) and Power Budget

## 2.1 Bill of materials

Prices are **approximate** (SAR, 2025–2026) and depend on the shop. Buy 1–2 spare sensors in case one is damaged.

| # | Component | Exact model / spec to ask for | Qty | Purpose | ≈ SAR |
|---|---|---|---|---|---|
| 1 | Microcontroller | **ESP32 DevKit V1** (ESP-WROOM-32, 30 or 38 pin, CP2102 or CH340 USB) | 1 | Brain + Wi-Fi | 35–55 |
| 2 | Soil moisture sensor | **Capacitive** soil moisture sensor **v1.2** (analog). *Not* the resistive fork type; it rusts | 1 (+1 spare) | Soil water % | 10–20 |
| 3 | Light sensor | **BH1750** (GY-302) I2C module | 1 | Light in lux | 10–20 |
| 4 | Temperature + humidity | **DHT22 / AM2302** module (3 pins, with pull-up) | 1 | Air temp + humidity | 20–35 |
| 5 | Display | **0.96" OLED SSD1306 128×64, I2C (4 pins)**. A 1.3" SSD1306 or 2.42" SSD1309 I2C also works | 1 | Emoji face | 15–35 |
| 6 | MP3 player | **DFPlayer Mini** (YX5200 / MP3-TF-16P) | 1 | Voice messages | 10–20 |
| 7 | Memory card | micro-SD 1–16 GB, **FAT32** | 1 | Voice MP3 files | 15–25 |
| 8 | Speaker | **3 W, 4 Ω or 8 Ω**, 40–50 mm | 1 | Sound | 10–20 |
| 9 | Solar panel | **6 V, 5–6 W** (≈ 1 A) mono-crystalline, with wires | 1 | Energy | 40–80 |
| 10 | Charger | **TP4056 module with protection** (DW01 + 8205; has B+/B− **and** OUT+/OUT−), USB-C | 1 | Charges battery safely | 5–10 |
| 11 | Battery | **18650 Li-ion 3.7 V, 2600–3500 mAh**, genuine brand (Samsung, LG, Panasonic, Sony) | 2 | Energy storage | 30–60 |
| 12 | Battery holder | 2 × 18650 holder (wire it in **parallel**) or 2 single holders | 1 | — | 5–10 |
| 13 | Boost converter | **MT3608** DC-DC step-up (2 A), set to 5.0 V | 1 | 3.7 V → 5 V | 5–10 |
| 14 | Diode | **1N5819** Schottky (1 A) | 1 | Stops battery draining into panel at night | 1 |
| 15 | Switch | SPDT slide or rocker switch | 1 | Power on/off | 2–5 |
| 16 | Push button | 6 × 6 mm tactile or 12 mm panel button | 1 | Screen / speak | 1–5 |
| 17 | Resistors | 100 kΩ ×3, 47 kΩ ×1, 1 kΩ ×1, (10 kΩ ×1 if DHT22 is a bare 4-pin sensor) | — | Dividers, DFPlayer RX | 2–5 |
| 18 | Capacitors | 100 nF ceramic ×2, 470–1000 µF / 10 V electrolytic ×1 | — | ADC filter, DFPlayer supply | 2–5 |
| 19 | Wiring | Breadboard (testing), jumper wires M-M / M-F, then perfboard / PCB + header pins, soldering kit | — | Connections | 20–40 |
| 20 | Enclosure | Waterproof ABS box (≈ 150 × 100 × 70 mm) with a window for the OLED, or a 3D-printed case; cable glands | 1 | Protection | 15–40 |
| 21 | Plant | Small potted plant (e.g. basil, mint, pothos) | 1 | 🌿 | 15–30 |
| | | | | **Total (approx.)** | **≈ 270 – 520** |

### Optional / nice to have
* **Multimeter** (essential for setting the MT3608 to 5.0 V and calibrating): 30–60 SAR.
* **USB power bank + USB cable**: powers the project during development before the solar part is ready.
* **CN3791 MPPT 6 V solar charger** instead of TP4056: more efficient with solar panels (≈ 25 SAR).
* **Water pump + relay** for automatic watering (see future work in [10](10-report-outline.md)).

## 2.2 Why each component

* **Capacitive soil sensor:** it has no exposed metal in the soil, so it does not corrode like the cheap resistive sensors.
* **BH1750:** it gives real **lux** values, which are better than an LDR for deciding "needs light". It shares the I2C bus with the OLED.
* **DHT22:** it is more accurate than the DHT11 (±0.5 °C) and has a wider range (−40…80 °C). That matters in Saudi summers.
* **OLED SSD1306:** it has high contrast, uses little power, needs only 2 data wires (I2C), and makes clear emoji drawings.
* **DFPlayer Mini:** it plays real recorded **voice** (Arabic or English) from an SD card. Its built-in 3 W amplifier drives a speaker directly.
* **TP4056 + 18650 + MT3608:** this is the classic, cheap and safe solar power chain. The TP4056 protection board stops
  over-charge, over-discharge and short circuit.

## 2.3 Power budget (energy calculation)

| Load | Current @ 5 V (average) |
|---|---|
| ESP32 with Wi-Fi connected (modem sleep) | ≈ 60 mA |
| ESP32 board regulator + USB chip + power LED | ≈ 10 mA |
| OLED (face drawn, ~30 % pixels on) | ≈ 12 mA |
| DFPlayer idle (+ a few seconds of voice per hour) | ≈ 18 mA |
| Soil sensor + DHT22 + BH1750 | ≈ 7 mA |
| **Total** | **≈ 107 mA @ 5 V ≈ 0.54 W** |

* With the boost converter (~85 % efficiency), the battery provides about **0.63 W**, or **≈ 15 Wh per day**.
* **Battery:** 2 × 3000 mAh × 3.7 V ≈ **22 Wh**, which gives about **35 hours without any sun** (more than one night plus a cloudy day).
* **Solar panel:** 6 W × ≈ 5.5 peak-sun-hours (Riyadh average) × 0.6 (losses: TP4056 not MPPT, angle, dust, heat)
  ≈ **20 Wh/day**. That is more than the 15 Wh/day the device uses, so ✅ the system is energy-positive.
* If the battery still drops below 3.45 V (for example, after several cloudy days or a dusty panel), the firmware enters **ECO mode**.
  The screen turns off and the ESP32 deep-sleeps, waking every 15 minutes to measure and upload. It returns to
  normal mode by itself when the solar panel recharges the battery.

> ⚠️ **The panel must see the sun.** Indoor light is ~100× weaker than sunlight and cannot charge the battery.
> If the plant is indoors, put the panel on a window or outside with a long cable (the plant can stay inside).

## 2.4 Safety notes

* Use **only protected TP4056 modules** and good-quality 18650 cells. Never short-circuit a cell.
* Put both cells in **parallel** (+ to +, − to −) only when they are at **the same voltage** (charge both fully first).
* Li-ion must not be **charged above 45 °C**. In summer, keep the battery box **in the shade** and ventilated,
  and never put it under the solar panel in direct sun.
* Do not use a 9 V or 12 V panel with the TP4056 (maximum input is 8 V).
* Turn the power switch **OFF** while the ESP32 is connected to the computer by USB.
