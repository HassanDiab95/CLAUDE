// =====================================================================
//  ري (Rayy): smart farming web dashboard (XAMPP: Apache + PHP + MySQL)
//  The page is served by Apache from htdocs/rayy and talks to the PHP API
//  in the "api" folder next to it. Screens (address after #):
//    #crops        my crops (cards with the emoji of each crop)
//    #crop/<id>    one crop: mood, live values, chart, diary, settings, device
//    #devices      sensor devices: add a device, move it to another crop
//    #users        (admin) create users, change roles, delete users
//  The data is refreshed by asking the server every few seconds (polling).
// =====================================================================
const API = "api";
const $ = (id) => document.getElementById(id);

// ---------------------------------------------------------------------
//  Texts (Arabic / English)
// ---------------------------------------------------------------------
const TEXT = {
  ar: {
    tagline: "زراعة ذكية تحوّل مشاعر محاصيلك إلى إيموجي", signIn: "تسجيل الدخول", createAccount: "إنشاء حساب",
    email: "البريد الإلكتروني", password: "كلمة المرور", fullName: "الاسم الكامل", passwordHint: "8 أحرف على الأقل",
    signOut: "خروج", admin: "مدير", navCrops: "زراعاتي", navDevices: "الأجهزة", navUsers: "المستخدمون",
    online: "متصلة", offline: "غير متصلة",
    demoBanner: "وضع تجريبي: بيانات محاكاة (بدون خادم XAMPP).",
    serverError: "تعذّر الاتصال بالخادم: تأكد من تشغيل Apache وMySQL في XAMPP",
    myCrops: "زراعاتي", cropsHint: "لكل زراعة قيمها المثالية. جهاز الاستشعار يقيس زراعة واحدة ويمكن نقله إلى زراعة أخرى.",
    addCrop: "+ إضافة زراعة", newCrop: "زراعة جديدة", cropName: "اسم الزراعة", cropNamePh: "مثال: فراولة البيت المحمي 1",
    cropType: "نوع المحصول", location: "الموقع", locationPh: "بيت محمي، مزرعة، حديقة، شرفة…", cancel: "إلغاء", save: "حفظ",
    idealValues: "القيم المثالية", noCrops: "لا توجد زراعات بعد. أضف أول زراعة لك.", noData: "لا توجد بيانات بعد",
    noDevice: "بدون جهاز", device: "الجهاز", owner: "المالك", back: "→ زراعاتي",
    lastUpdate: "آخر تحديث", soil: "رطوبة التربة", temperature: "الحرارة", humidity: "رطوبة الجو", light: "الإضاءة",
    wifi: "إشارة الواي فاي", history: "السجل (آخر 24 ساعة)", events: "مذكرات الزراعة",
    speak: "تشغيل صوت على الجهاز", speakNow: "تشغيل", settings: "إعدادات الزراعة",
    moistureMin: "عطشانة تحت (%)", moistureMax: "مبللة جداً فوق (%)", tempMin: "باردة تحت (°م)", tempMax: "حارة فوق (°م)",
    luxMin: "تحتاج ضوء تحت (لوكس)", quietStart: "صامتة من الساعة", quietEnd: "صامتة حتى الساعة", muted: "كتم الصوت",
    saved: "تم الحفظ ✔", sent: "تم إرسال الطلب، سيعمل الصوت خلال 30 ثانية",
    signalGood: "ممتازة", signalOk: "جيدة", signalBad: "ضعيفة", noEvents: "لا توجد أحداث بعد",
    deleteCrop: "حذف هذه الزراعة", confirmDelete: "حذف الزراعة وكل سجلها؟",
    cropDevice: "جهاز الاستشعار لهذه الزراعة", deviceOn: "يقيس هذه الزراعة الآن: ", noDeviceHere: "لا يوجد جهاز على هذه الزراعة. اختر جهازاً وانقله إليها.",
    moveHere: "نقل إلى هذه الزراعة", removeDevice: "إزالة", chooseDevice: "اختر جهازاً…", moved: "تم نقل الجهاز ✔ سيقيس هذه الزراعة خلال 30 ثانية",
    noDevicesYet: "ليس لديك أجهزة. أضف جهازاً من صفحة الأجهزة.",
    devicesHint: "الجهاز هو ESP32 مع الحساسات والسماعة. ضعه في زراعة واختر تلك الزراعة هنا، وانقله متى شئت.",
    addDevice: "إضافة جهاز", addDeviceHint: "أدخل DEVICE_ID و DEVICE_KEY المكتوبين في الجهاز (الملف config.h).",
    deviceId: "رقم الجهاز", deviceKey: "مفتاح الجهاز", deviceName: "اسم الجهاز", add: "إضافة",
    adminDeviceHint: "للمدير: الرقم الجديد يُسجَّل بهذا المفتاح، ثم يستطيع المستخدم إضافته بنفس الرقم والمفتاح.",
    measures: "يقيس: ", notAssigned: "غير مرتبط بزراعة", lastSeen: "آخر اتصال: ", never: "لم يتصل بعد",
    moveTo: "نقل إلى…", move: "نقل", unassign: "فصل", deviceAdded: "تمت إضافة الجهاز ✔", deviceCreated: "تم تسجيل الجهاز الجديد ✔",
    newUser: "إنشاء مستخدم", role: "الصلاحية", roleUser: "مستخدم", roleAdmin: "مدير", userCreated: "تم إنشاء المستخدم ✔",
    del: "حذف", confirmDeleteUser: "حذف المستخدم وكل زراعاته؟", you: "(أنت)",
    loginFailed: "فشل تسجيل الدخول: تحقق من البريد وكلمة المرور", other: "English",
    footer: "ري · زراعة ذكية · مشروع تخرج في إنترنت الأشياء",
    moods: {
      happy: ["سعيدة", "كل شيء ممتاز، شكراً لاهتمامك!"],
      thirsty: ["عطشانة", "أنا عطشانة! أرجوك اسقني ماء."],
      drowning: ["غرقانة", "كفاية ماء! التربة مبللة جداً."],
      hot: ["حرّانة", "الجو حار جداً، أحتاج تظليلاً أو تبريداً."],
      cold: ["بردانة", "أشعر بالبرد، أحتاج مكاناً أدفأ."],
      need_light: ["تحتاج ضوء", "أحتاج إلى ضوء الشمس."],
      sleepy: ["نائمة", "تصبحون على خير… أنا نائمة."],
      unknown: ["…", "بانتظار البيانات"],
    },
    tracks: ["عطشانة", "غرقانة", "حرّانة", "بردانة", "تحتاج ضوء", "سعيدة", "شكراً", "تصبحون على خير", "مرحباً"],
  },
  en: {
    tagline: "Smart farming that turns your crops' feelings into emoji", signIn: "Sign in", createAccount: "Create account",
    email: "Email", password: "Password", fullName: "Full name", passwordHint: "At least 8 characters",
    signOut: "Sign out", admin: "Admin", navCrops: "My crops", navDevices: "Devices", navUsers: "Users",
    online: "Online", offline: "Offline",
    demoBanner: "Demo mode: simulated data (no XAMPP server).",
    serverError: "Cannot reach the server: check that Apache and MySQL are running in XAMPP",
    myCrops: "My crops", cropsHint: "Each crop has its own ideal values. A sensor device measures one crop and can be moved to another.",
    addCrop: "+ Add crop", newCrop: "New crop", cropName: "Crop name", cropNamePh: "e.g. Strawberry greenhouse 1",
    cropType: "Crop type", location: "Location", locationPh: "Greenhouse, farm, garden, balcony…", cancel: "Cancel", save: "Save",
    idealValues: "Ideal values", noCrops: "No crops yet. Add your first crop.", noData: "No data yet",
    noDevice: "No device", device: "Device", owner: "Owner", back: "← My crops",
    lastUpdate: "Last update", soil: "Soil moisture", temperature: "Temperature", humidity: "Air humidity", light: "Light",
    wifi: "Wi-Fi signal", history: "History (last 24 hours)", events: "Crop diary",
    speak: "Play a sound on the device", speakNow: "Play", settings: "Crop settings",
    moistureMin: "Thirsty below (%)", moistureMax: "Too wet above (%)", tempMin: "Cold below (°C)", tempMax: "Hot above (°C)",
    luxMin: "Needs light below (lux)", quietStart: "Silent from (hour)", quietEnd: "Silent until (hour)", muted: "Mute sound",
    saved: "Saved ✔", sent: "Request sent, the device will play it within 30 s",
    signalGood: "excellent", signalOk: "good", signalBad: "weak", noEvents: "No events yet",
    deleteCrop: "Delete this crop", confirmDelete: "Delete the crop and all its history?",
    cropDevice: "Sensor device of this crop", deviceOn: "Measuring this crop now: ", noDeviceHere: "No device on this crop. Choose a device and move it here.",
    moveHere: "Move to this crop", removeDevice: "Remove", chooseDevice: "Choose a device…", moved: "Device moved ✔ it will measure this crop within 30 s",
    noDevicesYet: "You have no devices. Add one on the Devices page.",
    devicesHint: "A device is the ESP32 with its sensors and buzzer. Put it in a crop and choose that crop here; move it whenever you want.",
    addDevice: "Add a device", addDeviceHint: "Enter the DEVICE_ID and DEVICE_KEY written in the device (firmware config.h).",
    deviceId: "Device ID", deviceKey: "Device key", deviceName: "Device name", add: "Add",
    adminDeviceHint: "Admin: a new ID is registered with this key; a user can then add it with the same ID and key.",
    measures: "Measures: ", notAssigned: "Not assigned to a crop", lastSeen: "Last seen: ", never: "never connected",
    moveTo: "Move to…", move: "Move", unassign: "Unassign", deviceAdded: "Device added ✔", deviceCreated: "New device registered ✔",
    newUser: "Create a user", role: "Role", roleUser: "User", roleAdmin: "Admin", userCreated: "User created ✔",
    del: "Delete", confirmDeleteUser: "Delete the user and all their crops?", you: "(you)",
    loginFailed: "Sign-in failed: check the email and password", other: "العربية",
    footer: "Rayy · smart farming · IoT graduation project",
    moods: {
      happy: ["Happy", "Everything is perfect, thank you!"],
      thirsty: ["Thirsty", "I am thirsty! Please water me."],
      drowning: ["Too wet", "Too much water! The soil is soaked."],
      hot: ["Too hot", "It is too hot, I need shade or cooling."],
      cold: ["Cold", "I feel cold, I need a warmer place."],
      need_light: ["Needs light", "I need more sunlight."],
      sleepy: ["Sleeping", "Good night… I am sleeping."],
      unknown: ["…", "Waiting for data"],
    },
    tracks: ["Thirsty", "Too wet", "Hot", "Cold", "Needs light", "Happy", "Thank you", "Good night", "Hello"],
  },
};
const EMOJI = { happy: "😊", thirsty: "😫", drowning: "🥴", hot: "🥵", cold: "🥶", need_light: "😞", sleepy: "😴", unknown: "🌱" };
const ONLINE_MS = 120000;     // a crop is "online" if its device sent data in the last 2 minutes

