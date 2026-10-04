// =====================================================================
//  Wi-Fi + Firebase Realtime Database (REST API over HTTPS)
// =====================================================================
#pragma once
#include "mood.h"
#include "display.h"

void cloudBegin();                 // start Wi-Fi (non blocking) + NTP clock
bool wifiConnected();
bool cloudReady();                 // signed in to Firebase
void cloudLoop();                  // keep Wi-Fi / token alive (call often)
int  localHour();                  // 0..23, or -1 if the clock is not synced

// Uploads (return true on success)
bool cloudSendLive(const Status& s, int soilRaw);
bool cloudSendHistory(const Status& s);
bool cloudSendEvent(Mood mood, const char* message);

// Downloads the config written by the web / Android app.
// Returns true if it was read; cfg is updated in place.
bool cloudFetchConfig(PlantConfig& cfg);

// Returns a melody number requested from the app ("Play sound" button),
// 0 if nothing was requested. The request is deleted after reading.
int cloudFetchCommand();
