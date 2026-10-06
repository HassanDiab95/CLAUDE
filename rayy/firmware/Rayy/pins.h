// =====================================================================
//  Pin map for ESP32 DevKit V1 (30 or 38 pin), see docs/03-wiring.md
// =====================================================================
#pragma once

// Analog input: ADC1 pin only (ADC2 cannot be used while Wi-Fi is on)
#define PIN_SOIL        34   // capacitive soil moisture sensor AOUT

// Digital
#define PIN_DHT         4    // DHT22 data
#define PIN_BUZZER      25   // passive buzzer (+) through a 100 ohm resistor
#define PIN_BUTTON      13   // push button to GND (internal pull-up)
#define PIN_LED         2    // on-board blue LED (status)

// I2C bus: BH1750 light sensor (0x23)
#define PIN_SDA         21
#define PIN_SCL         22
