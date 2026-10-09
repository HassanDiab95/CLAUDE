#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include "config.h"
#include "cloud.h"

static uint32_t lastWifiTry = 0;
static bool     serverOk = false;          // last request to the server worked
static int      serverHour = -1;           // hour of the server clock (from the last answer)
static uint32_t serverHourAt = 0;          // millis() when serverHour was received
static int      currentCrop = -1;          // crop this device measures now (from the server)
static bool     noCropWarned = false;

// ---------------------------------------------------------------------
void cloudBegin() {
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  lastWifiTry = millis();
  configTzTime(TZ_INFO, "pool.ntp.org", "time.google.com");   // works only if the network has internet
}

bool wifiConnected() { return WiFi.status() == WL_CONNECTED; }

bool cloudReady() { return wifiConnected() && serverOk; }

void cloudLoop() {
  if (!wifiConnected()) {
    serverOk = false;
    if (millis() - lastWifiTry > 20000) {          // retry every 20 s
      Serial.println("[wifi] reconnecting...");
      WiFi.disconnect();
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      lastWifiTry = millis();
    }
  }
}

int localHour() {
  struct tm t;
  if (getLocalTime(&t, 10) && t.tm_year >= (2024 - 1900)) return t.tm_hour;   // internet time
  // No internet (e.g. a local Wi-Fi with only the XAMPP computer): use the server clock
  if (serverHour >= 0 && millis() - serverHourAt < 6UL * 3600UL * 1000UL)
    return (serverHour + (millis() - serverHourAt) / 3600000UL) % 24;
  return -1;
}

// ---------------------------------------------------------------------
bool cloudSync(const Status& s, int soilRaw, bool withHistory, const char* eventMessage,
               PlantConfig& c, int* playTrack) {
  *playTrack = 0;
  if (!wifiConnected()) return false;

  JsonDocument d;
  d["moisture"] = roundf(s.reading.moisture);
  if (!isnan(s.reading.temperature)) d["temperature"] = roundf(s.reading.temperature * 10) / 10;
  if (!isnan(s.reading.humidity))    d["humidity"]    = roundf(s.reading.humidity);
  if (s.reading.lux >= 0)            d["lux"]         = roundf(s.reading.lux);
  d["mood"]     = moodName(s.mood);
  d["soil_raw"] = soilRaw;
  d["rssi"]     = WiFi.RSSI();
  d["ip"]       = WiFi.localIP().toString();
  d["uptime_s"] = millis() / 1000;
  d["history"]  = withHistory;
  if (eventMessage) {
    d["event"]["mood"] = moodName(s.mood);
    d["event"]["message"] = eventMessage;
  }
  String body, resp;
  serializeJson(d, body);

  WiFiClient client;
  HTTPClient http;
  http.setTimeout(5000);
  String url = String(SERVER_URL) + "/device.php?device=" + DEVICE_ID;
  if (!http.begin(client, url)) { serverOk = false; return false; }
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Key", DEVICE_KEY);
  int code = http.POST(body);
  resp = http.getString();
  http.end();

  if (code != 200) {
    Serial.printf("[server] error %d: %s\n", code, resp.c_str());
    serverOk = false;
    return false;
  }
  JsonDocument a;
  if (deserializeJson(a, resp)) { serverOk = false; return false; }
  serverOk = true;

  // Crop the device is assigned to now (changed from the apps)
  if (a["crop"].isNull()) {
    if (!noCropWarned) Serial.println("[server] this device is not assigned to a crop yet: assign it in the app");
    noCropWarned = true;
  } else {
    noCropWarned = false;
    int cropId = a["crop"]["crop_id"] | 0;
    if (cropId != currentCrop) {
      Serial.printf("[server] measuring crop %d: %s\n", cropId, a["crop"]["name"] | "");
      currentCrop = cropId;
    }
  }
  // Thresholds of that crop (saved from the web / Android app)
  JsonObject cfg = a["config"];
  c.moistureMin = cfg["moisture_min"] | c.moistureMin;
  c.moistureMax = cfg["moisture_max"] | c.moistureMax;
  c.tempMin     = cfg["temp_min"]     | c.tempMin;
  c.tempMax     = cfg["temp_max"]     | c.tempMax;
  c.luxMin      = cfg["lux_min"]      | c.luxMin;
  c.quietStart  = cfg["quiet_start"]  | c.quietStart;
  c.quietEnd    = cfg["quiet_end"]    | c.quietEnd;
  c.muted       = cfg["muted"]        | c.muted;

  *playTrack = a["play"] | 0;
  if (a["hour"].is<int>()) { serverHour = a["hour"]; serverHourAt = millis(); }
  return true;
}
