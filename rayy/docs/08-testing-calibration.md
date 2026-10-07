# 08 · Calibration and Testing

## 8.1 Calibrate the soil moisture sensor (important!)

Every capacitive sensor gives slightly different raw values. Calibrate it before you trust the percentages:

1. Upload the firmware and open the **Serial Monitor** (115200). Each line shows `soil=..% (raw XXXX)`.
2. Hold the sensor **in the air, dry**. Note the raw value (e.g. **3050**). This is `SOIL_RAW_DRY`.
3. Put the sensor **in a glass of water up to the white line**. Note the raw value (e.g. **1280**). This is `SOIL_RAW_WET`.
4. Write both numbers in `config.h` and upload again.
5. Check: dry soil should read about 10–25 %, and soil just after watering about 60–80 %.

The raw value is also uploaded to Firebase (`live/soil_raw`), so you can see it in the Firebase console too.

## 8.2 Choose thresholds for your plant

| Plant type | Thirsty below | Too wet above | Light min (lux) | Hot above |
|---|---|---|---|---|
| Basil / mint (herbs) | 35 % | 85 % | 1000 | 35 °C |
| Pothos / indoor plants | 25 % | 80 % | 200 | 32 °C |
| Cactus / succulents | 10 % | 50 % | 2000 | 40 °C |

Change them from the web app → **Plant settings** (no re-upload needed).

## 8.3 Test plan

| # | Test | Steps | Expected result | ✔ |
|---|---|---|---|---|
| T1 | Start-up | Plug in the power bank | "hello" melody; Serial Monitor shows the readings | |
| T2 | Wi-Fi + Firebase | Watch the Serial Monitor | `[cloud] signed in to Firebase`, blue LED solid | |
| T3 | Thirsty | Pull the soil sensor out (dry air) | 😫 face, melody 1, web + app show "Thirsty" within 30 s | |
| T4 | Thank you | Put the sensor back in wet soil | 😊 face, melody 7 "thank you", diary event | |
| T5 | Too wet | Sensor in a glass of water | 🥴 face, melody 2 | |
| T6 | Hot | Warm the DHT22 with your hand / a hair dryer (carefully) > 35 °C | 🥵 face, melody 3 | |
| T7 | Cold | DHT22 near an ice pack < 10 °C | 🥶 face, melody 4 | |
| T8 | Needs light | Cover the BH1750 with your hand during the day | 😞 face, melody 5 | |
| T9 | Night | Set "day end" earlier or wait until 18:00 | 😴 face, lullaby once, no sounds in quiet hours | |
| T10 | Repeat | Keep the plant thirsty for 30 min | The melody repeats once every 30 min | |
| T11 | Mute | Web → mute → make it thirsty | Emoji in the apps changes, no sound | |
| T12 | Play from app | Web/app → choose a melody → Play | The plant plays it within 30 s | |
| T13 | Settings | Change "Thirsty below" to 60 % | The plant becomes thirsty within 30 s | |
| T14 | Offline | Turn off the router | Face and sounds still work, LED blinks, web shows "Offline"; data resumes automatically when the router is back | |
| T15 | Button | Press the button | The plant plays the current mood melody | |
| T16 | Security | Open `<database-url>/plants.json` in a browser (not signed in) | `Permission denied` | |
| T17 | Power bank | Run on a 10,000 mAh power bank (`SOLAR_ENABLED 0`) | Works for ≈ 2 days; no battery cards in the apps | |
| T18 | Android | Install the APK, sign in | The same values as the web, updated in real time | |
| T19 | Unit tests | `tests/test_mood` | `47 checks, 0 failures` | |
| T20 | Solar charging | Panel in the sun | `charging=1`; apps show ⚡ and "Charging from the sun ☀️" | |
| T21 | No sun | Cover the panel | `solar` ≈ 0 V; apps show "Not charging now" | |
| T22 | Battery reading | Compare multimeter and Serial Monitor | Difference < 0.05 V (else calibrate `BATTERY_DIVIDER`) | |
| T23 | 24 h solar run | Leave the plant outside for one day and night | Works all night; battery % rises in the day (history chart "Battery") | |
| T24 | Power-saving | Set `LOW_BATTERY_PCT 100` temporarily | No automatic melodies, uploads every 2 min, "Power-saving mode" in the apps | |

Record the results (photos, screenshots, history charts) for the report's **Testing and Results** chapter.
