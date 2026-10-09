// =====================================================================
//  Rayy: web dashboard (XAMPP version: Apache + PHP + MySQL)
//  The page is served by Apache from htdocs/rayy and reads the plant data
//  from the PHP API in the "api" folder next to it:
//    api/login.php      sign in → token (kept in this browser)
//    api/live.php       latest readings + settings      (every 5 s)
//    api/history.php    one point every 5 minutes       (every 5 min)
//    api/events.php     mood changes ("plant diary")    (every 15 s)
//    api/settings.php   save the settings
//    api/command.php    {play: n} makes the plant play melody n
// =====================================================================
const API = "api";
const PLANT_ID = "plant01";          // same as PLANT_ID in firmware/Rayy/config.h
const $ = (id) => document.getElementById(id);

// ---------------------------------------------------------------------
//  Texts (Arabic / English)
// ---------------------------------------------------------------------
const TEXT = {
  ar: {
    appName: "ري", loginHint: "سجّل الدخول لمتابعة نبتتك", email: "البريد الإلكتروني",
    password: "كلمة المرور", signIn: "تسجيل الدخول", signOut: "خروج", online: "متصلة", offline: "غير متصلة",
    demoBanner: "وضع تجريبي: بيانات محاكاة (بدون خادم XAMPP).",
    serverError: "تعذّر الاتصال بالخادم: تأكد من تشغيل Apache وMySQL في XAMPP",
    lastUpdate: "آخر تحديث", soil: "رطوبة التربة", temperature: "الحرارة", humidity: "رطوبة الجو",
    light: "الإضاءة", wifi: "إشارة الواي فاي", history: "السجل (آخر 24 ساعة)",
    events: "مذكرات النبتة", speak: "تشغيل صوت على النبتة", speakNow: "تشغيل", settings: "إعدادات النبتة",
    plantName: "اسم النبتة", moistureMin: "عطشانة تحت (%)", moistureMax: "مبللة جداً فوق (%)",
    tempMin: "باردة تحت (°م)", tempMax: "حارة فوق (°م)", luxMin: "تحتاج ضوء تحت (لوكس)",
    quietStart: "صامتة من الساعة", quietEnd: "صامتة حتى الساعة",
    muted: "كتم الصوت", save: "حفظ", saved: "تم الحفظ ✔", sent: "تم إرسال الطلب، سيعمل الصوت خلال 30 ثانية",
    signalGood: "ممتازة", signalOk: "جيدة", signalBad: "ضعيفة", noEvents: "لا توجد أحداث بعد", footer: "ري · مشروع تخرج في إنترنت الأشياء",
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
    tracks: ["عطشانة", "غرقانة", "حرّانة", "بردانة", "تحتاج ضوء", "سعيدة", "شكراً", "تصبحون على خير", "مرحباً"],
  },
  en: {
    appName: "Rayy", loginHint: "Sign in to see your plant", email: "Email", password: "Password",
    signIn: "Sign in", signOut: "Sign out", online: "Online", offline: "Offline",
    demoBanner: "Demo mode: simulated data (no XAMPP server).",
    serverError: "Cannot reach the server: check that Apache and MySQL are running in XAMPP",
    lastUpdate: "Last update", soil: "Soil moisture", temperature: "Temperature", humidity: "Air humidity",
    light: "Light", wifi: "Wi-Fi signal", history: "History (last 24 hours)",
    events: "Plant diary", speak: "Play a sound on the plant", speakNow: "Play", settings: "Plant settings",
    plantName: "Plant name", moistureMin: "Thirsty below (%)", moistureMax: "Too wet above (%)",
    tempMin: "Cold below (°C)", tempMax: "Hot above (°C)", luxMin: "Needs light below (lux)",
    quietStart: "Silent from (hour)", quietEnd: "Silent until (hour)",
    muted: "Mute sound", save: "Save", saved: "Saved ✔", sent: "Request sent, the plant will play it within 30 s",
    signalGood: "excellent", signalOk: "good", signalBad: "weak", noEvents: "No events yet", footer: "Rayy · IoT graduation project",
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
    tracks: ["Thirsty", "Too wet", "Hot", "Cold", "Needs light", "Happy", "Thank you", "Good night", "Hello"],
  },
};
const EMOJI = { happy: "😊", thirsty: "😫", drowning: "🥴", hot: "🥵", cold: "🥶", need_light: "😞", sleepy: "😴", unknown: "🌱" };

let lang = localStorageGet("lang") || "ar";
const state = { live: null, history: [], events: [], config: {} };
let source = null;   // PHP API or demo data source
let chart = null;

function localStorageGet(k) { try { return localStorage.getItem(k); } catch { return null; } }
function localStorageSet(k, v) { try { localStorage.setItem(k, v); } catch { /* private mode */ } }
const t = (k) => TEXT[lang][k] ?? k;

