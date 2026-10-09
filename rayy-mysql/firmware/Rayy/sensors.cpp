#include <Arduino.h>
#include <Wire.h>
#include <DHT.h>
#include <BH1750.h>
#include "config.h"
#include "pins.h"
#include "sensors.h"

static DHT    dht(PIN_DHT, DHT22);
static BH1750 lightMeter(0x23);
static bool   lightOk = false;
static int    lastSoilRaw = 0;

// Average several ADC samples to reduce noise
static int readAverage(int pin, int samples = 16) {
  long sum = 0;
  for (int i = 0; i < samples; i++) { sum += analogRead(pin); delay(2); }
  return sum / samples;
}

void sensorsBegin() {
  analogReadResolution(12);
  analogSetPinAttenuation(PIN_SOIL, ADC_11db);      // full 0..3.3 V range
  dht.begin();
  lightOk = lightMeter.begin(BH1750::CONTINUOUS_HIGH_RES_MODE, 0x23, &Wire);
  if (!lightOk) Serial.println("[sensors] BH1750 not found, check wiring");
}

void sensorsRead(Reading& r) {
  // Soil: high raw value = dry, low raw value = wet
  lastSoilRaw = readAverage(PIN_SOIL);
  float pct = (float)(SOIL_RAW_DRY - lastSoilRaw) * 100.0f / (SOIL_RAW_DRY - SOIL_RAW_WET);
  r.moisture = constrain(pct, 0.0f, 100.0f);

  r.temperature = dht.readTemperature();   // NaN on error
  r.humidity    = dht.readHumidity();

  r.lux = lightOk ? lightMeter.readLightLevel() : -1;   // negative on error
}

int soilRaw() { return lastSoilRaw; }
