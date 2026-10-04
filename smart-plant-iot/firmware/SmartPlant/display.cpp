#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "display.h"

static Adafruit_SSD1306 oled(128, 64, &Wire, -1);

// Face geometry (128 x 64 screen, 10 px status bar on top)
static const int FX = 64;   // face centre x
static const int FY = 37;   // face centre y
static const int FR = 26;   // face radius

// ---------------------------------------------------------------------
//  Small drawing helpers
// ---------------------------------------------------------------------
// Thick arc from a0 to a1 degrees (0 = right, 90 = down)
static void arc(int cx, int cy, int r, int a0, int a1, int thick = 2) {
  for (int a = a0; a <= a1; a += 3) {
    float rad = a * DEG_TO_RAD;
    for (int t = 0; t < thick; t++) {
      oled.drawPixel(cx + (r - t) * cos(rad), cy + (r - t) * sin(rad), SSD1306_WHITE);
    }
  }
}

static void drop(int x, int y) {            // water / sweat drop
  oled.fillTriangle(x, y - 5, x - 3, y, x + 3, y, SSD1306_WHITE);
  oled.fillCircle(x, y + 1, 3, SSD1306_WHITE);
}

static void openEyes(bool blink) {
  if (blink) {
    oled.fillRect(FX - 14, FY - 8, 9, 2, SSD1306_WHITE);
    oled.fillRect(FX + 5,  FY - 8, 9, 2, SSD1306_WHITE);
  } else {
    oled.fillCircle(FX - 10, FY - 8, 4, SSD1306_WHITE);
    oled.fillCircle(FX + 10, FY - 8, 4, SSD1306_WHITE);
    oled.fillCircle(FX - 9,  FY - 9, 1, SSD1306_BLACK);   // eye shine
    oled.fillCircle(FX + 11, FY - 9, 1, SSD1306_BLACK);
  }
}

static void xEyes() {
  for (int s = -1; s <= 1; s += 2) {
    int ex = FX + s * 10, ey = FY - 8;
    oled.drawLine(ex - 4, ey - 4, ex + 4, ey + 4, SSD1306_WHITE);
    oled.drawLine(ex - 4, ey + 4, ex + 4, ey - 4, SSD1306_WHITE);
  }
}

static void sadEyes() {
  oled.fillCircle(FX - 10, FY - 6, 3, SSD1306_WHITE);
  oled.fillCircle(FX + 10, FY - 6, 3, SSD1306_WHITE);
  oled.drawLine(FX - 16, FY - 12, FX - 6, FY - 15, SSD1306_WHITE);  // eyebrows
  oled.drawLine(FX + 16, FY - 12, FX + 6, FY - 15, SSD1306_WHITE);
}

static void wavyMouth(int y, int phase) {
  for (int x = -12; x < 12; x++) {
    int yy = y + (int)(2.5f * sin((x + phase) * 0.8f));
    oled.drawPixel(FX + x, yy, SSD1306_WHITE);
    oled.drawPixel(FX + x, yy + 1, SSD1306_WHITE);
  }
}

static void statusBar(const Status& s) {
  oled.setTextSize(1);
  oled.setTextColor(SSD1306_WHITE);
  oled.setCursor(0, 0);
  oled.printf("%d%%", (int)s.reading.moisture);
  if (!isnan(s.reading.temperature)) {
    oled.setCursor(30, 0);
    oled.printf("%dC", (int)roundf(s.reading.temperature));
  }
  // Wi-Fi / cloud indicator
  oled.setCursor(62, 0);
  oled.print(s.cloud ? "IoT" : (s.wifi ? "W" : "--"));
  if (s.muted) { oled.setCursor(84, 0); oled.print("M"); }
  // battery icon
  int bx = 104, w = 20;
  oled.drawRect(bx, 0, w, 8, SSD1306_WHITE);
  oled.fillRect(bx + w, 2, 2, 4, SSD1306_WHITE);
  int fill = constrain(s.batteryPct, 0, 100) * (w - 4) / 100;
  oled.fillRect(bx + 2, 2, fill, 4, SSD1306_WHITE);
  if (s.charging) { oled.setCursor(bx - 8, 0); oled.print("+"); }
}

// ---------------------------------------------------------------------
bool displayBegin() {
  if (!oled.begin(SSD1306_SWITCHCAPVCC, 0x3C)) return false;
  oled.clearDisplay();
  oled.display();
  return true;
}

