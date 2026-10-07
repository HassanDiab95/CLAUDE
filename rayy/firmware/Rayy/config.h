// =====================================================================
//  Rayy (ري) smart plant, USER CONFIGURATION
//  Edit the values in this file before uploading to the ESP32.
// =====================================================================
#pragma once

// ---------- Wi-Fi ----------------------------------------------------
#define WIFI_SSID            "YOUR_WIFI_NAME"
#define WIFI_PASSWORD        "YOUR_WIFI_PASSWORD"

// ---------- Firebase (see docs/04-firebase-setup.md) -----------------
// Project settings > General > Web API Key
#define FIREBASE_API_KEY     "YOUR_FIREBASE_WEB_API_KEY"
// Realtime Database URL, WITHOUT a trailing slash, for example
// "https://rayy-12345-default-rtdb.firebaseio.com"
// (or "...europe-west1.firebasedatabase.app" if you chose Europe)
#define FIREBASE_DB_URL      "https://YOUR-PROJECT-default-rtdb.firebaseio.com"
// The "device" user you created in Firebase Authentication
#define FIREBASE_USER_EMAIL  "device@rayy.app"
#define FIREBASE_USER_PASS   "CHANGE_ME_123"

// Every plant (ESP32) has its own ID in the database
#define PLANT_ID             "plant01"

// ---------- Timing ---------------------------------------------------
#define SENSOR_INTERVAL_MS    2000UL      // read sensors every 2 s
#define UPLOAD_INTERVAL_MS    30000UL     // send live data every 30 s
#define HISTORY_INTERVAL_MS   300000UL    // save a history point every 5 min

// ---------- Soil sensor calibration (see docs/08-testing-calibration.md)
// Raw ADC value (0..4095) with the sensor in DRY air and in a glass of WATER
#define SOIL_RAW_DRY          3000
#define SOIL_RAW_WET          1300

// ---------- Solar power (see docs/11-solar-power.md) -----------------
// 1 = solar panel + 18650 battery (measures battery and panel voltage)
// 0 = simple 5 V USB power bank / phone charger (nothing to measure)
#define SOLAR_ENABLED         1
// Voltage divider ratios: (R_top + R_bottom) / R_bottom
#define BATTERY_DIVIDER       2.0f        // 100k + 100k  -> 4.2 V reads as 2.1 V
#define SOLAR_DIVIDER         3.0f        // 200k + 100k  -> 7 V reads as 2.33 V
// Below this battery level the plant saves energy: melodies are muted
// and the cloud upload is slower (LOW_POWER_UPLOAD_MS)
#define LOW_BATTERY_PCT       15
#define LOW_POWER_UPLOAD_MS   120000UL    // upload every 2 min in saving mode

// ---------- Time zone (Saudi Arabia = UTC+3, no daylight saving) ------
#define TZ_INFO               "<+03>-3"
