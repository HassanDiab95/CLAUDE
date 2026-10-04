# 04 · Database: Why Firebase, and Step-by-Step Setup

## 4.1 Which database should we use? (recommendation)

**Yes: use Firebase for the whole project.** One free Firebase project gives everything this project needs:

| Need | Firebase service | Free "Spark" plan |
|---|---|---|
| Store the live data, history, events and settings | **Realtime Database** | 1 GB stored, 10 GB/month download, 100 simultaneous connections |
| Login for the web and Android apps (and the ESP32) | **Authentication** (email/password) | Free |
| Publish the web dashboard on the internet (`https://your-project.web.app`) | **Hosting** | 10 GB storage, 360 MB/day transfer |
| Android app connection | Firebase Android SDK | Free |

**Why Firebase Realtime Database fits this project best**

* **Real time:** when the ESP32 writes new data, the web page and the Android app update **instantly**, with no refresh.
* **No server to build:** we don't need PHP, Node.js or a hosted MySQL server. The ESP32 talks to Firebase directly over HTTPS.
* **One database for the 3 parts:** the ESP32 (REST API), the web (JavaScript SDK) and Android (Kotlin SDK).
* **Free** for this size: the plant writes ≈ 3,000 small messages a day (≈ 1 MB/day). That is far below the limits.
* **Secure:** rules allow only signed-in users ([`firebase/database.rules.json`](../firebase/database.rules.json)).
* Very well documented, popular for graduation projects, and available in Saudi Arabia.

**Alternatives we compared**

| Option | Verdict |
|---|---|
| **Firebase Realtime Database** | ✅ **Chosen**: simplest for IoT, real time, free |
| Cloud Firestore | Good too, but the REST API from the ESP32 is more complex (typed JSON), and it is billed per read |
| MySQL + PHP (XAMPP / hosting) | Needs a server and hosting, a REST API you write yourself, and polling instead of real time; more work in 6 weeks |
| ThingSpeak / Blynk | Fast for charts, but limited custom apps, free-plan limits, and less "own system" for a graduation project |
| Supabase (PostgreSQL) | Good, but less ESP32 material and more setup |

> **Are we "allowed" to use Firebase?** Technically yes: the free plan is enough, and nothing in this project needs a
> paid plan (no Cloud Functions are used). Whether external cloud services are accepted is your
> **college's/supervisor's** decision. Most IoT graduation projects use Firebase, and it is a professional Google
> platform, so it is usually accepted. Explain in your report that you chose it because it gives
> **real-time sync + authentication + hosting** in one platform (the reasons above).

## 4.2 Database structure

```
plants/
  plant01/                     ← PLANT_ID (one per ESP32)
    live/                      ← overwritten every 30 s by the ESP32
      moisture: 46             (%)
      temperature: 27.4        (°C)
      humidity: 38             (%)
      lux: 5400
      battery_pct: 87
      battery_v: 4.02
      solar_v: 6.3
      charging: true
      soil_raw: 2190           (for calibration)
      mood: "happy"            happy | thirsty | drowning | hot | cold | need_light | sleepy
      rssi: -61                (Wi-Fi signal)
      ip: "192.168.1.23"
      uptime_s: 86400
      ts: 1767000000000        (server time, milliseconds)
    history/
      -Nx1a2b3.../  { moisture, temperature, humidity, lux, battery_pct, mood, ts }   ← every 5 min
    events/
      -Nx9z8y7.../  { mood: "thirsty", message: "I am thirsty, please water me!", ts }  ← on mood change
    config/                    ← written by the web / Android app, read by the ESP32
      name: "Basil"
      moisture_min: 30   moisture_max: 85
      temp_min: 10       temp_max: 35
      lux_min: 200
      quiet_start: 22    quiet_end: 7
      volume: 25         muted: false
    command/                   ← "Speak now" button; deleted by the ESP32 after playing
      play: 1
```

## 4.3 Step-by-step setup (≈ 20 minutes)

### Step 1: Create the project
1. Go to <https://console.firebase.google.com> and sign in with a Google account (use a team account).
2. **Add project** → name it `smart-plant` → you can **disable Google Analytics** → **Create project**.

