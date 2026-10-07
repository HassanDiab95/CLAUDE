// =====================================================================
//  Solar power system: battery level and solar panel voltage
//  (see docs/11-solar-power.md)
// =====================================================================
#pragma once

struct PowerReading {
  bool  enabled;      // false when SOLAR_ENABLED is 0 (USB power bank)
  float batteryV;     // 18650 battery voltage (V)
  int   batteryPct;   // 0..100 %
  float solarV;       // solar panel voltage (V), 0 at night
  bool  charging;     // the panel is charging the battery
  bool  lowBattery;   // battery-saving mode is active
};

void powerBegin();
void powerRead(PowerReading& p);
