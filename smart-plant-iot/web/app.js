// =====================================================================
//  Smart Emoji Plant: web dashboard
//  Reads the plant data from Firebase Realtime Database:
//    plants/<PLANT_ID>/live      latest readings (updated every 30 s)
//    plants/<PLANT_ID>/history   one point every 5 minutes
//    plants/<PLANT_ID>/events    mood changes ("plant diary")
//    plants/<PLANT_ID>/config    settings written by this page
//    plants/<PLANT_ID>/command   {play: n} makes the plant speak
// =====================================================================
import { firebaseConfig, PLANT_ID } from "./firebase-config.js";

const FB = "https://www.gstatic.com/firebasejs/10.12.2/";
const $ = (id) => document.getElementById(id);

// ---------------------------------------------------------------------
//  Texts (Arabic / English)
// ---------------------------------------------------------------------
const TEXT = {
  ar: {
    appName: "النبتة الذكية", loginHint: "سجّل الدخول لمتابعة نبتتك", email: "البريد الإلكتروني",
    password: "كلمة المرور", signIn: "تسجيل الدخول", signOut: "خروج", online: "متصلة", offline: "غير متصلة",
    demoBanner: "وضع تجريبي: بيانات محاكاة. أضف إعدادات Firebase في الملف firebase-config.js",
    lastUpdate: "آخر تحديث", soil: "رطوبة التربة", temperature: "الحرارة", humidity: "رطوبة الجو",
    light: "الإضاءة", battery: "البطارية", solar: "اللوح الشمسي", history: "السجل (آخر 24 ساعة)",
    events: "مذكرات النبتة", speak: "اجعل النبتة تتكلم", speakNow: "تكلّمي الآن", settings: "إعدادات النبتة",
    plantName: "اسم النبتة", moistureMin: "عطشانة تحت (%)", moistureMax: "مبللة جداً فوق (%)",
    tempMin: "باردة تحت (°م)", tempMax: "حارة فوق (°م)", luxMin: "تحتاج ضوء تحت (لوكس)",
    quietStart: "صامتة من الساعة", quietEnd: "صامتة حتى الساعة", volume: "مستوى الصوت (0-30)",
    muted: "كتم الصوت", save: "حفظ", saved: "تم الحفظ ✔", sent: "تم إرسال الطلب، ستتكلم النبتة خلال 30 ثانية",
    charging: "يشحن ⚡", notCharging: "لا يشحن", noEvents: "لا توجد أحداث بعد", footer: "النبتة الذكية · إنترنت الأشياء · تعمل بالطاقة الشمسية",
    loginFailed: "فشل تسجيل الدخول: تحقق من البريد وكلمة المرور", other: "English",
    moods: {
      happy: ["سعيدة", "كل شيء ممتاز، شكراً لاهتمامك!"],
      thirsty: ["عطشانة", "أنا عطشانة! أرجوك اسقني ماء."],
      drowning: ["غرقانة", "كفاية ماء! التربة مبللة جداً."],
      hot: ["حرّانة", "الجو حار جداً، انقلني لمكان أبرد."],
      cold: ["بردانة", "أشعر بالبرد، أحتاج مكاناً أدفأ."],
      need_light: ["تحتاج ضوء", "أحتاج إلى ضوء الشمس."],
      sleepy: ["نائمة", "تصبحون على خير… أنا نائمة."],
      unknown: ["…", "بانتظار البيانات"],
    },
    tracks: ["عطشانة", "غرقانة", "حرّانة", "بردانة", "تحتاج ضوء", "سعيدة", "شكراً", "تصبحون على خير", "مرحباً", "بطارية ضعيفة"],
  },
  en: {
    appName: "Smart Emoji Plant", loginHint: "Sign in to see your plant", email: "Email", password: "Password",
    signIn: "Sign in", signOut: "Sign out", online: "Online", offline: "Offline",
    demoBanner: "Demo mode: simulated data. Add your Firebase settings to firebase-config.js",
    lastUpdate: "Last update", soil: "Soil moisture", temperature: "Temperature", humidity: "Air humidity",
    light: "Light", battery: "Battery", solar: "Solar panel", history: "History (last 24 hours)",
    events: "Plant diary", speak: "Make the plant speak", speakNow: "Speak now", settings: "Plant settings",
    plantName: "Plant name", moistureMin: "Thirsty below (%)", moistureMax: "Too wet above (%)",
    tempMin: "Cold below (°C)", tempMax: "Hot above (°C)", luxMin: "Needs light below (lux)",
    quietStart: "Silent from (hour)", quietEnd: "Silent until (hour)", volume: "Volume (0-30)",
    muted: "Mute voice", save: "Save", saved: "Saved ✔", sent: "Request sent, the plant will speak within 30 s",
    charging: "charging ⚡", notCharging: "not charging", noEvents: "No events yet", footer: "Smart Emoji Plant · IoT · Solar powered",
    loginFailed: "Sign-in failed: check the email and password", other: "العربية",
    moods: {
      happy: ["Happy", "Everything is perfect, thank you!"],
      thirsty: ["Thirsty", "I am thirsty! Please water me."],
      drowning: ["Too wet", "Too much water! The soil is soaked."],
      hot: ["Too hot", "It is too hot, move me somewhere cooler."],
      cold: ["Cold", "I feel cold, I need a warmer place."],
      need_light: ["Needs light", "I need more sunlight."],
      sleepy: ["Sleeping", "Good night… I am sleeping."],
      unknown: ["…", "Waiting for data"],
    },
    tracks: ["Thirsty", "Too wet", "Hot", "Cold", "Needs light", "Happy", "Thank you", "Good night", "Hello", "Low battery"],
  },
};
const EMOJI = { happy: "😊", thirsty: "😫", drowning: "🥴", hot: "🥵", cold: "🥶", need_light: "😞", sleepy: "😴", unknown: "🌱" };

