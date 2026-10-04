// =====================================================================
//  Mood engine: turns sensor readings into a plant "feeling".
//  Pure C++ (no Arduino calls) so it can be unit-tested on a PC,
//  see tests/test_mood.cpp
// =====================================================================
#pragma once
#include <stdint.h>

enum Mood : uint8_t {
  MOOD_HAPPY = 0,
  MOOD_THIRSTY,      // soil too dry
  MOOD_DROWNING,     // soil too wet
  MOOD_HOT,          // temperature too high
  MOOD_COLD,         // temperature too low
  MOOD_NEED_LIGHT,   // daytime but not enough light
  MOOD_SLEEPY,       // night time, everything OK
  MOOD_COUNT
};

// Buzzer melodies (see sound.cpp). The numbers are also used by the
// "Play sound" button of the web / Android apps.
enum Track : uint8_t {
  TRACK_NONE = 0,
  TRACK_THIRSTY = 1,
  TRACK_DROWNING = 2,
  TRACK_HOT = 3,
  TRACK_COLD = 4,
  TRACK_NEED_LIGHT = 5,
  TRACK_HAPPY = 6,
  TRACK_THANK_YOU = 7,
  TRACK_GOOD_NIGHT = 8,
  TRACK_HELLO = 9,
  TRACK_COUNT
};

struct Reading {
  float moisture;     // %   0..100
  float temperature;  // °C  (NaN if sensor error)
  float humidity;     // %   (NaN if sensor error)
  float lux;          // lux (negative if sensor error)
};

// Thresholds, editable from the web / Android app (Firebase "config")
struct PlantConfig {
  float moistureMin = 30;   // below -> thirsty
  float moistureMax = 85;   // above -> drowning
  float tempMin     = 10;   // below -> cold
  float tempMax     = 35;   // above -> hot
  float luxMin      = 200;  // below during the day -> needs light
  int   dayStart    = 6;    // hour the "day" begins
  int   dayEnd      = 18;   // hour the "day" ends
  int   quietStart  = 22;   // no sound from this hour...
  int   quietEnd    = 7;    // ...until this hour
  int   repeatMin   = 30;   // repeat a complaint every N minutes
  bool  muted       = false;
};

// Small margin so the mood does not flicker around a threshold
static const float HYST_MOISTURE = 5.0f;
static const float HYST_TEMP     = 1.0f;
static const float HYST_LUX      = 50.0f;

const char* moodName(Mood m);      // "happy", "thirsty"... (stored in Firebase)
const char* moodEmoji(Mood m);     // UTF-8 emoji (used in the apps / logs)
bool isHourInRange(int hour, int from, int to);   // handles ranges over midnight

// hour = local hour 0..23, or -1 when the clock is not synced yet
Mood evaluateMood(const Reading& r, const PlantConfig& c, int hour, Mood previous);

// Decide which melody (if any) to play now.
//   newMood/previous : mood now and in the previous evaluation
//   minutesSinceVoice: minutes since the last sound
Track chooseTrack(Mood newMood, Mood previous, uint32_t minutesSinceVoice,
                  int hour, const PlantConfig& c);
