#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include "config.h"
#include "cloud.h"

static String   idToken;                 // Firebase login token (valid 1 hour)
static uint32_t tokenTime = 0;           // millis() when we got the token
static uint32_t lastLoginTry = 0;
static uint32_t lastWifiTry = 0;
static const uint32_t TOKEN_LIFETIME_MS = 50UL * 60UL * 1000UL;  // renew after 50 min

static String basePath() {
  return String(FIREBASE_DB_URL) + "/plants/" + PLANT_ID;
}

// One HTTPS request. Returns the HTTP status code (negative on network error).
static int request(const char* method, const String& url, const String& body, String* response) {
  WiFiClientSecure client;
  // NOTE: setInsecure() skips certificate checking. It keeps the project simple;
  // for a production device load the Google root CA with client.setCACert().
  client.setInsecure();
  HTTPClient http;
  http.setTimeout(8000);
  if (!http.begin(client, url)) return -1;
  http.addHeader("Content-Type", "application/json");
  int code = http.sendRequest(method, body);
  if (response) *response = http.getString();
  http.end();
  return code;
}

static bool signIn() {
  String url = String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=") + FIREBASE_API_KEY;
  JsonDocument req;
  req["email"] = FIREBASE_USER_EMAIL;
  req["password"] = FIREBASE_USER_PASS;
  req["returnSecureToken"] = true;
  String body, resp;
  serializeJson(req, body);
  int code = request("POST", url, body, &resp);
  if (code != 200) {
    Serial.printf("[cloud] sign-in failed (%d): %s\n", code, resp.c_str());
    return false;
  }
  JsonDocument doc;
  if (deserializeJson(doc, resp)) return false;
  idToken = doc["idToken"].as<String>();
  tokenTime = millis();
  Serial.println("[cloud] signed in to Firebase");
  return idToken.length() > 0;
}

static String authQuery() { return String(".json?auth=") + idToken; }

// ---------------------------------------------------------------------
void cloudBegin() {
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  lastWifiTry = millis();
  configTzTime(TZ_INFO, "pool.ntp.org", "time.google.com");
}

bool wifiConnected() { return WiFi.status() == WL_CONNECTED; }

bool cloudReady() {
  return wifiConnected() && idToken.length() > 0 && millis() - tokenTime < TOKEN_LIFETIME_MS;
}

void cloudLoop() {
  if (!wifiConnected()) {
    if (millis() - lastWifiTry > 20000) {          // retry every 20 s
      Serial.println("[wifi] reconnecting...");
      WiFi.disconnect();
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      lastWifiTry = millis();
    }
    return;
  }
  if (!cloudReady() && millis() - lastLoginTry > 15000) {
    lastLoginTry = millis();
    signIn();
  }
}

int localHour() {
  struct tm t;
  if (!getLocalTime(&t, 10)) return -1;
  if (t.tm_year < (2024 - 1900)) return -1;        // not synced yet
  return t.tm_hour;
}

static void addReading(JsonDocument& d, const Status& s) {
  d["moisture"] = roundf(s.reading.moisture);
  if (!isnan(s.reading.temperature)) d["temperature"] = roundf(s.reading.temperature * 10) / 10;
  if (!isnan(s.reading.humidity))    d["humidity"]    = roundf(s.reading.humidity);
  if (s.reading.lux >= 0)            d["lux"]         = roundf(s.reading.lux);
  d["mood"] = moodName(s.mood);
  if (s.power.enabled) {                           // solar part
    d["battery_pct"] = s.power.batteryPct;
    d["battery_v"]   = roundf(s.power.batteryV * 100) / 100;
    d["solar_v"]     = roundf(s.power.solarV * 10) / 10;
    d["charging"]    = s.power.charging;
    d["saving"]      = s.power.lowBattery;
  }
  d["ts"][".sv"] = "timestamp";                    // server time (milliseconds)
}

bool cloudSendLive(const Status& s, int soilRaw) {
  if (!cloudReady()) return false;
  JsonDocument d;
  addReading(d, s);
  d["soil_raw"]    = soilRaw;
  d["rssi"]        = WiFi.RSSI();
  d["ip"]          = WiFi.localIP().toString();
  d["uptime_s"]    = millis() / 1000;
  String body;
  serializeJson(d, body);
  int code = request("PUT", basePath() + "/live" + authQuery(), body, nullptr);
  if (code == 401) idToken = "";                   // token refused, sign in again
  return code == 200;
}

bool cloudSendHistory(const Status& s) {
  if (!cloudReady()) return false;
  JsonDocument d;
  addReading(d, s);
  String body;
  serializeJson(d, body);
  return request("POST", basePath() + "/history" + authQuery(), body, nullptr) == 200;
}

bool cloudSendEvent(Mood mood, const char* message) {
  if (!cloudReady()) return false;
  JsonDocument d;
  d["mood"] = moodName(mood);
  d["message"] = message;
  d["ts"][".sv"] = "timestamp";
  String body;
  serializeJson(d, body);
  return request("POST", basePath() + "/events" + authQuery(), body, nullptr) == 200;
}

bool cloudFetchConfig(PlantConfig& c) {
  if (!cloudReady()) return false;
  String resp;
  if (request("GET", basePath() + "/config" + authQuery(), "", &resp) != 200) return false;
  JsonDocument d;
  if (deserializeJson(d, resp) || d.isNull()) return false;   // "null" = no config yet
  // Only overwrite the fields that exist in the database
  c.moistureMin = d["moisture_min"] | c.moistureMin;
  c.moistureMax = d["moisture_max"] | c.moistureMax;
  c.tempMin     = d["temp_min"]     | c.tempMin;
  c.tempMax     = d["temp_max"]     | c.tempMax;
  c.luxMin      = d["lux_min"]      | c.luxMin;
  c.dayStart    = d["day_start"]    | c.dayStart;
  c.dayEnd      = d["day_end"]      | c.dayEnd;
  c.quietStart  = d["quiet_start"]  | c.quietStart;
  c.quietEnd    = d["quiet_end"]    | c.quietEnd;
  c.repeatMin   = d["repeat_min"]   | c.repeatMin;
  c.muted       = d["muted"]        | c.muted;
  return true;
}

int cloudFetchCommand() {
  if (!cloudReady()) return 0;
  String resp;
  String url = basePath() + "/command" + authQuery();
  if (request("GET", url, "", &resp) != 200) return 0;
  JsonDocument d;
  if (deserializeJson(d, resp) || d.isNull()) return 0;
  int track = d["play"] | 0;
  if (track > 0) request("DELETE", url, "", nullptr);  // consume the command
  return track;
}