// ---------------------------------------------------------------------
//  Data sources
// ---------------------------------------------------------------------
class ApiError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

// Data source that talks to the PHP API (polling: the page asks every few seconds)
function apiSource() {
  let token = localStorageGet("token");
  let authCb = () => {};
  const timers = [];

  async function call(path, body) {
    const res = await fetch(`${API}/${path}${path.includes("?") ? "&" : "?"}plant=${PLANT_ID}`, {
      method: body ? "POST" : "GET",
      headers: { "Content-Type": "application/json", ...(token ? { "X-Auth-Token": token } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    const data = await res.json().catch(() => ({ ok: false, error: `HTTP ${res.status}` }));
    if (res.status === 401 && token) signedOut();       // session expired
    if (!res.ok || !data.ok) throw new ApiError(res.status, data.error || `HTTP ${res.status}`);
    return data;
  }
  function stopPolling() { timers.splice(0).forEach(clearInterval); }
  function signedOut() {
    token = null; localStorageSet("token", ""); stopPolling(); authCb(false);
  }
  function poll(fn, ms) { fn(); timers.push(setInterval(fn, ms)); }

  return {
    demo: false,
    onAuth: (cb) => { authCb = cb; cb(!!token); },
    async signIn(email, pass) {
      const r = await call("login.php", { email, password: pass });
      token = r.token; localStorageSet("token", token); authCb(true);
    },
    async signOut() {
      try { await call("logout.php", {}); } catch { /* already signed out */ }
      signedOut();
    },
    subscribe(handlers) {
      const safe = (fn) => async () => {
        try { await fn(); $("serverError").classList.add("hidden"); }
        catch (e) { if (e.status !== 401) { $("serverError").textContent = `${t("serverError")} (${e.message})`; $("serverError").classList.remove("hidden"); } }
      };
      let lastConfig = "";
      poll(safe(async () => {
        const r = await call("live.php");
        // refill the settings form only when the settings really changed
        const c = JSON.stringify(r.config);
        if (c !== lastConfig) { lastConfig = c; handlers.config(r.config); }
        handlers.live(r.live);
      }), 5000);
      poll(safe(async () => handlers.events((await call("events.php?limit=30")).events)), 15000);
      poll(safe(async () => handlers.history((await call("history.php?hours=24")).history)), 300000);
    },
    saveConfig: async (cfg) => { await call("settings.php", cfg); },
    speak: (track) => call("command.php", { play: track }),
  };
}

// Simulated plant used without a server (?demo=1)
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
    });
  }
  const last = history[history.length - 1];
  let config = { name: "ري 🌿", moisture_min: 30, moisture_max: 85, temp_min: 10, temp_max: 35,
                 lux_min: 200, quiet_start: 22, quiet_end: 7, muted: false };
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
    h.live({ ...r, mood: mood(r), rssi: -58 });
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
  $("vRssi").textContent = show(l.rssi);
  $("vSignal").textContent = l.rssi === undefined ? "" : t(l.rssi > -60 ? "signalGood" : l.rssi > -75 ? "signalOk" : "signalBad");

  const bm = $("barMoisture");
  bm.style.width = `${l.moisture ?? 0}%`;
  bm.className = l.moisture < (state.config.moisture_min ?? 30) ? "low"
    : l.moisture > (state.config.moisture_max ?? 85) ? "high" : "";

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
    catch (err) { $("loginError").textContent = err.status === 401 ? t("loginFailed") : `${t("serverError")} (${err.message})`; }
  });

  $("logoutBtn").addEventListener("click", () => source.signOut());
  $("chartMetric").addEventListener("change", renderChart);

  $("speakBtn").addEventListener("click", async () => {
    try {
      await source.speak(Number($("trackSelect").value));
      $("speakMsg").textContent = t("sent");
    } catch (err) { $("speakMsg").textContent = err.message; }
  });

  $("settingsForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const cfg = {};
    for (const el of e.target.elements) {
      if (!el.name) continue;
      if (el.type === "checkbox") cfg[el.name] = el.checked;
      else if (el.type === "number") { if (el.value !== "") cfg[el.name] = Number(el.value); }
      else if (el.value.trim() !== "") cfg[el.name] = el.value.trim();
    }
    try {
      await source.saveConfig(cfg);
      $("settingsMsg").textContent = t("saved");
    } catch (err) {
      $("settingsMsg").textContent = err.message;
      return;
    }
    setTimeout(() => ($("settingsMsg").textContent = ""), 3000);
  });

  // keep the "online" badge and times fresh
  setInterval(renderLive, 15000);
}

async function main() {
  bindUi();
  applyLanguage();
  // Demo mode: ?demo=1, or the page was opened as a file (not through Apache)
  const demo = new URLSearchParams(location.search).has("demo") || location.protocol === "file:";
  source = demo ? demoSource() : apiSource();
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
