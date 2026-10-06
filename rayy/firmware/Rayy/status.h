// =====================================================================
//  Current state of the plant, shared by the main program and the cloud
//  upload. (There is no screen: the emoji face is shown in the web
//  dashboard and the Android app.)
// =====================================================================
#pragma once
#include "mood.h"

struct Status {
  Reading reading;
  Mood    mood;
  bool    wifi;
  bool    cloud;
  bool    muted;
};
