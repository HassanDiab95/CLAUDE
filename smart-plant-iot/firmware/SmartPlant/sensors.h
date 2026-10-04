// =====================================================================
//  Sensors: soil moisture, DHT22, BH1750, battery + solar voltage
// =====================================================================
#pragma once
#include "mood.h"

void  sensorsBegin();
void  sensorsRead(Reading& r);   // fills moisture, temperature, humidity, lux
int   soilRaw();                 // last raw ADC value (for calibration)
float batteryVolts();
float solarVolts();
int   batteryPercent(float volts);