let lang = localStorageGet("lang") || "ar";
const state = { live: null, history: [], events: [], config: {} };
let source = null;   // Firebase or demo data source
let chart = null;

function localStorageGet(k) { try { return localStorage.getItem(k); } catch { return null; } }
function localStorageSet(k, v) { try { localStorage.setItem(k, v); } catch { /* private mode */ } }
const t = (k) => TEXT[lang][k] ?? k;

// ---------------------------------------------------------------------
//  Data sources
// ---------------------------------------------------------------------
async function firebaseSource() {
  const [{ initializeApp }, auth, db] = await Promise.all([
    import(FB + "firebase-app.js"),
    import(FB + "firebase-auth.js"),
    import(FB + "firebase-database.js"),
  ]);
  const app = initializeApp(firebaseConfig);
  const a = auth.getAuth(app);
  const d = db.getDatabase(app);
  const base = `plants/${PLANT_ID}`;
  const unsub = [];
  return {
    demo: false,
    onAuth: (cb) => auth.onAuthStateChanged(a, (u) => cb(!!u)),
    signIn: (email, pass) => auth.signInWithEmailAndPassword(a, email, pass),
    signOut: () => { unsub.splice(0).forEach((u) => u()); return auth.signOut(a); },
    subscribe(handlers) {
      unsub.push(db.onValue(db.ref(d, `${base}/live`), (s) => handlers.live(s.val())));
      unsub.push(db.onValue(db.query(db.ref(d, `${base}/history`), db.limitToLast(288)),
        (s) => handlers.history(Object.values(s.val() || {}))));
      unsub.push(db.onValue(db.query(db.ref(d, `${base}/events`), db.limitToLast(30)),
        (s) => handlers.events(Object.values(s.val() || {}).reverse())));
      unsub.push(db.onValue(db.ref(d, `${base}/config`), (s) => handlers.config(s.val() || {})));
    },
    saveConfig: (cfg) => db.update(db.ref(d, `${base}/config`), cfg),
    speak: (track) => db.set(db.ref(d, `${base}/command`), { play: track }),
  };
}

