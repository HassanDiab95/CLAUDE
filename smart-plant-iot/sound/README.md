# 🔊 Voice messages (DFPlayer Mini micro-SD card)

## Files to create

Record each sentence (1–4 seconds). You can record your own voices, which makes the project more personal, or use a
text-to-speech website. Save them as **MP3** files with **exactly** these names:

| File | When it plays | Arabic (suggested) | English |
|---|---|---|---|
| `0001.mp3` | Thirsty | أنا عطشانة! أرجوك اسقني ماء 💧 | I'm thirsty! Please water me. |
| `0002.mp3` | Too wet | كفاية ماء! أنا غرقانة | Too much water! I'm drowning. |
| `0003.mp3` | Too hot | الجو حار جداً! انقلني لمكان أبرد | It's too hot! Move me somewhere cooler. |
| `0004.mp3` | Cold | أشعر بالبرد! أحتاج مكاناً أدفأ | I feel cold! I need a warmer place. |
| `0005.mp3` | Needs light | أحتاج إلى ضوء الشمس ☀️ | I need some sunlight. |
| `0006.mp3` | Happy again | أنا سعيدة، كل شيء ممتاز 😊 | I'm happy, everything is perfect! |
| `0007.mp3` | After watering | شكراً لأنك سقيتني! | Thank you for watering me! |
| `0008.mp3` | Night starts | تصبحون على خير 😴 | Good night! |
| `0009.mp3` | Power on | مرحباً! أنا نبتتك الذكية 🌱 | Hello! I am your smart plant. |
| `0010.mp3` | (Speak now / low battery) | بطاريتي ضعيفة، أحتاج إلى الشمس | My battery is low, I need the sun. |

## Copy them to the SD card

1. Format the micro-SD card as **FAT32** (cards up to 32 GB).
2. Create a folder named **`mp3`** (lower-case) in the root of the card.
3. Copy the files into it: `/mp3/0001.mp3`, `/mp3/0002.mp3`, …
4. Put the card into the DFPlayer **before** powering on.

## Recording tips

* Use a phone voice recorder in a quiet room, then trim and export to MP3 with **Audacity** (free):
  *Effect → Normalize* (−1 dB) to make all files equally loud, then *File → Export → MP3* (128 kbps, mono is fine).
* Speak slowly and with a "cute" plant character. Add a short sound effect (a water drop or a yawn) if you like.
* The volume can be changed from the web app (0–30, default 25).
