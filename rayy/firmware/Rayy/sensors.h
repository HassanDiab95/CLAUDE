// =====================================================================
//  Sensors: capacitive soil moisture, DHT22 (temp + humidity), BH1750 (light)
// =====================================================================
#pragma once
#include "mood.h"

void sensorsBegin();
void sensorsRead(Reading& r);   // fills moisture, temperature, humidity, lux
int  soilRaw();                 // last raw ADC value (for calibration)
