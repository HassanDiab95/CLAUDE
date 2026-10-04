#include <Arduino.h>
#include "pins.h"
#include "sound.h"

// Note frequencies (Hz)
#define C5 523
#define D5 587
#define E5 659
#define F5 698
#define G5 784
#define A5 880
#define B5 988
#define C6 1047
#define E6 1319
#define G6 1568
#define C4 262
#define E4 330
#define G4 392
#define A4 440
#define REST 0

struct Note { uint16_t freq; uint16_t ms; };

// Each melody ends with {0, 0}
static const Note M_THIRSTY[]    = {{A5,150},{REST,60},{A5,150},{REST,60},{E5,150},{REST,60},{C5,400},{0,0}};       // sad "help!"
static const Note M_DROWNING[]   = {{G5,90},{E5,90},{G5,90},{E5,90},{G5,90},{E5,90},{C5,300},{0,0}};                // bubbling
static const Note M_HOT[]        = {{C6,120},{REST,80},{C6,120},{REST,80},{C6,120},{REST,80},{G5,300},{0,0}};       // alarm beeps
static const Note M_COLD[]       = {{E5,60},{D5,60},{E5,60},{D5,60},{E5,60},{D5,60},{E5,60},{D5,60},{C5,250},{0,0}}; // shivering
static const Note M_NEED_LIGHT[] = {{C5,250},{E5,250},{G5,250},{REST,80},{G4,400},{0,0}};                           // "where is the sun?"
static const Note M_HAPPY[]      = {{C5,120},{E5,120},{G5,120},{C6,300},{0,0}};                                     // happy arpeggio
static const Note M_THANK_YOU[]  = {{G5,120},{C6,120},{E6,120},{G6,200},{REST,60},{E6,120},{G6,350},{0,0}};         // joyful
static const Note M_GOOD_NIGHT[] = {{G5,300},{E5,300},{C5,300},{G4,600},{0,0}};                                     // lullaby
static const Note M_HELLO[]      = {{C5,100},{G5,100},{C6,250},{0,0}};                                              // start-up

static const Note* melodyFor(Track t) {
  switch (t) {
    case TRACK_THIRSTY:    return M_THIRSTY;
    case TRACK_DROWNING:   return M_DROWNING;
    case TRACK_HOT:        return M_HOT;
    case TRACK_COLD:       return M_COLD;
    case TRACK_NEED_LIGHT: return M_NEED_LIGHT;
    case TRACK_HAPPY:      return M_HAPPY;
    case TRACK_THANK_YOU:  return M_THANK_YOU;
    case TRACK_GOOD_NIGHT: return M_GOOD_NIGHT;
    case TRACK_HELLO:      return M_HELLO;
    default:               return nullptr;
  }
}

static const Note* current = nullptr;   // melody being played
static int      noteIndex = 0;              // current note
static uint32_t noteStart = 0;
static int      repeatsLeft = 0;        // complaints are played twice
static uint32_t pauseUntil = 0;         // short silence between repeats

static void startNote() {
  const Note& n = current[noteIndex];
  ledcWriteTone(PIN_BUZZER, n.freq);    // frequency 0 = silence
  noteStart = millis();
}

void soundBegin() {
  ledcAttach(PIN_BUZZER, 2000, 10);     // PWM channel for the buzzer (core 3.x API)
  ledcWriteTone(PIN_BUZZER, 0);
}

void soundPlay(Track t) {
  const Note* m = melodyFor(t);
  if (!m) return;
  Serial.printf("[sound] melody %d\n", (int)t);
  current = m;
  noteIndex = 0;
  repeatsLeft = (t <= TRACK_NEED_LIGHT) ? 1 : 0;   // repeat complaints once
  pauseUntil = 0;
  startNote();
}

void soundLoop() {
  if (!current) return;
  if (pauseUntil) {                     // waiting between two repeats
    if ((int32_t)(millis() - pauseUntil) < 0) return;
    pauseUntil = 0;
    startNote();
    return;
  }
  if (millis() - noteStart < current[noteIndex].ms) return;
  noteIndex++;
  if (current[noteIndex].ms == 0) {         // end of melody
    if (repeatsLeft > 0) {
      repeatsLeft--;
      noteIndex = 0;
      ledcWriteTone(PIN_BUZZER, 0);
      pauseUntil = millis() + 400;       // small pause before repeating
      return;
    }
    ledcWriteTone(PIN_BUZZER, 0);
    current = nullptr;
    return;
  }
  startNote();
}

bool soundBusy() { return current != nullptr; }
