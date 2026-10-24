const state = {
  token: localGet('shanta_token'),
  user: null,
  lang: localGet('shanta_lang') || 'en',
  meta: null,
  registering: false,
};

function localGet(k) { try { return localStorage.getItem(k); } catch { return null; } }
function localSet(k, v) { try { v == null ? localStorage.removeItem(k) : localStorage.setItem(k, v); } catch { /* private mode */ } }

const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const t = (key, fallback) => I18N[state.lang]?.[key] ?? fallback ?? key;

async function api(method, path, body) {
  const res = await fetch(`/api${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(state.token && { Authorization: `Bearer ${state.token}` }) },
    body: body && JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || (data.errors || []).join(' • ') || res.statusText);
  return data;
}

function toast(msg, isError) {
  const el = $('#toast');
  el.textContent = msg;
  el.className = isError ? 'show error' : 'show';
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (el.className = ''), 3500);
}

function formData(form) {
  const o = {};
  for (const el of form.elements) {
    if (!el.name) continue;
    if (el.type === 'checkbox') o[el.name] = el.checked;
    else if (el.type === 'number') o[el.name] = el.value === '' ? undefined : Number(el.value);
    else if (el.value !== '') o[el.name] = el.value;
  }
  return o;
}

// ---- i18n -------------------------------------------------------------------
function applyLang() {
  document.documentElement.lang = state.lang;
  document.documentElement.dir = state.lang === 'ar' ? 'rtl' : 'ltr';
  for (const el of $$('[data-i18n]')) {
    el.dataset.en ??= el.textContent;
    el.textContent = state.lang === 'en' ? el.dataset.en : t(el.dataset.i18n, el.dataset.en);
  }
  $('#langBtn').textContent = state.lang === 'en' ? 'العربية' : 'English';
  renderAuthButton();
}

// ---- routing ----------------------------------------------------------------
function route() {
  const id = (location.hash || '#search').slice(1);
  for (const v of $$('.view')) v.hidden = v.id !== id;
  for (const a of $$('.topbar nav a')) a.classList.toggle('active', a.getAttribute('href') === `#${id}`);
  if (id === 'bookings') loadBookings();
}

// ---- auth -------------------------------------------------------------------
function renderAuthButton() {
  $('#authBtn').textContent = state.user ? `${t('logout', 'Log out')} (${state.user.name.split(' ')[0]})` : t('login', 'Log in');
}

function openAuth() {
  state.registering = false;
  setAuthMode();
  $('#authDialog').showModal();
}

function setAuthMode() {
  for (const el of $$('#authForm .reg')) el.hidden = !state.registering;
  $('#authTitle').textContent = state.registering ? t('register', 'Create account') : t('login', 'Log in');
  $('#authToggle').textContent = state.registering ? t('have_account', 'I have an account') : t('no_account', 'Create account');
  $('#authError').textContent = '';
}

async function submitAuth(e) {
  e.preventDefault();
  const d = formData(e.target);
  try {
    const out = state.registering
      ? await api('POST', '/auth/register', d)
      : await api('POST', '/auth/login', { email: d.email, password: d.password });
    state.token = out.token;
    localSet('shanta_token', out.token);
    await loadMe();
    $('#authDialog').close();
    route();
  } catch (err) {
    $('#authError').textContent = err.message;
  }
}

async function loadMe() {
  if (!state.token) return;
  try { state.user = await api('GET', '/me'); } catch { state.token = null; localSet('shanta_token', null); state.user = null; }
  renderAuthButton();
}

function requireLogin() {
  if (state.user) return true;
  toast(t('login_first', 'Please log in first'), true);
  openAuth();
  return false;
}

// ---- search -----------------------------------------------------------------
function tripCard(trip, extra = '') {
  const kyc = trip.traveler_kyc === 'verified' ? `<span class="badge">✔ ${esc(t('verified', 'Verified'))}</span>` : '';
  return `<article class="card">
    <div class="route"><b>${esc(trip.from_city)}</b> <small>${esc(trip.from_country)}</small> → <b>${esc(trip.to_city)}</b> <small>${esc(trip.to_country)}</small></div>
    <div class="muted">✈ ${esc(trip.depart_date)} → ${esc(trip.arrive_date)}</div>
    <div>${esc(t('traveler', 'Traveler'))}: ${esc(trip.traveler_name)} ${kyc}</div>
    <div class="row"><span class="big"><bdi>${esc(trip.price_per_kg)} ${esc(trip.currency)}</bdi>${esc(t('per_kg', '/kg'))}</span>
      <span class="muted"><bdi>${esc(trip.available_kg)}</bdi> ${esc(t('kg_left', 'kg free'))}</span></div>
    ${extra}
  </article>`;
}

async function search(e) {
  e?.preventDefault();
  const q = new URLSearchParams(Object.entries(formData($('#searchForm'))).filter(([, v]) => v !== undefined && v !== ''));
  const trips = await api('GET', `/trips?${q}`);
  $('#results').innerHTML = trips.length ? trips.map((x) => tripCard(x)).join('') : `<p class="muted">${esc(t('no_results', 'No matching travelers yet. Post a request and we will notify you.'))}</p>`;
}

// ---- trips ------------------------------------------------------------------
async function postTrip(e) {
  e.preventDefault();
  if (!requireLogin()) return;
  try {
    await api('POST', '/trips', formData(e.target));
    toast(t('saved', 'Saved'));
    e.target.reset();
    location.hash = '#search';
  } catch (err) { toast(err.message, true); }
}

// ---- requests ---------------------------------------------------------------
async function liveCheck() {
  const d = formData($('#requestForm'));
  if (!d.weight_kg || d.declared_value === undefined) return;
  const r = await api('POST', '/requests/check', d);
  const box = $('#checkBox');
  const items = [...r.errors.map((x) => `<li class="err">⛔ ${esc(x)}</li>`), ...r.warnings.map((x) => `<li>⚠️ ${esc(x)}</li>`)];
  box.hidden = !items.length;
  box.innerHTML = `<ul>${items.join('')}</ul>`;
}

async function postRequest(e) {
  e.preventDefault();
  if (!requireLogin()) return;
  try {
    const req = await api('POST', '/requests', formData(e.target));
    toast(t('saved', 'Saved'));
    const matches = await api('GET', `/requests/${req.id}/matches`);
    $('#matches').innerHTML = matches.length
      ? matches.map((m) => tripCard(m, `<div class="row"><span>${esc(t('reward', 'Reward'))}: <b>${esc(m.estimated_reward)} ${esc(m.currency)}</b></span>
          <button data-book="${m.id}" data-req="${req.id}">${esc(t('book', 'Book'))}</button></div>`)).join('')
      : `<p class="muted">${esc(t('no_results'))}</p>`;
  } catch (err) { toast(err.message, true); }
}

async function book(tripId, requestId) {
  try {
    await api('POST', '/bookings', { trip_id: Number(tripId), request_id: Number(requestId) });
    location.hash = '#bookings';
  } catch (err) { toast(err.message, true); }
}

// ---- bookings ---------------------------------------------------------------
const ACTIONS_FOR = {
  proposed: ['accept', 'decline', 'cancel'],
  accepted: ['pay', 'cancel'],
  paid: ['inspect', 'cancel'],
  inspected: ['depart', 'dispute'],
  in_transit: ['deliver', 'dispute'],
};

async function loadBookings() {
  if (!state.user) { $('#bookingList').innerHTML = ''; return requireLogin(); }
  await loadMe();
  $('#kycBox').hidden = state.user.kyc_status === 'verified';
  const list = await api('GET', '/bookings');
  $('#bookingList').innerHTML = list.length ? list.map((b) => {
    const role = b.traveler_id === state.user.id ? 'traveler' : 'sender';
    const buttons = (ACTIONS_FOR[b.status] || []).filter((a) => !(['accept', 'decline'].includes(a) && b.proposed_by === state.user.id)).map((a) => `<button class="${a === 'cancel' || a === 'decline' || a === 'dispute' ? 'ghost' : ''}" data-act="${a}" data-id="${b.id}">${esc(t(a, a))}</button>`).join('');
    const code = b.delivery_code ? `<div class="notice">${esc(t('delivery_code', 'Delivery code (give it to the traveler only on receipt)'))}: <b>${esc(b.delivery_code)}</b></div>` : '';
    return `<article class="card">
      <div class="route"><b>#${b.id} ${esc(b.title)}</b> · ${esc(b.weight_kg)} kg</div>
      <div>${esc(t('status', 'Status'))}: <span class="badge s-${esc(b.status)}">${esc(b.status)}</span> · ${esc(t(role, role))}</div>
      <div>${esc(t('reward', 'Reward'))}: ${esc(b.reward)} ${esc(b.currency)}</div>
      ${code}<div class="row wrap">${buttons}</div>
    </article>`;
  }).join('') : `<p class="muted">${esc(t('no_bookings', 'No bookings yet.'))}</p>`;
}

async function bookingAction(id, action) {
  let body;
  if (action === 'inspect') {
    const ok = confirm('I opened the item, it matches the description, and it contains no prohibited items.\n\nفتحت الغرض، وهو مطابق للوصف، ولا يحتوي على ممنوعات.');
    if (!ok) return;
    body = { opened: true, matches_description: true, no_prohibited_items: true };
  }
  if (action === 'deliver') {
    const code = prompt('Delivery code from the recipient / كود التسليم من المستلم');
    if (!code) return;
    body = { delivery_code: code };
  }
  if (action === 'pay') {
    // In production this opens the payment provider's checkout (e.g. Paymob, Fawry, Tap, Checkout.com)
    // and the provider's webhook moves the booking to "paid".
    if (!confirm('Demo: simulate paying into escrow?')) return;
  }
  try { await api('POST', `/bookings/${id}/${action}`, body); loadBookings(); } catch (err) { toast(err.message, true); }
}

// ---- init -------------------------------------------------------------------
async function init() {
  state.meta = await api('GET', '/meta');
  const opts = Object.entries(state.meta.countries).map(([c, n]) => `<option value="${c}">${esc(n)}</option>`).join('');
  for (const s of $$('select.country')) s.innerHTML = `<option value="">—</option>${opts}`;
  const { allowed, restricted, prohibited } = state.meta.categories;
  $('#categorySelect').innerHTML = [...allowed, ...Object.keys(restricted)].map((c) => `<option value="${c}">${esc(c.replace(/_/g, ' '))}</option>`).join('')
    + Object.keys(prohibited).map((c) => `<option value="${c}">⛔ ${esc(c.replace(/_/g, ' '))}</option>`).join('');
  $('#prohibitedList').innerHTML = Object.values(prohibited).map((x) => `<li>⛔ ${esc(x)}</li>`).join('');
  $('#restrictedList').innerHTML = Object.entries(restricted).map(([k, x]) => `<li><b>${esc(k)}</b>: ${esc(x)}</li>`).join('');

  const sf = $('#searchForm');
  sf.from.value = 'SA'; sf.to.value = 'EG';

  $('#langBtn').onclick = () => { state.lang = state.lang === 'en' ? 'ar' : 'en'; localSet('shanta_lang', state.lang); applyLang(); };
  $('#authBtn').onclick = () => {
    if (state.user) { state.user = null; state.token = null; localSet('shanta_token', null); renderAuthButton(); route(); } else openAuth();
  };
  $('#authToggle').onclick = () => { state.registering = !state.registering; setAuthMode(); };
  $('#authClose').onclick = () => $('#authDialog').close();
  $('#authForm').onsubmit = submitAuth;
  sf.onsubmit = search;
  $('#tripForm').onsubmit = postTrip;
  $('#requestForm').onsubmit = postRequest;
  $('#requestForm').addEventListener('change', liveCheck);
  $('#kycBtn').onclick = async () => { await api('POST', '/me/kyc'); loadBookings(); };
  document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-book]');
    if (b) return book(b.dataset.book, b.dataset.req);
    const a = e.target.closest('[data-act]');
    if (a) bookingAction(a.dataset.id, a.dataset.act);
  });
  window.addEventListener('hashchange', route);

  await loadMe();
  applyLang();
  route();
  search();
}

init().catch((e) => toast(e.message, true));
