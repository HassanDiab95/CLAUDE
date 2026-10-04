// =====================================================================
//  SMART EMOJI PLANT: solar-powered IoT plant that shows its feelings
//  with emoji faces and voice messages.
//
//  Board  : ESP32 Dev Module (ESP32 DevKit V1)
//  Core   : esp32 by Espressif Systems 3.x (Arduino IDE Boards Manager)
//  Libs   : Adafruit SSD1306, Adafruit GFX, DHT sensor library,
//           Adafruit Unified Sensor, BH1750 (Christopher Laws),
//           DFRobotDFPlayerMini, ArduinoJson 7
//
//  Edit config.h (Wi-Fi + Firebase) before uploading.
// =====================================================================
#include <Wire.h>
#include <WiFi.h>
#include "config.h"
#include "pins.h"
#include "mood.h"
#include "sensors.h"
#include "display.h"
#include "voice.h"
#include "cloud.h"

// Kept in RTC memory so they survive deep sleep (ECO mode)
RTC_DATA_ATTR Mood savedMood = MOOD_HAPPY;
RTC_DATA_ATTR bool ecoMode = false;

static PlantConfig cfg;
static Status      st;
static Mood        prevMood = MOOD_HAPPY;
static bool        firstEvaluation = true;

static uint32_t lastSensor = 0, lastUpload = 0, lastHistory = 0, lastFrame = 0;
static uint32_t lastScreenSwap = 0, lastVoice = 0, frame = 0;
static bool     showFace = true;
static bool     oledOk = false;
static bool     pendingEvent = false;   // mood changed while offline

// ---------------------------------------------------------------------
static const char* moodMessage(Mood m) {
  switch (m) {
    case MOOD_HAPPY:      return "I am happy, everything is perfect!";
    case MOOD_THIRSTY:    return "I am thirsty, please water me!";
    case MOOD_DROWNING:   return "Too much water, I am drowning!";
    case MOOD_HOT:        return "It is too hot, move me to a cooler place!";
    case MOOD_COLD:       return "I feel cold, I need a warmer place!";
    case MOOD_NEED_LIGHT: return "I need more light!";
    case MOOD_SLEEPY:     return "Good night, I am sleeping.";
    default:              return "";
  }
}

static Track trackForMood(Mood m) {
  switch (m) {
    case MOOD_THIRSTY:    return TRACK_THIRSTY;
    case MOOD_DROWNING:   return TRACK_DROWNING;
    case MOOD_HOT:        return TRACK_HOT;
    case MOOD_COLD:       return TRACK_COLD;
    case MOOD_NEED_LIGHT: return TRACK_NEED_LIGHT;
    case MOOD_SLEEPY:     return TRACK_GOOD_NIGHT;
    default:              return TRACK_HAPPY;
  }
}

static void updatePower() {
  st.batteryVolts = batteryVolts();
  float sv = solarVolts();
  // Below 2.5 V there is no battery: the board is powered from USB while developing
  bool usbOnly = st.batteryVolts < 2.5f;
  st.batteryPct = usbOnly ? 100 : batteryPercent(st.batteryVolts);
  st.charging = sv > 4.5f && sv > st.batteryVolts + 0.3f;
  if (usbOnly) ecoMode = false;
  else if (st.batteryVolts < BATTERY_ECO_VOLTS && !st.charging) ecoMode = true;
  else if (st.batteryVolts > BATTERY_ECO_VOLTS + 0.15f) ecoMode = false;
}

static void readAndEvaluate() {
  sensorsRead(st.reading);
  updatePower();
  int hour = localHour();
  Mood m = evaluateMood(st.reading, cfg, hour, prevMood);
  st.mood = m;
  st.wifi = wifiConnected();
  st.cloud = cloudReady();
  st.muted = cfg.muted;

  if (firstEvaluation) {              // do not complain about the boot mood twice
    firstEvaluation = false;
    if (m != savedMood) pendingEvent = true;
    prevMood = m;
    savedMood = m;
    return;
  }

  uint32_t minutesSinceVoice = (millis() - lastVoice) / 60000UL;
  Track t = chooseTrack(m, prevMood, minutesSinceVoice, hour, cfg);
  if (t != TRACK_NONE) { voicePlay(t); lastVoice = millis(); }

  if (m != prevMood) {
    Serial.printf("[mood] %s -> %s\n", moodName(prevMood), moodName(m));
    pendingEvent = true;
    showFace = true;                  // show the new face immediately
    lastScreenSwap = millis();
  }
  prevMood = m;
  savedMood = m;
}