let lang = localStorageGet("lang") || "ar";
const state = {
  user: null, types: [], crops: [], devices: [], users: [],
  view: "crops", cropId: null,
  live: null, config: {}, device: null, type: null, history: [], events: [],
};
let call = null;        // function(path, body) → Promise<answer>: real API or demo
let token = localStorageGet("token");
let chart = null;
const timers = [];

function localStorageGet(k) { try { return localStorage.getItem(k); } catch { return null; } }
function localStorageSet(k, v) { try { localStorage.setItem(k, v); } catch { /* private mode */ } }
const t = (k) => TEXT[lang][k] ?? k;
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const typeName = (o) => (lang === "ar" ? o.type_ar ?? o.name_ar : o.type_en ?? o.name_en);

// ---------------------------------------------------------------------
//  Talking to the PHP API
// ---------------------------------------------------------------------
class ApiError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

async function realCall(path, body) {
  const res = await fetch(`${API}/${path}`, {
    method: body ? "POST" : "GET",
    headers: { "Content-Type": "application/json", ...(token ? { "X-Auth-Token": token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({ ok: false, error: `HTTP ${res.status}` }));
  if (!res.ok || !data.ok) throw new ApiError(res.status, data.error || `HTTP ${res.status}`);
  return data;
}

/** Calls the API; shows a banner when the server cannot be reached, signs out on 401. */
async function api(path, body) {
  try {
    const r = await call(path, body);
    $("serverError").classList.add("hidden");
    return r;
  } catch (e) {
    if (e.status === 401 && state.user) { signedOut(); throw e; }
    if (!e.status) {   // network error: Apache stopped, wrong address...
      $("serverError").textContent = `${t("serverError")} (${e.message})`;
      $("serverError").classList.remove("hidden");
    }
    throw e;
  }
}

function stopPolling() { timers.splice(0).forEach(clearInterval); }
function poll(fn, ms) {
  const run = () => fn().catch(() => { /* shown by api() */ });
  run();
  timers.push(setInterval(run, ms));
}

// ---------------------------------------------------------------------
//  Sign in / create account / sign out
// ---------------------------------------------------------------------
async function signedIn(r) {
  token = r.token;
  localStorageSet("token", token);
  state.user = r.user;
  history.replaceState(null, "", "#crops");      // always start on "My crops" after signing in
  showApp();
}

function signedOut() {
  stopPolling();
  token = null;
  localStorageSet("token", "");
  state.user = null;
  $("app").classList.add("hidden");
  $("login").classList.remove("hidden");
}

function showApp() {
  $("login").classList.add("hidden");
  $("app").classList.remove("hidden");
  $("userName").textContent = state.user.full_name;
  const admin = state.user.role === "admin";
  $("roleBadge").classList.toggle("hidden", !admin);
  document.querySelectorAll(".admin-only").forEach((el) => el.classList.toggle("hidden", !admin));
  api("crop_types.php").then((r) => { state.types = r.types; fillTypeSelects(); }).catch(() => {});
  route();
}

// ---------------------------------------------------------------------
//  Screens (routing with the address #...)
// ---------------------------------------------------------------------
function route() {
  if (!state.user) return;
  const [view, id] = (location.hash.slice(1) || "crops").split("/");
  stopPolling();
  state.view = ["crops", "crop", "devices", "users"].includes(view) ? view : "crops";
  if (state.view === "users" && state.user.role !== "admin") state.view = "crops";
  document.querySelectorAll(".view").forEach((v) => v.classList.add("hidden"));
  document.querySelectorAll(".nav a").forEach((a) => a.classList.toggle("active",
    a.dataset.view === state.view || (state.view === "crop" && a.dataset.view === "crops")));

  if (state.view === "crops") {
    $("viewCrops").classList.remove("hidden");
    poll(loadCrops, 10000);
  } else if (state.view === "crop") {
    state.cropId = Number(id);
    state.live = null; state.history = []; state.events = []; state.config = {};
    $("viewCrop").classList.remove("hidden");
    $("settingsMsg").textContent = ""; $("speakMsg").textContent = ""; $("deviceMsg").textContent = "";
    loadDevices().then(renderCropDevice).catch(() => {});
    poll(loadLive, 5000);
    poll(loadEvents, 15000);
    poll(loadHistory, 300000);
  } else if (state.view === "devices") {
    $("viewDevices").classList.remove("hidden");
    Promise.all([loadDevices(), loadCropsQuiet()]).then(renderDevices).catch(() => {});
  } else {
    $("viewUsers").classList.remove("hidden");
    loadUsers().catch(() => {});
  }
  window.scrollTo(0, 0);
}

// ---------------------------------------------------------------------
//  Crops list
// ---------------------------------------------------------------------
async function loadCrops() {
  state.crops = (await api("crops.php")).crops;
  renderCrops();
}
async function loadCropsQuiet() { state.crops = (await api("crops.php")).crops; }

const isOnline = (live) => live?.ts && Date.now() - live.ts < ONLINE_MS;

function renderCrops() {
  const grid = $("cropsGrid");
  if (!state.crops.length) {
    grid.innerHTML = `<div class="card empty full"><div class="big">🌾</div><p>${t("noCrops")}</p></div>`;
    return;
  }
  const admin = state.user.role === "admin";
  grid.innerHTML = state.crops.map((c) => {
    const mood = isOnline(c.live) && TEXT[lang].moods[c.live.mood] ? c.live.mood : null;
    const face = mood ? EMOJI[mood] : c.type_emoji;
    const status = mood ? TEXT[lang].moods[mood][0] : (c.live ? t("offline") : t("noData"));
    const v = c.live;
    return `<a class="card crop-card ${mood && !["happy", "sleepy"].includes(mood) ? "alert" : ""}" href="#crop/${c.crop_id}">
      <div class="top"><div><h3>${esc(c.name)}</h3>
        <div class="muted small">${c.type_emoji} ${esc(typeName(c))}${c.location ? " · " + esc(c.location) : ""}</div></div>
        <div class="big">${face}</div></div>
      <div><strong>${esc(status)}</strong></div>
      <div class="vals muted">${v ? `💧 <span>${show(v.moisture)}%</span> 🌡️ <span>${show(v.temperature, 1)}°C</span> ☀️ <span>${show(v.lux)} lux</span>` : ""}</div>
      <div class="small muted">📡 ${c.device ? esc(c.device.name) : t("noDevice")}${admin ? ` · 👤 ${esc(c.owner_name)}` : ""}</div>
    </a>`;
  }).join("");
}

function fillTypeSelects() {
  document.querySelectorAll(".type-select").forEach((sel) => {
    const v = sel.value;
    sel.innerHTML = state.types.map((ty) => `<option value="${ty.type_code}">${ty.emoji} ${esc(typeName(ty))}</option>`).join("");
    if (v) sel.value = v;
  });
  // the crop settings form shows the type of the open crop
  if (state.config.type_code) $("settingsForm").elements.type_code.value = state.config.type_code;
  updateTypePreview();
}

function updateTypePreview() {
  const sel = $("addCropForm").elements.type_code;
  const ty = state.types.find((x) => x.type_code === sel.value);
  $("addCropForm").querySelector(".type-preview").textContent = ty
    ? `${t("idealValues")}: 💧 ${ty.moisture_min}–${ty.moisture_max}% · 🌡️ ${ty.temp_min}–${ty.temp_max}°C · ☀️ ≥ ${ty.lux_min} lux` : "";
}

// ---------------------------------------------------------------------
//  One crop
// ---------------------------------------------------------------------
async function loadLive() {
  const r = await api(`live.php?crop=${state.cropId}`);
  const changed = JSON.stringify(r.config) !== JSON.stringify(state.config);
  Object.assign(state, { live: r.live, device: r.device, type: r.type });
  if (changed) { state.config = r.config; fillSettings(); }
  renderLive();
  renderCropDevice();
}
async function loadEvents() {
  state.events = (await api(`events.php?crop=${state.cropId}&limit=30`)).events;
  renderEvents();
}
async function loadHistory() {
  state.history = (await api(`history.php?crop=${state.cropId}&hours=24`)).history;
  renderChart();
}

const fmtTime = (ts) => ts ? new Date(ts).toLocaleString(lang === "ar" ? "ar-SA-u-ca-gregory-nu-latn" : "en-GB",
  { hour: "2-digit", minute: "2-digit", day: "numeric", month: "short" }) : "—";
const show = (v, digits = 0) => (v === undefined || v === null ? "—" : Number(v).toFixed(digits));

function renderLive() {
  if (state.view !== "crop") return;
  const l = state.live;
  const mood = l?.mood && TEXT[lang].moods[l.mood] ? l.mood : "unknown";
  const [title, text] = TEXT[lang].moods[mood];
  $("moodEmoji").textContent = EMOJI[mood];
  $("moodTitle").textContent = title;
  $("moodText").textContent = text;
  $("hero").classList.toggle("alert", !["happy", "sleepy", "unknown"].includes(mood));
  $("cropName").textContent = state.config.name || "…";
  $("cropTypeEmoji").textContent = state.type?.emoji || "";
  $("cropMeta").textContent = [state.type ? typeName(state.type) : "", state.config.location].filter(Boolean).join(" · ");
  document.title = `${EMOJI[mood]} ${state.config.name || ""} · ري`;

  $("lastUpdate").textContent = fmtTime(l?.ts);
  $("vMoisture").textContent = show(l?.moisture);
  $("vTemp").textContent = show(l?.temperature, 1);
  $("vHum").textContent = show(l?.humidity);
  $("vLux").textContent = show(l?.lux);
  $("vRssi").textContent = show(l?.rssi);
  $("vSignal").textContent = l?.rssi == null ? "" : t(l.rssi > -60 ? "signalGood" : l.rssi > -75 ? "signalOk" : "signalBad");
  const bm = $("barMoisture");
  bm.style.width = `${l?.moisture ?? 0}%`;
  bm.className = l?.moisture < (state.config.moisture_min ?? 30) ? "low" : l?.moisture > (state.config.moisture_max ?? 85) ? "high" : "";

  const online = isOnline(l);
  $("onlineBadge").textContent = online ? t("online") : t("offline");
  $("onlineBadge").className = `badge dark ${online ? "on" : "off"}`;
}

function renderCropDevice() {
  if (state.view !== "crop") return;
  const d = state.device;
  $("cropDeviceText").textContent = d ? `${t("deviceOn")}${d.name} (${d.device_id})` : t("noDeviceHere");
  $("removeDeviceBtn").classList.toggle("hidden", !d);
  const others = state.devices.filter((x) => !d || x.device_id !== d.device_id);
  const sel = $("moveDeviceSelect");
  sel.innerHTML = `<option value="">${t("chooseDevice")}</option>` + others.map((x) =>
    `<option value="${esc(x.device_id)}">${esc(x.name)} (${esc(x.device_id)})${x.crop ? " · " + x.crop.emoji + " " + esc(x.crop.name) : ""}</option>`).join("");
  $("moveDeviceBtn").disabled = !others.length;
  if (!state.devices.length) $("deviceMsg").textContent = t("noDevicesYet");
}

function renderEvents() {
  const ul = $("events");
  if (!state.events.length) { ul.innerHTML = `<li class="muted">${t("noEvents")}</li>`; return; }
  ul.innerHTML = state.events.map((e) => {
    const m = TEXT[lang].moods[e.mood] ? e.mood : "unknown";
    return `<li><span class="e-emoji">${EMOJI[m]}</span><div><div>${esc(TEXT[lang].moods[m][1])}</div><div class="e-time">${fmtTime(e.ts)}</div></div></li>`;
  }).join("");
}

function renderChart() {
  if (!window.Chart || state.view !== "crop") return;
  const metric = $("chartMetric").value;
  const pts = state.history.filter((p) => p[metric] !== undefined && p[metric] !== null && p.ts);
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
    else if (v !== undefined) el.value = v ?? "";
  }
}

// ---------------------------------------------------------------------
//  Devices
// ---------------------------------------------------------------------
async function loadDevices() { state.devices = (await api("devices.php")).devices; }

function renderDevices() {
  const list = $("devicesList");
  if (!state.devices.length) {
    list.innerHTML = `<div class="card empty full"><div class="big">📡</div><p>${t("noDevicesYet")}</p></div>`;
    return;
  }
  const options = state.crops.map((c) => `<option value="${c.crop_id}">${c.type_emoji} ${esc(c.name)}</option>`).join("");
  list.innerHTML = state.devices.map((d) => `<div class="card device-card">
      <div class="top"><h3>📡 ${esc(d.name)}</h3><span class="muted small" dir="ltr">${esc(d.device_id)}</span></div>
      <div>${d.crop ? `${t("measures")}<a href="#crop/${d.crop.crop_id}">${d.crop.emoji} ${esc(d.crop.name)}</a>` : `<span class="muted">${t("notAssigned")}</span>`}</div>
      <div class="muted small">${t("lastSeen")}${d.last_seen ? fmtTime(d.last_seen) : t("never")}${d.owner_name ? " · 👤 " + esc(d.owner_name) : ""}</div>
      <div class="speak-row">
        <select data-device="${esc(d.device_id)}"><option value="">${t("moveTo")}</option>${options}</select>
        <button class="btn primary" data-move="${esc(d.device_id)}">${t("move")}</button>
        ${d.crop ? `<button class="btn" data-unassign="${esc(d.device_id)}">${t("unassign")}</button>` : ""}
      </div>
    </div>`).join("");
}

async function assignDevice(deviceId, cropId) {
  await api("device_assign.php", { device_id: deviceId, crop_id: cropId });
  await loadDevices();
}

// ---------------------------------------------------------------------
//  Users (admin)
// ---------------------------------------------------------------------
async function loadUsers() {
  state.users = (await api("users.php")).users;
  $("usersBody").innerHTML = state.users.map((u) => {
    const me = u.user_id === state.user.user_id;
    return `<tr>
      <td>${esc(u.full_name)} ${me ? `<span class="muted">${t("you")}</span>` : ""}</td>
      <td dir="ltr">${esc(u.email)}</td>
      <td><select data-role="${u.user_id}" ${me ? "disabled" : ""}>
        <option value="user" ${u.role === "user" ? "selected" : ""}>${t("roleUser")}</option>
        <option value="admin" ${u.role === "admin" ? "selected" : ""}>${t("roleAdmin")}</option></select></td>
      <td>${u.crops}</td><td>${u.devices}</td>
      <td>${me ? "" : `<button class="btn small" data-deluser="${u.user_id}">${t("del")}</button>`}</td></tr>`;
  }).join("");
}

// ---------------------------------------------------------------------
//  Language
// ---------------------------------------------------------------------
function applyLanguage() {
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
  document.querySelectorAll("[data-i18n]").forEach((el) => (el.textContent = t(el.dataset.i18n)));
  document.querySelectorAll("[data-i18n-ph]").forEach((el) => (el.placeholder = t(el.dataset.i18nPh)));
  document.querySelectorAll(".lang-toggle").forEach((b) => (b.textContent = t("other")));
  $("trackSelect").innerHTML = TEXT[lang].tracks.map((n, i) => `<option value="${i + 1}">${i + 1}. ${n}</option>`).join("");
  fillTypeSelects();
  if (!state.user) return;
  if (state.view === "crops") renderCrops();
  if (state.view === "crop") { renderLive(); renderEvents(); renderChart(); renderCropDevice(); }
  if (state.view === "devices") renderDevices();
  if (state.view === "users") loadUsers().catch(() => {});
}

// ---------------------------------------------------------------------
//  Buttons and forms
// ---------------------------------------------------------------------
const formData = (form) => {
  const o = {};
  for (const el of form.elements) {
    if (!el.name) continue;
    if (el.type === "checkbox") o[el.name] = el.checked;
    else if (el.type === "number") { if (el.value !== "") o[el.name] = Number(el.value); }
    else o[el.name] = el.value.trim();
  }
  return o;
};
const message = (el, text, ok = true) => { el.textContent = text; el.className = `small ${ok ? "ok" : "error"} ${el.className.includes("full") ? "full" : ""}`; };

function bindUi() {
  document.querySelectorAll(".lang-toggle").forEach((b) => b.addEventListener("click", () => {
    lang = lang === "ar" ? "en" : "ar";
    localStorageSet("lang", lang);
    applyLanguage();
  }));
  window.addEventListener("hashchange", route);

  // sign in / create account tabs
  document.querySelectorAll(".tab").forEach((b) => b.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach((x) => x.classList.toggle("active", x === b));
    $("loginForm").classList.toggle("hidden", b.dataset.tab !== "signin");
    $("registerForm").classList.toggle("hidden", b.dataset.tab !== "register");
    $("loginError").textContent = "";
  }));
  $("loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    $("loginError").textContent = "";
    try { await signedIn(await api("login.php", { email: $("email").value.trim(), password: $("password").value })); }
    catch (err) { $("loginError").textContent = err.status === 401 ? t("loginFailed") : err.message; }
  });
  $("registerForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    $("loginError").textContent = "";
    try {
      await signedIn(await api("register.php", { full_name: $("regName").value.trim(), email: $("regEmail").value.trim(), password: $("regPassword").value }));
    } catch (err) { $("loginError").textContent = err.message; }
  });
  $("logoutBtn").addEventListener("click", async () => {
    try { await api("logout.php", {}); } catch { /* already signed out */ }
    signedOut();
  });

  // crops
  $("addCropBtn").addEventListener("click", () => { $("addCropForm").classList.remove("hidden"); $("addCropForm").elements.name.focus(); });
  $("cancelCropBtn").addEventListener("click", () => $("addCropForm").classList.add("hidden"));
  $("addCropForm").elements.type_code.addEventListener("change", updateTypePreview);
  $("addCropForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      const r = await api("crops.php", formData(e.target));
      e.target.reset(); e.target.classList.add("hidden");
      location.hash = `#crop/${r.crop_id}`;
    } catch (err) { message($("addCropMsg"), err.message, false); }
  });

  // one crop
  $("chartMetric").addEventListener("change", renderChart);
  $("speakBtn").addEventListener("click", async () => {
    try { await api(`command.php?crop=${state.cropId}`, { play: Number($("trackSelect").value) }); message($("speakMsg"), t("sent")); }
    catch (err) { message($("speakMsg"), err.message, false); }
  });
  // choosing another crop type fills its ideal values (they can still be edited)
  $("settingsForm").elements.type_code.addEventListener("change", (e) => {
    const ty = state.types.find((x) => x.type_code === e.target.value);
    if (!ty) return;
    for (const k of ["moisture_min", "moisture_max", "temp_min", "temp_max", "lux_min"]) $("settingsForm").elements[k].value = ty[k];
  });
  $("settingsForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      await api(`crop_update.php?crop=${state.cropId}`, formData(e.target));
      message($("settingsMsg"), t("saved"));
      await loadLive();                            // new name / type / thresholds
    } catch (err) { message($("settingsMsg"), err.message, false); }
  });
  $("deleteCropBtn").addEventListener("click", async () => {
    if (!confirm(t("confirmDelete"))) return;
    try { await api(`crop_delete.php?crop=${state.cropId}`, {}); location.hash = "#crops"; }
    catch (err) { message($("settingsMsg"), err.message, false); }
  });
  $("moveDeviceBtn").addEventListener("click", async () => {
    const id = $("moveDeviceSelect").value;
    if (!id) return;
    try { await assignDevice(id, state.cropId); await loadLive(); message($("deviceMsg"), t("moved")); }
    catch (err) { message($("deviceMsg"), err.message, false); }
  });
  $("removeDeviceBtn").addEventListener("click", async () => {
    if (!state.device) return;
    try { await assignDevice(state.device.device_id, null); await loadLive(); }
    catch (err) { message($("deviceMsg"), err.message, false); }
  });

  // devices
  $("devicesList").addEventListener("click", async (e) => {
    const move = e.target.dataset.move, un = e.target.dataset.unassign;
    if (!move && !un) return;
    try {
      if (move) {
        const crop = e.target.parentElement.querySelector("select").value;
        if (!crop) return;
        await assignDevice(move, Number(crop));
      } else await assignDevice(un, null);
      await loadCropsQuiet(); renderDevices();
    } catch (err) { alert(err.message); }
  });
  $("addDeviceForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      const r = await api("devices.php", formData(e.target));
      e.target.reset();
      message($("addDeviceMsg"), t(r.created ? "deviceCreated" : "deviceAdded"));
      await loadDevices(); renderDevices();
    } catch (err) { message($("addDeviceMsg"), err.message, false); }
  });

  // users (admin)
  $("addUserForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      await api("users.php", { action: "create", ...formData(e.target) });
      e.target.reset();
      message($("addUserMsg"), t("userCreated"));
      await loadUsers();
    } catch (err) { message($("addUserMsg"), err.message, false); }
  });
  $("usersBody").addEventListener("change", async (e) => {
    const id = Number(e.target.dataset.role);
    if (!id) return;
    try { await api("users.php", { action: "role", user_id: id, role: e.target.value }); message($("usersMsg"), t("saved")); }
    catch (err) { message($("usersMsg"), err.message, false); loadUsers(); }
  });
  $("usersBody").addEventListener("click", async (e) => {
    const id = Number(e.target.dataset.deluser);
    if (!id || !confirm(t("confirmDeleteUser"))) return;
    try { await api("users.php", { action: "delete", user_id: id }); await loadUsers(); }
    catch (err) { message($("usersMsg"), err.message, false); }
  });
}

