// =====================================================================
//  Sound alerts with a passive buzzer: a different melody for every mood.
//  The melody plays in the background (non-blocking), so the emoji
//  animation keeps running while the plant "sings".
// =====================================================================
#pragma once
#include "mood.h"

void soundBegin();
void soundPlay(Track t);   // start a melody (replaces the one playing)
void soundLoop();          // call often from loop()
bool soundBusy();
