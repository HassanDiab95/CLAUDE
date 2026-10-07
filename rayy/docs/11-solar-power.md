# 11 · Solar Power Part (الطاقة الشمسية)

Rayy can run from the sun. A small solar panel charges two 18650 Li-ion batteries during the day,
and the batteries power the plant at night. The ESP32 measures the **battery level** and the **panel voltage**
and sends them to Firebase, so the web dashboard and the Android app show 🔋 battery % and 🔆 "charging from the sun".

> The 5 V USB power bank still works: it is the **backup / indoor testing** option. Choose with one line in
> `firmware/Rayy/config.h`: `#define SOLAR_ENABLED 1` (solar) or `0` (power bank).

## 11.1 Solar components (separate part)

| # | Component (EN) | المكوّن (AR) | Qty | Approx. SAR | Why |
|---|---|---|---|---|---|
| S1 | Solar panel **6 V, 6 W**, monocrystalline | لوح شمسي 6 فولت 6 واط | 1 | 35–50 | Produces the energy (≈ 1 A in full sun) |
| S2 | **CN3791 MPPT** solar Li-ion charger module (6 V version) | منظّم شحن شمسي MPPT | 1 | 15–25 | Charges the battery safely from the panel at its best point |
| S3 | **18650 Li-ion** battery 3.7 V, 3000 mAh, **protected** | بطارية ليثيوم 18650 | 2 | 40–60 | Stores the energy for the night and cloudy days |
| S4 | 2 × 18650 battery holder (**parallel**) | حامل بطاريتين 18650 | 1 | 8–12 | Holds the batteries: 3.7 V, 6000 mAh |
| S5 | **MT3608** DC-DC boost converter | رافع جهد إلى 5 فولت | 1 | 8–12 | Raises 3.7 V to the 5 V the ESP32 needs |
| S6 | Resistors **100 kΩ** | مقاومات 100 كيلو أوم | 5 | 2–5 | Voltage dividers so the ESP32 can measure the battery and the panel |
| S7 | ON / OFF switch (rocker or slide) | مفتاح تشغيل | 1 | 3–5 | Turns the plant off without removing the batteries |
| S8 | JST-PH 2-pin connectors + 22 AWG red/black wire | موصلات وأسلاك طاقة | 1 set | 10–15 | Clean, removable power connections |
| | **Solar part total** | **إجمالي الجزء الشمسي** | | **≈ 121–184** | |

Tools: a **multimeter** (needed to set the boost converter to 5 V), a small screwdriver.

## 11.2 Energy calculation (why these sizes)

| Item | Value |
|---|---|
| Rayy consumption (ESP32 + Wi-Fi + sensors), average | ≈ 0.5 W → **≈ 12 Wh per day** |
| Battery: 2 × 3000 mAh × 3.7 V | ≈ 22 Wh (≈ 19.5 Wh usable after the boost converter, 88 %) |
| Autonomy with **no sun at all** | 19.5 Wh ÷ 0.5 W ≈ **39 hours** (more in power-saving mode) |
| Panel energy in Saudi Arabia (≈ 5.5 peak-sun hours) | 6 W × 5.5 h × 0.7 (losses) ≈ **23 Wh per day** |
| Result | The panel produces about **2 ×** what the plant uses, so the battery is full every sunny day ✅ |

**Power-saving mode:** when the battery drops below **15 %** (`LOW_BATTERY_PCT`), the plant stops automatic melodies
and uploads every 2 minutes instead of every 30 seconds. It returns to normal above 25 %.

## 11.3 Wiring

```
 ☀ Solar panel 6 V                 CN3791 MPPT charger              2 × 18650 (parallel)
   (+) ─────────────────────────── IN+            BAT+ ─────────────── (+) ──┬──────────── Switch ─── MT3608 VIN+
   (−) ─────────────────────────── IN−            BAT− ─────────────── (−) ──┼──────────────────────── MT3608 VIN−
    │                                                                        │
    │  Panel divider (÷3)                                    Battery divider (÷2)
    │  Panel(+) ─ 100k ─ 100k ─┬─ 100k ─ GND                 BAT(+) ─ 100k ─┬─ 100k ─ GND
    │                          └──── ESP32 GPIO39 (VN)                      └──── ESP32 GPIO35
                                                              MT3608 VOUT+ (set to 5.1 V) ── ESP32 VIN (5V)
                                                              MT3608 VOUT− ─────────────── ESP32 GND
```

