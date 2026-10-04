// =====================================================================
//  Pin map for ESP32 DevKit V1 (30 or 38 pin), see docs/03-wiring.md
// =====================================================================
#pragma once

// Analog inputs: ADC1 pins only (ADC2 cannot be used while Wi-Fi is on)
#define PIN_SOIL        34   // capacitive soil moisture sensor AOUT
#define PIN_BATTERY     35   // battery voltage divider (100k / 100k)
#define PIN_SOLAR       39   // solar panel voltage divider (100k / 47k), "VN"

// Digital
#define PIN_DHT         4    // DHT22 data
#define PIN_BUTTON      13   // push button to GND (internal pull-up)
#define PIN_LED         2    // on-board blue LED (status)

// I2C bus: OLED SSD1306 (0x3C) + BH1750 light sensor (0x23)
#define PIN_SDA         21
#define PIN_SCL         22

// DFPlayer Mini on UART2
#define PIN_DF_RX       16   // ESP32 RX2  <- DFPlayer TX
#define PIN_DF_TX       17   // ESP32 TX2  -> 1k resistor -> DFPlayer RX