// ---------------------------------------------------------------------
//  Demo mode: a small fake server in the browser (no XAMPP needed)
// ---------------------------------------------------------------------
function demoServer() {
  const now = Date.now();
  const types = [
    ["strawberry", "فراولة", "Strawberry", "🍓", 60, 85, 10, 28, 5000], ["tomato", "طماطم", "Tomato", "🍅", 50, 80, 15, 32, 8000],
    ["mint", "نعناع", "Mint", "🌿", 55, 85, 10, 30, 2000], ["cactus", "صبار", "Cactus", "🌵", 10, 40, 10, 40, 5000],
    ["other", "أخرى", "Other", "🌾", 30, 85, 10, 35, 200],
  ].map(([type_code, name_ar, name_en, emoji, moisture_min, moisture_max, temp_min, temp_max, lux_min]) =>
    ({ type_code, name_ar, name_en, emoji, moisture_min, moisture_max, temp_min, temp_max, lux_min }));
  const T = (code) => types.find((x) => x.type_code === code);
  const user = { user_id: 1, email: "admin@rayy.app", full_name: "Rayy Admin", role: "admin" };
  let nextId = 4;
  const crops = [
    { crop_id: 1, name: "فراولة البيت المحمي", location: "Greenhouse 1", type_code: "strawberry", m: 72 },
    { crop_id: 2, name: "طماطم المزرعة", location: "Farm A", type_code: "tomato", m: 41 },
    { crop_id: 3, name: "نعناع الحديقة", location: "Garden", type_code: "mint", m: 66 },
  ].map((c) => ({ ...c, ...T(c.type_code), quiet_start: 22, quiet_end: 7, muted: false }));
  const devices = [{ device_id: "rayy-01", name: "Rayy sensor 1", crop_id: 1 }];
  const users = [{ ...user, crops: 3, devices: 1 }, { user_id: 2, email: "sara@test.com", full_name: "Sara", role: "user", crops: 0, devices: 0 }];
  const cfg = (c) => ({ name: c.name, location: c.location, type_code: c.type_code, moisture_min: c.moisture_min, moisture_max: c.moisture_max,
    temp_min: c.temp_min, temp_max: c.temp_max, lux_min: c.lux_min, quiet_start: c.quiet_start, quiet_end: c.quiet_end, muted: c.muted });
  const mood = (c, m) => m < c.moisture_min ? "thirsty" : m > c.moisture_max ? "drowning" : "happy";
  const live = (c) => {
    const dev = devices.find((d) => d.crop_id === c.crop_id);
    const m = c.m + Math.round(Math.random() * 2 - 1);
    return dev || c.crop_id === 2 ? { moisture: m, temperature: 26.5, humidity: 41, lux: 6200, rssi: -58, mood: mood(c, m),
      device_id: "rayy-01", ts: dev ? Date.now() : now - 3600e3 } : null;
  };
  const dev = (c) => { const d = devices.find((x) => x.crop_id === c.crop_id); return d ? { device_id: d.device_id, name: d.name } : null; };
  const cropJson = (c) => ({ crop_id: c.crop_id, name: c.name, location: c.location, type_code: c.type_code, type_ar: T(c.type_code).name_ar,
    type_en: T(c.type_code).name_en, type_emoji: T(c.type_code).emoji, owner_name: user.full_name, device: dev(c), live: live(c), config: cfg(c) });
  const history = (c) => Array.from({ length: 288 }, (_, i) => {
    const ts = now - (287 - i) * 300000, h = new Date(ts).getHours();
    const sun = Math.max(0, Math.sin(((h - 6) / 12) * Math.PI));
    return { ts, moisture: Math.round(c.m + 15 - ((i % 150) * 0.2)), temperature: +(20 + sun * 12).toFixed(1), humidity: Math.round(50 - sun * 15), lux: Math.round(sun * 9000) };
  });
  const find = (p) => crops.find((c) => c.crop_id === Number(new URLSearchParams(p.split("?")[1]).get("crop")));

  return async (path, body) => {
    const p = path.split("?")[0];
    if (p === "login.php" || p === "register.php") return { ok: true, token: "demo", user };
    if (p === "logout.php") return { ok: true };
    if (p === "me.php") return { ok: true, user };
    if (p === "crop_types.php") return { ok: true, types };
    if (p === "crops.php" && body) {
      const c = { crop_id: nextId++, name: body.name, location: body.location, ...T(body.type_code), quiet_start: 22, quiet_end: 7, muted: false, m: 50 };
      crops.push(c);
      return { ok: true, crop_id: c.crop_id };
    }
    if (p === "crops.php") return { ok: true, crops: crops.map(cropJson) };
    const c = find(path);
    if (p === "live.php") return { ok: true, live: live(c), config: cfg(c), device: dev(c), type: T(c.type_code) };
    if (p === "history.php") return { ok: true, history: dev(c) ? history(c) : [] };
    if (p === "events.php") return { ok: true, events: [{ ts: now - 3 * 3600e3, mood: "happy" }, { ts: now - 9 * 3600e3, mood: "thirsty" }] };
    if (p === "command.php") return { ok: true };
    if (p === "crop_update.php") {
      if (body.type_code && body.type_code !== c.type_code) Object.assign(c, T(body.type_code));
      Object.assign(c, body);
      return { ok: true, config: cfg(c) };
    }
    if (p === "crop_delete.php") { crops.splice(crops.indexOf(c), 1); return { ok: true }; }
    if (p === "devices.php" && body) throw new ApiError(400, "Demo mode");
    if (p === "devices.php") return { ok: true, devices: devices.map((d) => {
      const cc = crops.find((x) => x.crop_id === d.crop_id);
      return { ...d, last_seen: Date.now(), owner_name: user.full_name, crop: cc ? { crop_id: cc.crop_id, name: cc.name, emoji: T(cc.type_code).emoji } : null };
    }) };
    if (p === "device_assign.php") { devices[0].crop_id = body.crop_id; return { ok: true }; }
    if (p === "users.php" && !body) return { ok: true, users };
    if (p === "users.php") return { ok: true };
    throw new ApiError(404, "Unknown demo path " + p);
  };
}

// ---------------------------------------------------------------------
async function main() {
  bindUi();
  applyLanguage();
  // Demo mode: ?demo=1, or the page was opened as a file (not through Apache)
  const demo = new URLSearchParams(location.search).has("demo") || location.protocol === "file:";
  call = demo ? demoServer() : realCall;
  $("demoBanner").classList.toggle("hidden", !demo);

  if (demo) return signedIn(await call("login.php", {}));
  if (!token) { $("login").classList.remove("hidden"); return; }
  try { state.user = (await api("me.php")).user; showApp(); }
  catch { signedOut(); }
}

main();
