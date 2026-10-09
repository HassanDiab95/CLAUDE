# 08 · Calibration and Testing

## 8.1 Calibrate the soil moisture sensor (important!)

Every capacitive sensor gives slightly different raw values. Calibrate it before you trust the percentages:

1. Upload the firmware and open the **Serial Monitor** (115200). Each line shows `soil=..% (raw XXXX)`.
2. Hold the sensor **in the air, dry**. Note the raw value (e.g. **3050**). This is `SOIL_RAW_DRY`.
3. Put the sensor **in a glass of water up to the white line**. Note the raw value (e.g. **1280**). This is `SOIL_RAW_WET`.
4. Write both numbers in `config.h` and upload again.
5. Check: dry soil should read about 10–25 %, and soil just after watering about 60–80 %.

The raw value is also uploaded to MySQL (table `live_status`, column `soil_raw`), so you can see it in phpMyAdmin too.

## 8.2 Thresholds of each crop

You do not need to choose the numbers yourself: when you add a crop, its **crop type** fills the ideal values
from the library (`crop_types` table):

| Crop type | Thirsty below | Too wet above | Cold below | Hot above | Light min (lux) |
|---|---|---|---|---|---|
| 🍓 Strawberry | 60 % | 85 % | 10 °C | 28 °C | 5000 |
| 🍅 Tomato | 50 % | 80 % | 15 °C | 32 °C | 8000 |
| 🥒 Cucumber | 60 % | 85 % | 18 °C | 32 °C | 6000 |
| 🫑 Pepper | 50 % | 80 % | 18 °C | 32 °C | 7000 |
| 🥬 Lettuce | 60 % | 85 % | 7 °C | 24 °C | 3000 |
| 🌿 Mint | 55 % | 85 % | 10 °C | 30 °C | 2000 |
| 🌱 Basil | 45 % | 80 % | 15 °C | 32 °C | 3000 |
| 🌴 Date palm (young) | 30 % | 70 % | 15 °C | 45 °C | 10000 |
| 🌹 Rose | 45 % | 75 % | 12 °C | 30 °C | 5000 |
| 🌵 Cactus | 10 % | 40 % | 10 °C | 40 °C | 5000 |
| 🪴 Indoor plant | 40 % | 80 % | 15 °C | 30 °C | 200 |
| 🌾 Other | 30 % | 85 % | 10 °C | 35 °C | 200 |

After calibrating the soil sensor, adjust them for your real crop from the app → crop page → **Crop settings**
(no re-upload needed). The values are typical for growing in Saudi Arabia and should be checked with the
agriculture teacher or a local farmer.

## 8.3 Test plan

| # | Test | Steps | Expected result | ✔ |
|---|---|---|---|---|
| T1 | Start-up | Plug in the power bank | "hello" melody; Serial Monitor shows the readings | |
| T2 | Wi-Fi + server | Watch the Serial Monitor | `[server] connected to …/rayy/api`, `server=1`, blue LED solid | |
| T3 | Thirsty | Pull the soil sensor out (dry air) | 😫 face, melody 1, web + app show "Thirsty" within 30 s | |
| T4 | Thank you | Put the sensor back in wet soil | 😊 face, melody 7 "thank you", diary event | |
| T5 | Too wet | Sensor in a glass of water | 🥴 face, melody 2 | |
| T6 | Hot | Warm the DHT22 with your hand / a hair dryer (carefully) > 35 °C | 🥵 face, melody 3 | |
| T7 | Cold | DHT22 near an ice pack < 10 °C | 🥶 face, melody 4 | |
| T8 | Needs light | Cover the BH1750 with your hand during the day | 😞 face, melody 5 | |
| T9 | Night | Set "day end" earlier or wait until 18:00 | 😴 face, lullaby once, no sounds in quiet hours | |
| T10 | Repeat | Keep the crop thirsty for 30 min | The melody repeats once every 30 min | |
| T11 | Mute | Web → mute → make it thirsty | Emoji in the apps changes, no sound | |
| T12 | Play from app | Web/app → choose a melody → Play | The device plays it within 30 s | |
| T13 | Settings | Change "Thirsty below" to 60 % | The crop becomes thirsty within 30 s | |
| T14 | Offline | Turn off the router | Face and sounds still work, LED blinks, web shows "Offline"; data resumes automatically when the router is back | |
| T15 | Button | Press the button | The device plays the current mood melody | |
| T16 | Security | Open `http://<ip>/rayy/api/crops.php` in a browser (not signed in) | `Not signed in` | |
| T17 | Power bank | Run on a 10,000 mAh power bank | Works for ≈ 2 days | |
| T18 | Android | Install the APK, sign in | The same crops and values as the web, updated every 5 s | |
| T19 | Unit tests | `tests/test_mood` | `33 checks, 0 failures` | |
| T20 | Create account | Web or Android → Create account | Signed in as a new user with no crops | |
| T21 | Add crops | Add a strawberry crop and a cactus crop | Each crop gets the ideal values of its type | |
| T22 | Move the device | Crop page → Move to this crop (strawberry), soil sensor in dry soil | 😫 thirsty | |
| T23 | Same soil, other crop | Move the device to the cactus crop, same dry soil | Within 30 s: 😊 happy (cactus likes dry soil); strawberry keeps its history | |
| T24 | Permissions | Sign in as a normal user | Sees only own crops and devices, no Users tab | |
| T25 | Admin | Sign in as admin → Users | Create a user, make them admin, delete them | |
| T26 | API test | `bash tests/test_api.sh http://localhost/rayy/api` (fresh `rayy.sql`) | `44 passed, 0 failed` | |

Record the results (photos, screenshots, history charts) for the report's **Testing and Results** chapter.