static void syncCloud(bool withHistory) {
  if (!cloudReady()) return;
  if (cloudFetchConfig(cfg)) voiceSetVolume(cfg.volume);
  cloudSendLive(st, soilRaw(), solarVolts());
  if (pendingEvent && cloudSendEvent(st.mood, moodMessage(st.mood))) pendingEvent = false;
  if (withHistory) cloudSendHistory(st);
  int cmd = cloudFetchCommand();
  if (cmd > 0) { voicePlay((Track)cmd); lastVoice = millis(); }
}

// Short press: switch screen. Long press (>1 s): say how I feel now.
static void handleButton() {
  static bool wasDown = false;
  static uint32_t downAt = 0;
  bool down = digitalRead(PIN_BUTTON) == LOW;
  if (down && !wasDown) downAt = millis();
  if (!down && wasDown) {
    uint32_t held = millis() - downAt;
    if (held > 1000) { voicePlay(trackForMood(st.mood)); lastVoice = millis(); }
    else if (held > 40) { showFace = !showFace; lastScreenSwap = millis(); }
  }
  wasDown = down;
}

// ECO mode: one quick measurement + upload, then deep sleep to save the battery
static void ecoCycle() {
  if (oledOk) displayMessage("Low battery", "ECO mode...");
  uint32_t start = millis();
  while (!cloudReady() && millis() - start < 20000) { cloudLoop(); delay(200); }
  readAndEvaluate();
  syncCloud(true);
  if (!ecoMode) return;               // battery recovered (solar), stay awake
  if (cloudReady()) cloudSendEvent(st.mood, "Battery low: ECO mode (deep sleep)");
  Serial.printf("[power] ECO: sleeping %d min\n", ECO_SLEEP_MINUTES);
  if (oledOk) displayOff();
  esp_sleep_enable_timer_wakeup((uint64_t)ECO_SLEEP_MINUTES * 60ULL * 1000000ULL);
  esp_deep_sleep_start();
}

// ---------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== Smart Emoji Plant ===");
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  Wire.begin(PIN_SDA, PIN_SCL);

  oledOk = displayBegin();
  if (!oledOk) Serial.println("[display] SSD1306 not found at 0x3C");
  else displayMessage("Smart Plant", "Starting...");

  sensorsBegin();
  bool wokeFromSleep = esp_sleep_get_wakeup_cause() == ESP_SLEEP_WAKEUP_TIMER;
  voiceBegin(cfg.volume);
  if (!wokeFromSleep) voicePlay(TRACK_HELLO);
  cloudBegin();

  if (oledOk) displayMessage("Connecting Wi-Fi", WIFI_SSID);
  uint32_t start = millis();
  while (!wifiConnected() && millis() - start < 10000) delay(200);
  Serial.printf("[wifi] %s\n", wifiConnected() ? WiFi.localIP().toString().c_str() : "offline (will keep trying)");
  if (wifiConnected()) {
    cloudLoop();                       // sign in to Firebase
    cloudFetchConfig(cfg);
    voiceSetVolume(cfg.volume);
  }

  prevMood = savedMood;
  readAndEvaluate();
  if (ecoMode) ecoCycle();
  syncCloud(true);
  lastSensor = lastUpload = lastHistory = lastScreenSwap = millis();
}

void loop() {
  uint32_t now = millis();
  cloudLoop();
  handleButton();

  if (now - lastSensor >= SENSOR_INTERVAL_MS) {
    lastSensor = now;
    readAndEvaluate();
    // Print the readings to the Serial Monitor (115200 baud) for testing / calibration
    Serial.printf("soil=%d%% (raw %d)  temp=%.1fC  hum=%.0f%%  lux=%.0f  batt=%.2fV %d%%  mood=%s  wifi=%d cloud=%d\n",
                  (int)st.reading.moisture, soilRaw(), st.reading.temperature, st.reading.humidity,
                  st.reading.lux, st.batteryVolts, st.batteryPct, moodName(st.mood), st.wifi, st.cloud);
    if (ecoMode) ecoCycle();
  }

  if (now - lastUpload >= UPLOAD_INTERVAL_MS) {
    lastUpload = now;
    bool history = now - lastHistory >= HISTORY_INTERVAL_MS;
    if (history) lastHistory = now;
    syncCloud(history);
  }

  if (now - lastScreenSwap >= SCREEN_ROTATE_MS) {
    lastScreenSwap = now;
    showFace = !showFace;
  }

  if (oledOk && now - lastFrame >= 200) {      // 5 frames per second
    lastFrame = now;
    frame++;
    if (showFace) displayFace(st, frame);
    else displayData(st);
  }

  // Status LED: solid = connected to Firebase, blinking = offline
  digitalWrite(PIN_LED, cloudReady() ? HIGH : ((now / 500) % 2));
}
