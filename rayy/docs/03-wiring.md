# 03 · Wiring and Assembly

![Wiring diagram](images/wiring-diagram.png)

(Vector version: [`images/wiring-diagram.svg`](images/wiring-diagram.svg))

## 3.1 ESP32 pin map

| ESP32 pin | Connected to | Notes |
|---|---|---|
| **VIN (5V)** | MT3608 boost **VOUT+** (5.1 V) | Solar power (see 3.3). **Or** the USB port with a power bank while testing |
| **3V3** | VCC of soil sensor, DHT22, BH1750 | Total < 50 mA |
| **GND** | GND of every module | **All grounds together** |
| **GPIO34** | Soil sensor **AOUT** | Analog input (ADC1) |
| **GPIO4** | DHT22 **OUT / DATA** | |
| **GPIO21** | I2C **SDA**: BH1750 | |
| **GPIO22** | I2C **SCL**: BH1750 | |
| **GPIO25** | **100 Ω** → buzzer **(+)** | PWM melodies |
| **GPIO13** | Push button → GND | Internal pull-up is used |
| GPIO2 | On-board blue LED | Solid = connected to Firebase, blinking = offline |
| **GPIO35** | Battery (+) → 100 kΩ → **GPIO35** → 100 kΩ → GND | Battery voltage ÷ 2 (input only) |
| **GPIO39 (VN)** | Panel (+) → 100 kΩ → 100 kΩ → **GPIO39** → 100 kΩ → GND | Panel voltage ÷ 3 (input only) |

> Analog sensors **must** use ADC1 pins (GPIO32–39). ADC2 pins stop working when Wi-Fi is on.

## 3.2 Module by module

### Capacitive soil moisture sensor v1.2
| Sensor pin | ESP32 |
|---|---|
| VCC | 3V3 |
| GND | GND |
| AOUT | GPIO34 |

Push the sensor into the soil **up to the white line only**. The electronics at the top must stay dry
(cover the top edge with nail polish, hot glue or heat-shrink to protect it from water).

### DHT22 (module with 3 pins)
| Sensor pin | ESP32 |
|---|---|
| + (VCC) | 3V3 |
| OUT (DATA) | GPIO4 |
| − (GND) | GND |

If you have the **bare 4-pin** DHT22: pin 1 = VCC, pin 2 = DATA (add a **10 kΩ** resistor between DATA and 3V3),
pin 3 = not connected, pin 4 = GND. Keep it outside the box, in the shade.

### BH1750 light sensor (GY-302)
| Sensor pin | ESP32 |
|---|---|
| VCC | 3V3 |
| GND | GND |
| SCL | GPIO22 |
| SDA | GPIO21 |
| ADDR | GND (address 0x23) |

Point it **up**, next to the plant leaves.

### Passive buzzer
| Buzzer pin | ESP32 |
|---|---|
| **+** (or **S** on a 3-pin module) | **100 Ω resistor** → GPIO25 |
| **−** | GND |
| middle pin of a 3-pin module (if present) | not needed (or 3V3) |

The 100 Ω resistor limits the current from the ESP32 pin. For a **louder** sound (optional): drive the buzzer
with an NPN transistor (2N2222 / S8050): GPIO25 → 1 kΩ → base, emitter → GND, collector → buzzer (−),
buzzer (+) → 5 V (VIN pin).

### Push button
One leg → GPIO13, the diagonal leg → GND.

## 3.3 Power (solar part)

```
Solar panel 6 V ──► CN3791 MPPT charger ──► 2 × 18650 (parallel) ──► switch ──► MT3608 (5.1 V) ──► ESP32 VIN + GND
```

1. Panel (+)/(−) → CN3791 **IN+ / IN−**.
2. CN3791 **BAT+ / BAT−** → battery holder (+)/(−).
3. Battery (+) → **switch** → MT3608 **VIN+**; battery (−) → MT3608 **VIN−**.
4. **Set the MT3608 to 5.1 V with the multimeter before connecting the ESP32.**
5. MT3608 **VOUT+** → ESP32 **VIN**; **VOUT−** → ESP32 **GND**.
6. Add the two voltage dividers to **GPIO35** (battery) and **GPIO39** (panel) from the table above.

The board's regulator makes 3.3 V for the sensors. ⚠️ Never connect the USB cable and the MT3608 at the same time:
switch the solar part **off** before uploading code. While building, you can power the board from a **5 V USB power
bank** through the USB port instead (set `SOLAR_ENABLED 0`). Full details: [11 · Solar power](11-solar-power.md).

## 3.4 Assembly steps (recommended order)

1. **ESP32 + buzzer** first. Upload the firmware and check that the "hello" melody plays at start-up.
2. Open the Serial Monitor (115200 baud) to see the messages.
3. Add the **BH1750 and DHT22** and check the readings in the Serial Monitor (115200 baud).
4. Add the **soil sensor** and calibrate it ([08](08-testing-calibration.md)).
5. Add the **button**: a press plays the current mood's melody.
6. **Final version:** solder onto a small perfboard (or use a mini breadboard) and put it in a box fixed to the pot:
   holes for the buzzer, a hole for the USB cable, and the soil sensor cable going
   into the pot. The DHT22 and BH1750 stay outside the box.
7. **Solar part:** set the MT3608 to 5.1 V, wire the charger, batteries, switch and dividers (3.3), put them in the
   box, and place the **solar panel** outside facing the sun (south, tilted ≈ 25°).

## 3.5 Typical problems

| Problem | Cause / solution |
|---|---|
| BH1750 not found | Check SDA/SCL. Run the "I2C scanner" example sketch: you should see 0x23 |
| DHT22 reads `nan` | Wrong pin, or missing pull-up on a bare sensor |
| Soil % always 0 or 100 | Not calibrated (see [08](08-testing-calibration.md)) |
| No sound | Active buzzer instead of passive, wrong pin, or (+)/(−) reversed |
| Board not detected by the PC | Charge-only USB cable (use a data cable) or missing CP210x/CH340 driver |
| Project turns off on the power bank | The power bank auto-shuts-off at low current; use another one or a phone charger |
| ESP32 restarts when Wi-Fi starts (solar) | Battery empty, or MT3608 below 5 V: charge the battery, re-set the MT3608 to 5.1 V |
| Battery % is wrong | Check the 100 kΩ divider on GPIO35; calibrate `BATTERY_DIVIDER` ([11](11-solar-power.md)) |
| "Not charging" in full sun | Panel wires reversed or CN3791 IN not connected; panel shaded |
