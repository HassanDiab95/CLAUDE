#include "mood.h"
#include <math.h>

const char* moodName(Mood m) {
  switch (m) {
    case MOOD_HAPPY:      return "happy";
    case MOOD_THIRSTY:    return "thirsty";
    case MOOD_DROWNING:   return "drowning";
    case MOOD_HOT:        return "hot";
    case MOOD_COLD:       return "cold";
    case MOOD_NEED_LIGHT: return "need_light";
    case MOOD_SLEEPY:     return "sleepy";
    default:              return "unknown";
  }
}

const char* moodEmoji(Mood m) {
  switch (m) {
    case MOOD_HAPPY:      return "\xF0\x9F\x98\x8A";  // 😊
    case MOOD_THIRSTY:    return "\xF0\x9F\x98\xAB";  // 😫
    case MOOD_DROWNING:   return "\xF0\x9F\xA5\xB4";  // 🥴
    case MOOD_HOT:        return "\xF0\x9F\xA5\xB5";  // 🥵
    case MOOD_COLD:       return "\xF0\x9F\xA5\xB6";  // 🥶
    case MOOD_NEED_LIGHT: return "\xF0\x9F\x98\x9E";  // 😞
    case MOOD_SLEEPY:     return "\xF0\x9F\x98\xB4";  // 😴
    default:              return "?";
  }
}

bool isHourInRange(int hour, int from, int to) {
  if (hour < 0) return false;
  if (from == to) return false;
  if (from < to) return hour >= from && hour < to;
  return hour >= from || hour < to;          // e.g. 22 -> 7 crosses midnight
}

Mood evaluateMood(const Reading& r, const PlantConfig& c, int hour, Mood previous) {
  // While a problem is active, it must improve by the hysteresis margin
  // before we consider it solved.
  float dryLimit  = c.moistureMin + (previous == MOOD_THIRSTY  ? HYST_MOISTURE : 0);
  float wetLimit  = c.moistureMax - (previous == MOOD_DROWNING ? HYST_MOISTURE : 0);
  float hotLimit  = c.tempMax     - (previous == MOOD_HOT      ? HYST_TEMP     : 0);
  float coldLimit = c.tempMin     + (previous == MOOD_COLD     ? HYST_TEMP     : 0);
  float darkLimit = c.luxMin      + (previous == MOOD_NEED_LIGHT ? HYST_LUX    : 0);

  // 1) Water is the most important need
  if (r.moisture < dryLimit) return MOOD_THIRSTY;
  if (r.moisture > wetLimit) return MOOD_DROWNING;

  // 2) Temperature (skip if the sensor failed)
  if (!isnan(r.temperature)) {
    if (r.temperature > hotLimit)  return MOOD_HOT;
    if (r.temperature < coldLimit) return MOOD_COLD;
  }

  // 3) Light depends on day / night
  bool lightOk = r.lux >= 0;
  if (hour >= 0) {
    bool day = isHourInRange(hour, c.dayStart, c.dayEnd);
    if (!day) return MOOD_SLEEPY;
    if (lightOk && r.lux < darkLimit) return MOOD_NEED_LIGHT;
    return MOOD_HAPPY;
  }
  // Clock not synced yet (no internet): use darkness as "night"
  if (lightOk && r.lux < 10) return MOOD_SLEEPY;
  return MOOD_HAPPY;
}

static Track complaintTrack(Mood m) {
  switch (m) {
    case MOOD_THIRSTY:    return TRACK_THIRSTY;
    case MOOD_DROWNING:   return TRACK_DROWNING;
    case MOOD_HOT:        return TRACK_HOT;
    case MOOD_COLD:       return TRACK_COLD;
    case MOOD_NEED_LIGHT: return TRACK_NEED_LIGHT;
    default:              return TRACK_NONE;
  }
}

Track chooseTrack(Mood newMood, Mood previous, uint32_t minutesSinceVoice,
                  int hour, const PlantConfig& c) {
  if (c.muted) return TRACK_NONE;
  if (isHourInRange(hour, c.quietStart, c.quietEnd)) return TRACK_NONE;

  bool changed = newMood != previous;

  if (changed) {
    if (newMood == MOOD_HAPPY) {
      // Say "thank you" after being watered, otherwise "I'm happy"
      return previous == MOOD_THIRSTY ? TRACK_THANK_YOU : TRACK_HAPPY;
    }
    if (newMood == MOOD_SLEEPY) return TRACK_GOOD_NIGHT;
    return complaintTrack(newMood);
  }

  // Same mood: repeat complaints from time to time so nobody forgets
  Track t = complaintTrack(newMood);
  if (t != TRACK_NONE && minutesSinceVoice >= (uint32_t)c.repeatMin) return t;
  return TRACK_NONE;
}
