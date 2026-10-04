// =====================================================================
//  RAYY (ري): a smart IoT plant that shows its feelings with
//  emoji faces (OLED) and sound alerts (buzzer melodies).
//
//  Board  : ESP32 Dev Module (ESP32 DevKit V1), powered by a 5 V USB
//           power bank or a 5 V USB phone charger
//  Core   : esp32 by Espressif Systems 3.x (Arduino IDE Boards Manager)
//  Libs   : Adafruit SSD1306, Adafruit GFX, DHT sensor library,
//           Adafruit Unified Sensor, BH1750 (Christopher Laws), ArduinoJson 7
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
#include "sound.h"
#include "cloud.h"

static PlantConfig cfg;
static Status      st;
static Mood        prevMood = MOOD_HAPPY;
static bool        firstEvaluation = true;

static uint32_t lastSensor = 0, lastUpload = 0, lastHistory = 0, lastFrame = 0;
static uint32_t lastScreenSwap = 0, lastSound = 0, frame = 0;
static bool     showFace = true;
static bool     oledOk = false;
static bool     pendingEvent = false;   // mood changed, event not uploaded yet

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

static void readAndEvaluate() {
  sensorsRead(st.reading);
  int hour = localHour();
  Mood m = evaluateMood(st.reading, cfg, hour, prevMood);
  st.mood = m;
  st.wifi = wifiConnected();
  st.cloud = cloudReady();
  st.muted = cfg.muted;

  if (firstEvaluation) {              // first reading after power-on
    firstEvaluation = false;
    pendingEvent = true;
    prevMood = m;
    return;
  }

  uint32_t minutesSinceSound = (millis() - lastSound) / 60000UL;
  Track t = chooseTrack(m, prevMood, minutesSinceSound, hour, cfg);
  if (t != TRACK_NONE) { soundPlay(t); lastSound = millis(); }

  if (m != prevMood) {
    Serial.printf("[mood] %s -> %s\n", moodName(prevMood), moodName(m));
    pendingEvent = true;
    showFace = true;                  // show the new face immediately
    lastScreenSwap = millis();
  }
  prevMood = m;
}

static void syncCloud(bool withHistory) {
  if (!cloudReady()) return;
  cloudFetchConfig(cfg);
  cloudSendLive(st, soilRaw());
  if (pendingEvent && cloudSendEvent(st.mood, moodMessage(st.mood))) pendingEvent = false;
  if (withHistory) cloudSendHistory(st);
  int cmd = cloudFetchCommand();
  if (cmd > 0) { soundPlay((Track)cmd); lastSound = millis(); }
}

// Short press: switch screen. Long press (>1 s): play the current mood sound.
static void handleButton() {
  static bool wasDown = false;
  static uint32_t downAt = 0;
  bool down = digitalRead(PIN_BUTTON) == LOW;
  if (down && !wasDown) downAt = millis();
  if (!down && wasDown) {
    uint32_t held = millis() - downAt;
    if (held > 1000) { soundPlay(trackForMood(st.mood)); lastSound = millis(); }
    else if (held > 40) { showFace = !showFace; lastScreenSwap = millis(); }
  }
  wasDown = down;
}

// ---------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== Rayy (ري) smart plant ===");
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  Wire.begin(PIN_SDA, PIN_SCL);

  oledOk = displayBegin();
  if (!oledOk) Serial.println("[display] SSD1306 not found at 0x3C");
  else displayMessage("Rayy", "Starting...");

  sensorsBegin();
  soundBegin();
  soundPlay(TRACK_HELLO);
  cloudBegin();

  if (oledOk) displayMessage("Connecting Wi-Fi", WIFI_SSID);
  uint32_t start = millis();
  while (!wifiConnected() && millis() - start < 10000) { soundLoop(); delay(20); }
  Serial.printf("[wifi] %s\n", wifiConnected() ? WiFi.localIP().toString().c_str() : "offline (will keep trying)");
  if (wifiConnected()) {
    cloudLoop();                       // sign in to Firebase
    cloudFetchConfig(cfg);
  }

  readAndEvaluate();
  syncCloud(true);
  lastSensor = lastUpload = lastHistory = lastScreenSwap = millis();
}

void loop() {
  uint32_t now = millis();
  soundLoop();
  cloudLoop();
  handleButton();

  if (now - lastSensor >= SENSOR_INTERVAL_MS) {
    lastSensor = now;
    readAndEvaluate();
    // Print the readings to the Serial Monitor (115200 baud) for testing / calibration
    Serial.printf("soil=%d%% (raw %d)  temp=%.1fC  hum=%.0f%%  lux=%.0f  mood=%s  wifi=%d cloud=%d\n",
                  (int)st.reading.moisture, soilRaw(), st.reading.temperature, st.reading.humidity,
                  st.reading.lux, moodName(st.mood), st.wifi, st.cloud);
  }

  // Cloud sync waits until a melody has finished (HTTPS requests take ~1 s)
  if (now - lastUpload >= UPLOAD_INTERVAL_MS && !soundBusy()) {
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
