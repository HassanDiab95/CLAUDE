# 12 · Future Work: Artificial Intelligence (الذكاء الاصطناعي، مستقبلاً)

AI is **not part of the current version**. Rayy is already designed so an AI part can be added later
**without changing the existing code**: this chapter explains where it plugs in and gives three options,
from the simplest to the most advanced.

## 12.1 What is ready for AI today

| Ready part | Why it helps AI |
|---|---|
| `plants/<id>/history` (every 5 min: moisture, temperature, humidity, light, battery) | The **training data**: after 2–4 weeks you have thousands of labelled points |
| `plants/<id>/events` (every mood change) | Labels: when the plant was thirsty, hot, … |
| `plants/<id>/ai` (**reserved** in `database.rules.json`) | Where the AI writes its results; the apps can read them |
| `evaluateMood()` in `firmware/Rayy/mood.cpp` | One function decides the mood: an AI model can replace or assist it |
| Sounds are numbered tracks (`command/play`) | An AI can choose which melody / message to play |

Export the data for training: Firebase console → Realtime Database → `plants/plant01/history` → ⋮ → **Export JSON**.

## 12.2 Option A: watering prediction in the cloud (recommended first)

* **Idea:** "Rayy will be thirsty in about **9 hours**". A simple model (linear regression on the moisture
  slope, then later a small neural network) learns how fast the soil dries for this plant.
* **Where:** a **Firebase Cloud Function** (Node.js or Python) that runs every hour, reads `history`, and writes:

```json
"ai": { "next_water_hours": 9, "confidence": 0.82, "tip": "Water tomorrow morning", "ts": 1760000000000 }
```

* **Apps:** add one card "🧠 AI prediction" that reads `plants/<id>/ai`.
* **Note:** Cloud Functions need the Firebase **Blaze** (pay-as-you-go) plan; a small project stays inside the
  free quota. Alternative without Blaze: run the same Python script on a PC on a schedule.

## 12.3 Option B: TinyML on the ESP32 (works offline)

* **Idea:** a tiny model runs **on the ESP32** itself, e.g. to recognise the plant's daily pattern or to detect a
  broken / unplugged sensor.
* **Tools:** **Edge Impulse** (free for students) or **TensorFlow Lite for Microcontrollers**: upload the exported
  history CSV, train, then export an **Arduino library** and call it from `readAndEvaluate()` in `Rayy.ino`.
* **Fits:** the ESP32 has 520 KB RAM; small models (< 50 KB) run in a few milliseconds.

## 12.4 Option C: the plant "talks" with generative AI

* **Idea:** instead of fixed sentences, an AI model (for example a Claude model through the Anthropic API) writes a
  short friendly message in Arabic or English from the current readings: "صباح الخير! التربة جافة قليلاً…".
* **Where:** a Cloud Function triggered when `events` gets a new entry; it writes the text to `ai/message`, and the
  apps show it under the emoji. The API key stays **on the server**, never in the ESP32, web or Android code.
* **Plant disease detection** with an **ESP32-CAM** and an image-classification model is a bigger extension of the
  same idea.

## 12.5 Steps to add AI later (summary)

1. Collect at least **2–4 weeks** of history from the real plant.
2. Export the JSON and explore it (Python + pandas, or Excel).
3. Start with **Option A** (simplest, biggest benefit), write the result to `plants/<id>/ai`.
4. Add an "AI" card to `web/index.html` + `web/app.js` and to `MainScreen.kt`.
5. Compare the AI prediction with what really happened, and write the accuracy in the report.
