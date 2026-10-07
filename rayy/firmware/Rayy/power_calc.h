// =====================================================================
//  Solar / battery calculations (pure functions, no Arduino code, so
//  they can also be unit-tested on a PC, see tests/test_mood.cpp)
// =====================================================================
#pragma once

// Li-ion 18650 cell: open-circuit voltage -> state of charge (%).
// Approximate curve, good enough for a "battery level" display.
inline int batteryPercentFromVolts(float v) {
  static const float VOLTS[] = {3.30f, 3.50f, 3.60f, 3.70f, 3.80f, 3.90f, 4.00f, 4.10f, 4.20f};
  static const int   PCT[]   = {0,     5,     15,    35,    55,    70,    82,    93,    100};
  const int n = sizeof(VOLTS) / sizeof(VOLTS[0]);
  if (!(v > VOLTS[0])) return 0;               // also catches NaN
  if (v >= VOLTS[n - 1]) return 100;
  for (int i = 1; i < n; i++) {
    if (v < VOLTS[i]) {
      float f = (v - VOLTS[i - 1]) / (VOLTS[i] - VOLTS[i - 1]);
      return (int)(PCT[i - 1] + f * (PCT[i] - PCT[i - 1]) + 0.5f);
    }
  }
  return 100;
}

// The panel is charging the battery when its voltage is clearly above
// the battery voltage (the MPPT charger needs some headroom).
inline bool solarIsCharging(float solarV, float batteryV) {
  return solarV > 4.5f && solarV > batteryV + 0.6f;
}

// Battery-saving mode thresholds with hysteresis: enter below lowPct,
// leave only when the battery is back above lowPct + 10.
inline bool lowPowerMode(int pct, int lowPct, bool wasLow) {
  return wasLow ? pct < lowPct + 10 : pct < lowPct;
}