// Simulated plant used when Firebase is not configured yet
function demoSource() {
  const now = Date.now();
  const history = [];
  for (let i = 287; i >= 0; i--) {
    const ts = now - i * 5 * 60000;
    const h = new Date(ts).getHours() + new Date(ts).getMinutes() / 60;
    const sun = Math.max(0, Math.sin(((h - 6) / 12) * Math.PI));
    const moisture = Math.max(18, 70 - ((287 - i) % 200) * 0.28);   // dries, then watered
    history.push({
      ts, moisture: Math.round(moisture),
      temperature: +(22 + sun * 12 + Math.random()).toFixed(1),
      humidity: Math.round(45 - sun * 15),
      lux: Math.round(sun * 9000 + 5),
      battery_pct: Math.round(60 + sun * 35),
    });
  }
  const last = history[history.length - 1];
  let config = { name: "Basil 🌿", moisture_min: 30, moisture_max: 85, temp_min: 10, temp_max: 35,
                 lux_min: 200, quiet_start: 22, quiet_end: 7, volume: 25, muted: false };
  const events = [
    { ts: now - 3 * 3600e3, mood: "happy", message: "I am happy, everything is perfect!" },
    { ts: now - 9 * 3600e3, mood: "thirsty", message: "I am thirsty, please water me!" },
    { ts: now - 14 * 3600e3, mood: "sleepy", message: "Good night, I am sleeping." },
  ];
  let h = null;
  const night = () => { const hr = new Date().getHours(); return hr < 6 || hr >= 18; };
  const mood = (r) => r.moisture < config.moisture_min ? "thirsty" : r.temperature > config.temp_max ? "hot"
    : night() ? "sleepy" : r.lux < config.lux_min ? "need_light" : "happy";
  const tick = () => {
    const r = { ...last, ts: Date.now(), moisture: Math.max(0, last.moisture + Math.round(Math.random() * 2 - 1)) };
    h.live({ ...r, mood: mood(r), battery_v: 3.95, solar_v: r.lux > 500 ? 6.1 : 0.3, charging: r.lux > 500, rssi: -58 });
  };
  return {
    demo: true,
    onAuth: (cb) => cb(true),
    signIn: async () => {}, signOut: async () => {},
    subscribe(handlers) {
      h = handlers;
      handlers.history(history); handlers.events(events); handlers.config(config);
      tick(); setInterval(tick, 5000);
    },
    saveConfig: async (c) => { config = { ...config, ...c }; h.config(config); },
    speak: async () => {},
  };
}

// ---------------------------------------------------------------------
//  Rendering
// ---------------------------------------------------------------------
function applyLanguage() {
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    if (el.id === "plantName" && state.config.name) return;
    el.textContent = t(el.dataset.i18n);
  });
  document.querySelectorAll(".lang-toggle").forEach((b) => (b.textContent = t("other")));
  $("trackSelect").innerHTML = TEXT[lang].tracks.map((n, i) => `<option value="${i + 1}">${i + 1}. ${n}</option>`).join("");
  renderLive(); renderEvents(); renderChart();
}

const fmtTime = (ts) => ts ? new Date(ts).toLocaleString(lang === "ar" ? "ar-SA-u-ca-gregory-nu-latn" : "en-GB",
  { hour: "2-digit", minute: "2-digit", day: "numeric", month: "short" }) : "—";
const show = (v, digits = 0) => (v === undefined || v === null ? "—" : Number(v).toFixed(digits));

function renderLive() {
  const l = state.live;
  const mood = l?.mood && TEXT[lang].moods[l.mood] ? l.mood : "unknown";
  const [title, text] = TEXT[lang].moods[mood];
  $("moodEmoji").textContent = EMOJI[mood];
  $("moodTitle").textContent = title;
  $("moodText").textContent = text;
  $("hero").classList.toggle("alert", !["happy", "sleepy", "unknown"].includes(mood));
  document.title = `${EMOJI[mood]} ${state.config.name || t("appName")}`;
  if (!l) return;

  $("lastUpdate").textContent = fmtTime(l.ts);
  $("vMoisture").textContent = show(l.moisture);
  $("vTemp").textContent = show(l.temperature, 1);
  $("vHum").textContent = show(l.humidity);
  $("vLux").textContent = show(l.lux);
  $("vBatt").textContent = show(l.battery_pct);
  $("vBattV").textContent = show(l.battery_v, 2);
  $("vCharging").textContent = l.charging ? t("charging") : t("notCharging");
  $("vSolar").textContent = show(l.solar_v, 1);
  $("vRssi").textContent = show(l.rssi);

  const bm = $("barMoisture");
  bm.style.width = `${l.moisture ?? 0}%`;
  bm.className = l.moisture < (state.config.moisture_min ?? 30) ? "low"
    : l.moisture > (state.config.moisture_max ?? 85) ? "high" : "";
  const bb = $("barBatt");
  bb.style.width = `${l.battery_pct ?? 0}%`;
  bb.className = l.battery_pct < 20 ? "low" : "";

  // "Online" if the plant sent data during the last 2 minutes
  const online = l.ts && Date.now() - l.ts < 120000;
  const badge = $("onlineBadge");
  badge.textContent = online ? t("online") : t("offline");
  badge.className = `badge ${online ? "on" : "off"}`;
}

function renderEvents() {
  const ul = $("events");
  if (!state.events.length) { ul.innerHTML = `<li class="muted">${t("noEvents")}</li>`; return; }
  ul.innerHTML = "";
  for (const e of state.events) {
    const m = TEXT[lang].moods[e.mood] ? e.mood : "unknown";
    const li = document.createElement("li");
    li.innerHTML = `<span class="e-emoji">${EMOJI[m]}</span><div><div></div><div class="e-time"></div></div>`;
    li.querySelector("div > div").textContent = TEXT[lang].moods[m][1];
    li.querySelector(".e-time").textContent = fmtTime(e.ts);
    ul.appendChild(li);
  }
}

