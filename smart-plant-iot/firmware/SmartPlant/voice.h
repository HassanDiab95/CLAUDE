// =====================================================================
//  Voice messages with the DFPlayer Mini (MP3 files on a micro-SD card)
// =====================================================================
#pragma once
#include "mood.h"

bool voiceBegin(int volume);     // false if the DFPlayer / SD card is missing
void voiceSetVolume(int volume); // 0..30
void voicePlay(Track t);
