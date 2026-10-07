// Unit tests for the mood engine and the solar battery calculations, run on a PC (no ESP32 needed):
//   g++ -std=c++17 -I../firmware/Rayy test_mood.cpp ../firmware/Rayy/mood.cpp -o test_mood && ./test_mood
#include <cmath>
#include <cstdio>
#include "mood.h"
#include "power_calc.h"

static int failures = 0, checks = 0;
#define CHECK(cond) do { checks++; if (!(cond)) { failures++; std::printf("FAIL line %d: %s\n", __LINE__, #cond); } } while (0)

static Reading R(float m, float t, float lux) { return Reading{m, t, 40, lux}; }

int main() {
  PlantConfig c;   // defaults: moisture 30..85, temp 10..35, lux 200, day 6..18

  // --- basic moods during the day (12:00) ---
  CHECK(evaluateMood(R(50, 25, 1000), c, 12, MOOD_HAPPY) == MOOD_HAPPY);
  CHECK(evaluateMood(R(20, 25, 1000), c, 12, MOOD_HAPPY) == MOOD_THIRSTY);
  CHECK(evaluateMood(R(95, 25, 1000), c, 12, MOOD_HAPPY) == MOOD_DROWNING);
  CHECK(evaluateMood(R(50, 40, 1000), c, 12, MOOD_HAPPY) == MOOD_HOT);
  CHECK(evaluateMood(R(50, 5, 1000),  c, 12, MOOD_HAPPY) == MOOD_COLD);
  CHECK(evaluateMood(R(50, 25, 50),   c, 12, MOOD_HAPPY) == MOOD_NEED_LIGHT);

  // --- priorities: water before temperature before light ---
  CHECK(evaluateMood(R(10, 45, 10), c, 12, MOOD_HAPPY) == MOOD_THIRSTY);
  CHECK(evaluateMood(R(50, 45, 10), c, 12, MOOD_HAPPY) == MOOD_HOT);

  // --- night ---
  CHECK(evaluateMood(R(50, 25, 0), c, 23, MOOD_HAPPY) == MOOD_SLEEPY);
  CHECK(evaluateMood(R(20, 25, 0), c, 23, MOOD_HAPPY) == MOOD_THIRSTY);  // still complains

  // --- hysteresis: watering from 29% to 32% is not enough to stop "thirsty" ---
  CHECK(evaluateMood(R(32, 25, 1000), c, 12, MOOD_THIRSTY) == MOOD_THIRSTY);
  CHECK(evaluateMood(R(36, 25, 1000), c, 12, MOOD_THIRSTY) == MOOD_HAPPY);
  CHECK(evaluateMood(R(50, 34.5f, 1000), c, 12, MOOD_HOT) == MOOD_HOT);
  CHECK(evaluateMood(R(50, 33.5f, 1000), c, 12, MOOD_HOT) == MOOD_HAPPY);

  // --- broken sensors ---
  CHECK(evaluateMood(R(50, NAN, 1000), c, 12, MOOD_HAPPY) == MOOD_HAPPY);
  CHECK(evaluateMood(R(50, 25, -1), c, 12, MOOD_HAPPY) == MOOD_HAPPY);

  // --- clock not synced (hour = -1) ---
  CHECK(evaluateMood(R(50, 25, 2), c, -1, MOOD_HAPPY) == MOOD_SLEEPY);
  CHECK(evaluateMood(R(50, 25, 500), c, -1, MOOD_HAPPY) == MOOD_HAPPY);

  // --- hour ranges ---
  CHECK(isHourInRange(23, 22, 7));
  CHECK(isHourInRange(3, 22, 7));
  CHECK(!isHourInRange(12, 22, 7));
  CHECK(isHourInRange(6, 6, 18));
  CHECK(!isHourInRange(18, 6, 18));
  CHECK(!isHourInRange(-1, 6, 18));

  // --- voice decisions ---
  CHECK(chooseTrack(MOOD_THIRSTY, MOOD_HAPPY, 0, 12, c) == TRACK_THIRSTY);
  CHECK(chooseTrack(MOOD_HAPPY, MOOD_THIRSTY, 0, 12, c) == TRACK_THANK_YOU);
  CHECK(chooseTrack(MOOD_HAPPY, MOOD_HOT, 0, 12, c) == TRACK_HAPPY);
  CHECK(chooseTrack(MOOD_SLEEPY, MOOD_HAPPY, 0, 20, c) == TRACK_GOOD_NIGHT);
  CHECK(chooseTrack(MOOD_HAPPY, MOOD_HAPPY, 999, 12, c) == TRACK_NONE);       // no spam
  CHECK(chooseTrack(MOOD_THIRSTY, MOOD_THIRSTY, 10, 12, c) == TRACK_NONE);    // too soon
  CHECK(chooseTrack(MOOD_THIRSTY, MOOD_THIRSTY, 30, 12, c) == TRACK_THIRSTY); // reminder
  CHECK(chooseTrack(MOOD_THIRSTY, MOOD_HAPPY, 0, 23, c) == TRACK_NONE);       // quiet hours
  PlantConfig muted = c; muted.muted = true;
  CHECK(chooseTrack(MOOD_THIRSTY, MOOD_HAPPY, 0, 12, muted) == TRACK_NONE);

  // --- solar part: battery level, charging, saving mode ---
  CHECK(batteryPercentFromVolts(4.25f) == 100);
  CHECK(batteryPercentFromVolts(4.20f) == 100);
  CHECK(batteryPercentFromVolts(3.70f) == 35);
  CHECK(batteryPercentFromVolts(3.75f) == 45);
  CHECK(batteryPercentFromVolts(3.30f) == 0);
  CHECK(batteryPercentFromVolts(2.90f) == 0);
  CHECK(batteryPercentFromVolts(NAN) == 0);
  CHECK(solarIsCharging(6.0f, 3.8f));
  CHECK(!solarIsCharging(4.0f, 3.8f));          // weak light
  CHECK(!solarIsCharging(0.0f, 3.8f));          // night
  CHECK(lowPowerMode(10, 15, false));
  CHECK(!lowPowerMode(20, 15, false));
  CHECK(lowPowerMode(20, 15, true));            // hysteresis: stay saving until 25 %
  CHECK(!lowPowerMode(26, 15, true));

  std::printf("%d checks, %d failures\n", checks, failures);
  return failures == 0 ? 0 : 1;
}
