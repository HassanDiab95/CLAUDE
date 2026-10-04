// =====================================================================
//  OLED display: animated emoji faces + data screen
// =====================================================================
#pragma once
#include "mood.h"

struct Status {
  Reading reading;
  Mood    mood;
  float   batteryVolts;
  int     batteryPct;
  bool    charging;
  bool    wifi;
  bool    cloud;
  bool    muted;
};

bool displayBegin();                       // false if the OLED is not found
void displayFace(const Status& s, uint32_t frame);  // big emoji face
void displayData(const Status& s);         // numbers screen
void displayMessage(const char* line1, const char* line2);
void displayOff();