function renderChart() {
  if (!window.Chart) return;                 // Chart.js failed to load (offline)
  const metric = $("chartMetric").value;
  const pts = state.history.filter((p) => p[metric] !== undefined && p.ts);
  const labels = pts.map((p) => new Date(p.ts).toLocaleTimeString(lang === "ar" ? "ar-SA-u-ca-gregory-nu-latn" : "en-GB",
    { hour: "2-digit", minute: "2-digit" }));
  const data = pts.map((p) => p[metric]);
  const label = $("chartMetric").selectedOptions[0].textContent;
  const color = getComputedStyle(document.documentElement).getPropertyValue("--green").trim() || "#2f7d4f";
  if (!chart) {
    chart = new Chart($("chart"), {
      type: "line",
      data: { labels, datasets: [{ label, data, borderColor: color, backgroundColor: color + "22", fill: true, tension: .3, pointRadius: 0, borderWidth: 2 }] },
      options: { responsive: true, maintainAspectRatio: false, animation: false,
        plugins: { legend: { display: false } },
        scales: { x: { ticks: { maxTicksLimit: 8 } }, y: { beginAtZero: metric !== "temperature" } } },
    });
  } else {
    chart.data.labels = labels;
    Object.assign(chart.data.datasets[0], { label, data });
    chart.options.scales.y.beginAtZero = metric !== "temperature";
    chart.update();
  }
}

function fillSettings() {
  const f = $("settingsForm");
  for (const el of f.elements) {
    if (!el.name || document.activeElement === el) continue;
    const v = state.config[el.name];
    if (el.type === "checkbox") el.checked = !!v;
    else if (v !== undefined) el.value = v;
  }
  if (state.config.name) $("plantName").textContent = state.config.name;
}

// ---------------------------------------------------------------------
//  Events
// ---------------------------------------------------------------------
function bindUi() {
  document.querySelectorAll(".lang-toggle").forEach((b) => b.addEventListener("click", () => {
    lang = lang === "ar" ? "en" : "ar";
    localStorageSet("lang", lang);
    applyLanguage();
  }));

  $("loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    $("loginError").textContent = "";
    try { await source.signIn($("email").value.trim(), $("password").value); }
    catch { $("loginError").textContent = t("loginFailed"); }
  });

  $("logoutBtn").addEventListener("click", () => source.signOut());
  $("chartMetric").addEventListener("change", renderChart);

  $("speakBtn").addEventListener("click", async () => {
    await source.speak(Number($("trackSelect").value));
    $("speakMsg").textContent = t("sent");
  });

  $("settingsForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const cfg = {};
    for (const el of e.target.elements) {
      if (!el.name) continue;
      if (el.type === "checkbox") cfg[el.name] = el.checked;
      else if (el.type === "number") { if (el.value !== "") cfg[el.name] = Number(el.value); }
      else cfg[el.name] = el.value.trim();
    }
    await source.saveConfig(cfg);
    $("settingsMsg").textContent = t("saved");
    setTimeout(() => ($("settingsMsg").textContent = ""), 3000);
  });

  // keep the "online" badge and times fresh
  setInterval(renderLive, 15000);
}

async function main() {
  bindUi();
  applyLanguage();
  const demo = new URLSearchParams(location.search).has("demo") || firebaseConfig.apiKey.startsWith("YOUR_");
  try {
    source = demo ? demoSource() : await firebaseSource();
  } catch (err) {
    console.error("Firebase could not be loaded, switching to demo mode", err);
    source = demoSource();
  }
  $("demoBanner").classList.toggle("hidden", !source.demo);
  if (source.demo) $("logoutBtn").classList.add("hidden");

  let subscribed = false;
  source.onAuth((signedIn) => {
    $("login").classList.toggle("hidden", signedIn);
    $("app").classList.toggle("hidden", !signedIn);
    if (signedIn && !subscribed) {
      subscribed = true;
      source.subscribe({
        live: (v) => { state.live = v; renderLive(); },
        history: (v) => { state.history = v.sort((a, b) => a.ts - b.ts); renderChart(); },
        events: (v) => { state.events = v; renderEvents(); },
        config: (v) => { state.config = v; fillSettings(); renderLive(); },
      });
    }
    if (!signedIn) subscribed = false;
  });
}

main();
