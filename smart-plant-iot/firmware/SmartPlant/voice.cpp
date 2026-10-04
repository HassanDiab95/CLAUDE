#include <Arduino.h>
#include <DFRobotDFPlayerMini.h>
#include "pins.h"
#include "voice.h"

static HardwareSerial      dfSerial(2);    // UART2
static DFRobotDFPlayerMini player;
static bool ready = false;
static int  currentVolume = -1;

bool voiceBegin(int volume) {
  dfSerial.begin(9600, SERIAL_8N1, PIN_DF_RX, PIN_DF_TX);
  delay(500);                                // DFPlayer needs time after power-up
  ready = player.begin(dfSerial, true, true);
  if (!ready) {
    Serial.println("[voice] DFPlayer not found (check wiring / SD card)");
    return false;
  }
  voiceSetVolume(volume);
  return true;
}

void voiceSetVolume(int volume) {
  volume = constrain(volume, 0, 30);
  if (!ready || volume == currentVolume) return;
  player.volume(volume);
  currentVolume = volume;
}

void voicePlay(Track t) {
  if (!ready || t == TRACK_NONE) return;
  Serial.printf("[voice] playing /mp3/%04d.mp3\n", (int)t);
  player.playMp3Folder((int)t);              // plays /mp3/000t.mp3
}
