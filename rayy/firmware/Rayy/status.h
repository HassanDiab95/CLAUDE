// =====================================================================
//  Current state of the plant, shared by the main program and the cloud
//  upload. (There is no screen: the emoji face is shown in the web
//  dashboard and the Android app.)
// =====================================================================
#pragma once
#include "mood.h"
#include "power.h"

struct Status {
  Reading reading;
  PowerReading power;   // solar panel + battery (power.enabled = false on a power bank)
  Mood    mood;
  bool    wifi;
  bool    cloud;
  bool    muted;
};
