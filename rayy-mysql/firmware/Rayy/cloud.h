// =====================================================================
//  Wi-Fi + the Rayy server (XAMPP: Apache + PHP + MySQL)
//  One HTTP request every 30 s sends the data and receives the settings
//  and the "Play" command (see server/rayy/api/device.php).
// =====================================================================
#pragma once
#include "mood.h"
#include "status.h"

void cloudBegin();                 // start Wi-Fi (non blocking) + NTP clock
bool wifiConnected();
bool cloudReady();                 // Wi-Fi on and the last server request worked
void cloudLoop();                  // keep Wi-Fi alive (call often)
int  localHour();                  // 0..23 (internet time, or the server's clock), -1 if unknown

// Sends the live values to the server. withHistory = also save a history
// point; eventMessage = mood changed (diary text), or nullptr.
// cfg is updated with the settings from the database.
// Returns true on success; *playTrack = melody requested from the apps (0 = none).
bool cloudSync(const Status& s, int soilRaw, bool withHistory, const char* eventMessage,
               PlantConfig& cfg, int* playTrack);
