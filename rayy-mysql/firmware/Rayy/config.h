// =====================================================================
//  Rayy (ري) smart plant, USER CONFIGURATION
//  Edit the values in this file before uploading to the ESP32.
// =====================================================================
#pragma once

// ---------- Wi-Fi ----------------------------------------------------
#define WIFI_SSID            "YOUR_WIFI_NAME"
#define WIFI_PASSWORD        "YOUR_WIFI_PASSWORD"

// ---------- Rayy server (XAMPP: Apache + PHP + MySQL) -----------------
// The IP address of the computer that runs XAMPP (Windows: ipconfig →
// "IPv4 Address"), followed by /rayy/api. No "/" at the end.
// Do NOT write "localhost": for the ESP32, localhost is the ESP32 itself.
#define SERVER_URL           "http://192.168.1.10/rayy/api"
// Secret key of this plant. The same text is saved (as SHA-256) in the
// "plants" table by database/rayy.sql. Change it in both places.
#define DEVICE_KEY           "rayy-device-key-2026"

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

// ---------- Time zone (Saudi Arabia = UTC+3, no daylight saving) ------
#define TZ_INFO               "<+03>-3"
