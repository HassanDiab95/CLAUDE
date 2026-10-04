// =====================================================================
//  Smart Plant (IoT emoji plant), USER CONFIGURATION
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
// "https://smart-plant-12345-default-rtdb.firebaseio.com"
// (or "...europe-west1.firebasedatabase.app" if you chose Europe)
#define FIREBASE_DB_URL      "https://YOUR-PROJECT-default-rtdb.firebaseio.com"
// The "device" user you created in Firebase Authentication
#define FIREBASE_USER_EMAIL  "device@smartplant.app"
#define FIREBASE_USER_PASS   "CHANGE_ME_123"

// Every plant (ESP32) has its own ID in the database
#define PLANT_ID             "plant01"

// ---------- Timing ---------------------------------------------------
#define SENSOR_INTERVAL_MS    2000UL      // read sensors every 2 s
#define UPLOAD_INTERVAL_MS    30000UL     // send live data every 30 s
#define HISTORY_INTERVAL_MS   300000UL    // save a history point every 5 min
#define SCREEN_ROTATE_MS      6000UL      // face screen <-> data screen

// ---------- Soil sensor calibration (see docs/08-testing-calibration.md)
// Raw ADC value (0..4095) with the sensor in DRY air and in a glass of WATER
#define SOIL_RAW_DRY          3000
#define SOIL_RAW_WET          1300

// ---------- Battery / solar measurement ------------------------------
// Voltage dividers: battery 100k/100k, solar 100k/47k
#define BATTERY_DIVIDER       2.0f
#define SOLAR_DIVIDER         ((100.0f + 47.0f) / 47.0f)
// Fine calibration: measured-with-multimeter / value-shown-by-ESP32
#define BATTERY_CAL           1.00f
#define SOLAR_CAL             1.00f
// Below this voltage the plant enters ECO mode (deep sleep between uploads)
#define BATTERY_ECO_VOLTS     3.45f
#define ECO_SLEEP_MINUTES     15

// ---------- Time zone (Saudi Arabia = UTC+3, no daylight saving) ------
#define TZ_INFO               "<+03>-3"