### Step 2: Authentication
1. Left menu **Build → Authentication → Get started**.
2. **Sign-in method** tab → **Email/Password** → **Enable** → Save.
3. **Users** tab → **Add user** and create:
   * `device@smartplant.app` with a strong password. **The ESP32 uses this account** (put it in `config.h`).
   * One account for each team member / user, e.g. `team@smartplant.app`. **The web and Android apps use these.**
   (The email does not need to exist; Firebase does not send emails for users added by hand.)

### Step 3: Realtime Database
1. **Build → Realtime Database → Create database**.
2. Location: **Belgium (europe-west1)** (closest to Saudi Arabia) or United States.
3. Start in **locked mode** → Enable.
4. Copy the database URL shown at the top, e.g.
   `https://smart-plant-1234-default-rtdb.europe-west1.firebasedatabase.app`.
5. **Rules** tab → delete everything → paste the content of
   [`firebase/database.rules.json`](../firebase/database.rules.json) → **Publish**.

### Step 4: Web app keys
1. ⚙️ **Project settings → General** → under "Your apps" click the **`</>` (Web)** icon.
2. Nickname `smart-plant-web` → **Register app**.
3. Copy the `firebaseConfig = { apiKey: ..., ... }` values into [`web/firebase-config.js`](../web/firebase-config.js).
   Check that `databaseURL` is your URL from step 3.
4. The same **Web API Key** (`apiKey`) goes into `FIREBASE_API_KEY` in `firmware/SmartPlant/config.h`.

> The web `apiKey` is **not a secret**. It only identifies the project. The data is protected by **Authentication +
> Rules**, so publishing it is normal.

### Step 5: Android app
1. **Project settings → General → Add app → Android**.
2. Android package name: **`com.smartplant.app`** → Register.
3. Download **`google-services.json`** and copy it to **`android/app/google-services.json`**.
   (Download it **after** creating the Realtime Database, so it contains the database URL.)
4. Next → Next → Continue to console. The Gradle steps are already done in this project.

### Step 6: Hosting (publish the web dashboard)
On a computer with **Node.js LTS** installed:

```bash
npm install -g firebase-tools
firebase login
cd smart-plant-iot          # this folder (contains firebase.json)
firebase use --add          # choose your project, alias "default"
firebase deploy --only hosting,database
```

The dashboard is now online at `https://<project-id>.web.app` 🎉 (open it from any phone or PC).

## 4.4 Testing the database without the ESP32

In the Firebase console → Realtime Database → **Data** tab, you can add data by hand to test the apps:
click **+** next to the root → `plants` → `plant01` → `live` → add `moisture: 20`, `mood: "thirsty"`,
`ts: 1767000000000`. The apps show 😫 immediately.

You can also simulate the ESP32 with `curl` (REST API, the same one the firmware uses):

```bash
API_KEY=YOUR_WEB_API_KEY
DB=https://YOUR-DB-URL
# 1) login as the device user, get an idToken
TOKEN=$(curl -s "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"email":"device@smartplant.app","password":"CHANGE_ME_123","returnSecureToken":true}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["idToken"])')
# 2) write live data
curl -X PUT "$DB/plants/plant01/live.json?auth=$TOKEN" \
  -d '{"moisture":22,"temperature":29.5,"humidity":35,"lux":4200,"battery_pct":80,"mood":"thirsty","ts":{".sv":"timestamp"}}'
```

## 4.5 Security (for the report)

* Every request needs a valid **ID token** from Firebase Authentication. Anonymous internet users get
  `Permission denied`.
* The rules also **validate** values (moisture 0–100, volume 0–30, muted is boolean).
* Passwords are stored by Google (hashed), never in the database.
* The ESP32 uses HTTPS. For simplicity it does not verify the certificate (`setInsecure()`). For a commercial
  product, load Google's root certificate (mentioned as future work).
* Possible improvement: give the device account write access only to `live/history/events`, and users write access
  only to `config/command` (using the account UID in the rules).
