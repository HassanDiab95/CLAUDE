#include <Arduino.h>
#include "config.h"
#include "pins.h"
#include "power.h"
#include "power_calc.h"

// Average several ADC samples. analogReadMilliVolts() uses the factory
// calibration of the ESP32 ADC, so the result is already in millivolts.
static float readVolts(int pin, float dividerRatio) {
  uint32_t sum = 0;
  for (int i = 0; i < 16; i++) sum += analogReadMilliVolts(pin);
  return (sum / 16.0f) / 1000.0f * dividerRatio;
}

void powerBegin() {
#if SOLAR_ENABLED
  analogSetPinAttenuation(PIN_BATTERY, ADC_11db);   // 0..~3.1 V input range
  analogSetPinAttenuation(PIN_SOLAR, ADC_11db);
#endif
}

void powerRead(PowerReading& p) {
#if SOLAR_ENABLED
  p.enabled    = true;
  p.batteryV   = readVolts(PIN_BATTERY, BATTERY_DIVIDER);
  p.solarV     = readVolts(PIN_SOLAR, SOLAR_DIVIDER);
  if (p.solarV < 0.3f) p.solarV = 0;                // night / panel disconnected
  p.batteryPct = batteryPercentFromVolts(p.batteryV);
  p.charging   = solarIsCharging(p.solarV, p.batteryV);
  p.lowBattery = lowPowerMode(p.batteryPct, LOW_BATTERY_PCT, p.lowBattery);
#else
  p = PowerReading{};                               // power bank: nothing to measure
#endif
}
