# 08 · Calibration and Testing

## 8.1 Calibrate the soil moisture sensor (important!)

Every capacitive sensor gives slightly different raw values. Calibrate it before you trust the percentages:

1. Upload the firmware and open the **Serial Monitor** (115200). Each line shows `soil=..% (raw XXXX)`.
2. Hold the sensor **in the air, dry**. Note the raw value (e.g. **3050**). This is `SOIL_RAW_DRY`.
3. Put the sensor **in a glass of water up to the white line**. Note the raw value (e.g. **1280**). This is `SOIL_RAW_WET`.
4. Write both numbers in `config.h` and upload again.
5. Check: dry soil should read about 10–25 %, and soil just after watering about 60–80 %.

The raw value is also uploaded to Firebase (`live/soil_raw`), so you can calibrate from the web console too.

## 8.2 Calibrate the battery voltage

1. Measure the battery with a **multimeter** (e.g. 3.98 V).
2. Compare it with `batt=` in the Serial Monitor (e.g. 3.90 V).
3. Set `BATTERY_CAL = 3.98 / 3.90 = 1.02` in `config.h`. Do the same for `SOLAR_CAL` if needed.

## 8.3 Choose thresholds for your plant

| Plant type | Thirsty below | Too wet above | Light min (lux) | Hot above |
|---|---|---|---|---|
| Basil / mint (herbs) | 35 % | 85 % | 1000 | 35 °C |
| Pothos / indoor plants | 25 % | 80 % | 200 | 32 °C |
| Cactus / succulents | 10 % | 50 % | 2000 | 40 °C |

Change them from the web app → **Plant settings** (no re-upload needed).

## 8.4 Test plan

| # | Test | Steps | Expected result | ✔ |
|---|---|---|---|---|
| T1 | Start-up | Power on | OLED "Smart Plant / Starting…", "Hello" voice, face appears | |
| T2 | Wi-Fi + Firebase | Watch Serial Monitor | `[cloud] signed in to Firebase`, LED solid | |
| T3 | Thirsty | Pull the soil sensor out (dry air) | 😫 face, voice 0001 "I'm thirsty", web + app show "Thirsty" within 30 s | |
| T4 | Thank you | Put the sensor back in wet soil | 😊 face, voice 0007 "Thank you", diary event | |
| T5 | Too wet | Sensor in a glass of water | 🥴 face, voice 0002 | |
| T6 | Hot | Warm the DHT22 with a hair dryer (carefully) > 35 °C | 🥵 face, voice 0003 | |
| T7 | Cold | DHT22 near an ice pack < 10 °C | 🥶 face, voice 0004 | |
| T8 | Needs light | Cover the BH1750 with your hand during the day | 😞 face, voice 0005 | |
| T9 | Night | Set "day end" earlier or wait until 18:00 | 😴 face, "good night" once, no other complaints in quiet hours | |
| T10 | Repeat | Keep the plant thirsty for 30 min | The voice repeats once every 30 min | |
| T11 | Mute | Web → mute → make it thirsty | Face changes, no sound, "M" shown on OLED | |
| T12 | Speak now | Web/app → choose track → Speak | The plant plays it within 30 s | |
| T13 | Settings | Change "Thirsty below" to 60 % | The plant becomes thirsty within 30 s | |
| T14 | Offline | Turn off the router | Face/voice still work, LED blinks, the web shows "Offline"; after the router is back, data resumes automatically | |
| T15 | Button | Short press / long press | Screen changes / plant says its current mood | |
| T16 | Security | Open the database URL `…/plants.json` in a browser (not signed in) | `Permission denied` | |
| T17 | Solar charging | Put the panel in the sun | `charging: true`, battery % increases during the day | |
| T18 | Night autonomy | Leave it running for 24 h outdoors | It works through the night; the history chart shows the battery curve | |
| T19 | ECO mode | Use a nearly empty battery (< 3.45 V) | "Low battery / ECO mode", wakes every 15 min, event in the diary | |
| T20 | Android | Install the APK, sign in | The same values as the web, updated in real time | |
| T21 | Unit tests | `tests/test_mood` | `33 checks, 0 failures` | |

Record the results (photos, screenshots, history charts) for the report's **Testing and Results** chapter.