| From | To | Wire |
|---|---|---|
| Panel (+) / (−) | CN3791 **IN+ / IN−** | red / black |
| CN3791 **BAT+ / BAT−** | battery holder (+) / (−) | red / black |
| Battery (+) | switch → MT3608 **VIN+** | red |
| Battery (−) | MT3608 **VIN−** | black |
| MT3608 **VOUT+** (5.1 V) | ESP32 **VIN** (5V pin) | red |
| MT3608 **VOUT−** | ESP32 **GND** | black |
| Battery (+) → 100 kΩ → **GPIO35** → 100 kΩ → GND | battery sensing (÷ 2) | yellow |
| Panel (+) → 100 kΩ → 100 kΩ → **GPIO39 (VN)** → 100 kΩ → GND | panel sensing (÷ 3) | orange |
| All grounds (panel −, battery −, ESP32 GND) | common GND | black |

⚠️ **Safety rules**

1. **Set the MT3608 to 5.1 V first**: connect only the battery, measure VOUT with the multimeter, and turn the small
   screw on the blue potentiometer until it reads 5.0–5.2 V. **Only then** connect it to the ESP32.
2. **Never** power the ESP32 from the MT3608 **and** the USB cable at the same time. To upload code, switch the solar
   part **off**.
3. Use **protected** 18650 cells, put both cells the same way (+ to +), and use cells of the same model and charge.
4. The GPIO pins accept **max 3.3 V**: always keep the dividers. 4.2 V battery → 2.1 V; 7 V panel → 2.33 V.
5. Put the charger, batteries and boost converter inside the box, away from water. Only the panel is outside, in the sun.

## 11.4 Firmware (already done)

| File | What it does |
|---|---|
| `firmware/Rayy/power_calc.h` | Pure calculations: battery % from voltage, "is charging", power-saving hysteresis (unit-tested) |
| `firmware/Rayy/power.h / power.cpp` | Reads GPIO35 and GPIO39 (16 samples, calibrated mV), fills `PowerReading` |
| `firmware/Rayy/config.h` | `SOLAR_ENABLED`, `BATTERY_DIVIDER 2.0`, `SOLAR_DIVIDER 3.0`, `LOW_BATTERY_PCT 15`, `LOW_POWER_UPLOAD_MS` |
| `firmware/Rayy/pins.h` | `PIN_BATTERY 35`, `PIN_SOLAR 39` |
| `firmware/Rayy/cloud.cpp` | Adds `battery_pct`, `battery_v`, `solar_v`, `charging`, `saving` to `live` (and `battery_pct` to `history`) |

Serial Monitor line every 2 s:

```
power: battery=3.92V (69%)  solar=6.1V  charging=1  saving=0
```

## 11.5 Database fields (Firebase `plants/plant01/live`)

| Field | Type | Example | Meaning |
|---|---|---|---|
| `battery_pct` | number | 69 | Battery level % |
| `battery_v` | number | 3.92 | Battery voltage |
| `solar_v` | number | 6.1 | Panel voltage (0 at night) |
| `charging` | boolean | true | The sun is charging the battery |
| `saving` | boolean | false | Power-saving mode is active |

The web dashboard and the Android app show the **Battery** and **Solar panel** cards **only when these fields exist**,
so they still work with the power bank. The history chart has a new **Battery** line.

## 11.6 Calibration and tests

1. Measure the battery with the multimeter (e.g. 3.95 V) and compare with the Serial Monitor. If the difference is more
   than 0.05 V, adjust `BATTERY_DIVIDER` (e.g. 2.0 → 2.03). Do the same for the panel and `SOLAR_DIVIDER`.
2. Tests:

| # | Test | Expected |
|---|---|---|
| S-T1 | Panel in the sun | `charging=1`, ⚡ icon in the apps |
| S-T2 | Cover the panel | `solar` ≈ 0 V, "Not charging now" |
| S-T3 | 24 h with the panel outside | Battery % goes up during the day, down at night, never reaches 0 |
| S-T4 | Battery below 15 % (test by setting `LOW_BATTERY_PCT 100`) | No automatic melodies, uploads every 2 min, "Power-saving mode" |
| S-T5 | `SOLAR_ENABLED 0` on a power bank | Battery and solar cards are hidden, everything else works |