void displayFace(const Status& s, uint32_t frame) {
  oled.clearDisplay();
  statusBar(s);
  oled.drawCircle(FX, FY, FR, SSD1306_WHITE);
  oled.drawCircle(FX, FY, FR - 1, SSD1306_WHITE);

  bool blink = (frame % 25) == 0;      // blink once every ~5 s
  int  wob   = (frame % 4) < 2 ? 0 : 1;  // little wobble for animations

  switch (s.mood) {
    case MOOD_HAPPY:
      openEyes(blink);
      arc(FX, FY + 2, 13, 20, 160, 2);                 // smile
      oled.drawCircle(FX - 17, FY + 4, 3, SSD1306_WHITE);  // cheeks
      oled.drawCircle(FX + 17, FY + 4, 3, SSD1306_WHITE);
      // little leaf on the head
      oled.fillTriangle(FX, FY - FR, FX + 10, FY - FR - 6, FX + 4, FY - FR - 1, SSD1306_WHITE);
      break;

    case MOOD_THIRSTY:
      sadEyes();
      oled.fillRoundRect(FX - 8, FY + 6, 16, 9, 3, SSD1306_WHITE);   // open mouth
      oled.fillRoundRect(FX - 3, FY + 11, 6, 7 + wob, 2, SSD1306_BLACK); // tongue
      oled.drawRoundRect(FX - 3, FY + 11, 6, 7 + wob, 2, SSD1306_WHITE);
      drop(16, 30 + (frame % 10) * 2);                 // falling drop
      oled.setCursor(4, 54); oled.print("WATER!");
      break;

    case MOOD_DROWNING:
      xEyes();
      wavyMouth(FY + 10, frame);
      drop(108, 24); drop(116, 38); drop(104, 50);
      oled.setCursor(0, 54); oled.print("Too wet");
      break;

    case MOOD_HOT:
      oled.drawLine(FX - 14, FY - 8, FX - 6, FY - 6, SSD1306_WHITE);
      oled.drawLine(FX + 14, FY - 8, FX + 6, FY - 6, SSD1306_WHITE);
      oled.fillCircle(FX, FY + 9, 6, SSD1306_WHITE);                  // panting
      drop(FX + FR - 4, FY - 14 + wob * 3);                           // sweat
      // sun
      oled.drawCircle(14, 24, 6, SSD1306_WHITE);
      for (int a = 0; a < 360; a += 45) {
        float r = a * DEG_TO_RAD;
        oled.drawLine(14 + 8 * cos(r), 24 + 8 * sin(r), 14 + 11 * cos(r), 24 + 11 * sin(r), SSD1306_WHITE);
      }
      break;

    case MOOD_COLD:
      oled.fillCircle(FX - 10 + wob, FY - 8, 3, SSD1306_WHITE);
      oled.fillCircle(FX + 10 + wob, FY - 8, 3, SSD1306_WHITE);
      for (int i = 0; i < 6; i++) {                                   // zig-zag teeth
        int x = FX - 12 + i * 4 + wob;
        oled.drawLine(x, FY + 8, x + 2, FY + 12, SSD1306_WHITE);
        oled.drawLine(x + 2, FY + 12, x + 4, FY + 8, SSD1306_WHITE);
      }
      // snowflake
      for (int a = 0; a < 180; a += 60) {
        float r = a * DEG_TO_RAD;
        oled.drawLine(112 - 8 * cos(r), 28 - 8 * sin(r), 112 + 8 * cos(r), 28 + 8 * sin(r), SSD1306_WHITE);
      }
      break;

    case MOOD_NEED_LIGHT:
      sadEyes();
      arc(FX, FY + 20, 10, 210, 330, 2);                              // frown
      // light bulb
      oled.drawCircle(14, 28, 7, SSD1306_WHITE);
      oled.drawRect(11, 35, 7, 5, SSD1306_WHITE);
      oled.setCursor(2, 54); oled.print("Light?");
      break;

    case MOOD_SLEEPY:
      oled.drawLine(FX - 14, FY - 7, FX - 6, FY - 7, SSD1306_WHITE);
      oled.drawLine(FX + 6,  FY - 7, FX + 14, FY - 7, SSD1306_WHITE);
      oled.drawCircle(FX, FY + 10, 3, SSD1306_WHITE);
      oled.setCursor(98, 34 - (frame % 8)); oled.print("z");
      oled.setCursor(106, 26 - (frame % 8)); oled.print("Z");
      break;

    default:
      break;
  }
  oled.display();
}

void displayData(const Status& s) {
  oled.clearDisplay();
  statusBar(s);
  oled.setTextSize(1);
  oled.setCursor(0, 14);
  oled.printf("Soil  : %3d %%\n", (int)s.reading.moisture);
  if (isnan(s.reading.temperature)) oled.print("Temp  : --\n");
  else oled.printf("Temp  : %.1f C\n", s.reading.temperature);
  if (isnan(s.reading.humidity)) oled.print("Humid : --\n");
  else oled.printf("Humid : %3d %%\n", (int)s.reading.humidity);
  if (s.reading.lux < 0) oled.print("Light : --\n");
  else oled.printf("Light : %d lx\n", (int)s.reading.lux);
  oled.printf("Batt  : %.2fV %d%%\n", s.batteryVolts, s.batteryPct);
  oled.printf("Mood  : %s", moodName(s.mood));
  oled.display();
}

void displayMessage(const char* line1, const char* line2) {
  oled.clearDisplay();
  oled.setTextSize(1);
  oled.setTextColor(SSD1306_WHITE);
  oled.setCursor(0, 20); oled.print(line1);
  oled.setCursor(0, 36); oled.print(line2);
  oled.display();
}

void displayOff() {
  oled.clearDisplay();
  oled.display();
  oled.ssd1306_command(SSD1306_DISPLAYOFF);
}
