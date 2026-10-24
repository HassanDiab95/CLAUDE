import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';
import { hashPassword, verifyPassword, signToken, requireAuth, publicUser } from './auth.js';
import {
  COUNTRIES, PROHIBITED, RESTRICTED, ALLOWED, checkRequest, tripFitsRequest,
  TRANSITIONS, ACTOR, arrivalCapUsd,
} from './rules.js';

const WEB_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '../../web');

const userRating = (db, id) =>
  db.prepare('SELECT ROUND(AVG(stars), 1) AS avg, COUNT(*) AS count FROM reviews WHERE subject_id = ?').get(id);

export function createApp(db) {
  const app = express();
  app.use(express.json({ limit: '100kb' }));
  app.use((req, res, next) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });

  const auth = requireAuth(db);
  const api = express.Router();

  // ---- Reference data -------------------------------------------------------
  api.get('/meta', (req, res) => {
    res.json({
      countries: COUNTRIES,
      categories: { allowed: ALLOWED, restricted: RESTRICTED, prohibited: PROHIBITED },
      arrival_caps_usd: Object.fromEntries(Object.keys(COUNTRIES).map((c) => [c, arrivalCapUsd(c)])),
    });
  });

  // ---- Auth -----------------------------------------------------------------
  api.post('/auth/register', (req, res) => {
    const { name, email, phone, country, password, accept_terms } = req.body ?? {};
    if (!name || !email || !password || !country) return res.status(400).json({ error: 'name, email, country and password are required' });
    if (password.length < 8) return res.status(400).json({ error: 'Password must be at least 8 characters' });
    if (!COUNTRIES[country]) return res.status(400).json({ error: 'Unsupported country' });
    if (accept_terms !== true) return res.status(400).json({ error: 'You must accept the terms and the prohibited-items policy' });
    if (db.prepare('SELECT 1 FROM users WHERE email = ?').get(email.toLowerCase())) {
      return res.status(409).json({ error: 'Email already registered' });
    }
    const r = db.prepare(`INSERT INTO users (name, email, phone, country, password_hash, accepted_terms_at)
      VALUES (?, ?, ?, ?, ?, datetime('now'))`).run(name, email.toLowerCase(), phone ?? null, country, hashPassword(password));
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(r.lastInsertRowid);
    res.status(201).json({ token: signToken(user.id), user: publicUser(user) });
  });

  api.post('/auth/login', (req, res) => {
    const { email, password } = req.body ?? {};
    const user = email && db.prepare('SELECT * FROM users WHERE email = ?').get(email.toLowerCase());
    if (!user || !verifyPassword(password ?? '', user.password_hash)) return res.status(401).json({ error: 'Invalid email or password' });
    res.json({ token: signToken(user.id), user: publicUser(user) });
  });

  api.get('/me', auth, (req, res) => res.json({ ...publicUser(req.user), email: req.user.email, rating: userRating(db, req.user.id) }));

  // Placeholder for a real KYC provider (e.g. Sumsub, Onfido, Valify in Egypt).
  // In production the provider's webhook sets 'verified'; here we simulate it.
  api.post('/me/kyc', auth, (req, res) => {
    const next = process.env.SHANTA_AUTO_KYC === '0' ? 'pending' : 'verified';
    db.prepare('UPDATE users SET kyc_status = ? WHERE id = ?').run(next, req.user.id);
    res.json({ kyc_status: next });
  });

  api.get('/users/:id', (req, res) => {
    const u = db.prepare('SELECT * FROM users WHERE id = ?').get(req.params.id);
    if (!u) return res.status(404).json({ error: 'Not found' });
    res.json({ ...publicUser(u), rating: userRating(db, u.id) });
  });

  // ---- Trips (travelers offering spare kg) -----------------------------------
  api.post('/trips', auth, (req, res) => {
    const t = req.body ?? {};
    const errors = [];
    if (!COUNTRIES[t.from_country] || !COUNTRIES[t.to_country]) errors.push('Valid from_country and to_country are required');
    if (t.from_country === t.to_country) errors.push('Origin and destination must differ');
    if (!t.from_city || !t.to_city) errors.push('Cities are required');
    if (!t.depart_date || !t.arrive_date || t.arrive_date < t.depart_date) errors.push('Valid depart_date and arrive_date are required');
    if (!(t.available_kg > 0 && t.available_kg <= 46)) errors.push('available_kg must be between 0 and 46');
    if (!(t.price_per_kg >= 0)) errors.push('price_per_kg is required');
    if (errors.length) return res.status(400).json({ errors });

    const r = db.prepare(`INSERT INTO trips (traveler_id, from_country, from_city, to_country, to_city, depart_date, arrive_date,
      available_kg, price_per_kg, currency, accepts_buy_for_me, accepts_handover, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
      req.user.id, t.from_country, t.from_city, t.to_country, t.to_city, t.depart_date, t.arrive_date,
      t.available_kg, t.price_per_kg, t.currency ?? 'USD', t.accepts_buy_for_me === false ? 0 : 1, t.accepts_handover ? 1 : 0, t.notes ?? null);
    res.status(201).json(db.prepare('SELECT * FROM trips WHERE id = ?').get(r.lastInsertRowid));
  });

  // Search: /trips?from=SA&to=EG&by=2026-11-30&min_kg=3
  api.get('/trips', (req, res) => {
    const { from, to, by, min_kg } = req.query;
    const where = ["t.status = 'open'", "t.depart_date >= date('now')"];
    const args = [];
    if (from) { where.push('t.from_country = ?'); args.push(from); }
    if (to) { where.push('t.to_country = ?'); args.push(to); }
    if (by) { where.push('t.arrive_date <= ?'); args.push(by); }
    if (min_kg) { where.push('t.available_kg >= ?'); args.push(Number(min_kg)); }
    const rows = db.prepare(`SELECT t.*, u.name AS traveler_name, u.kyc_status AS traveler_kyc
      FROM trips t JOIN users u ON u.id = t.traveler_id WHERE ${where.join(' AND ')} ORDER BY t.depart_date LIMIT 100`).all(...args);
    res.json(rows);
  });

  api.get('/trips/:id', (req, res) => {
    const t = db.prepare('SELECT * FROM trips WHERE id = ?').get(req.params.id);
    if (!t) return res.status(404).json({ error: 'Not found' });
    res.json(t);
  });

  // ---- Requests (people who need something carried) -------------------------
  api.post('/requests/check', (req, res) => res.json(checkRequest(normalizeRequest(req.body ?? {}))));

  api.post('/requests', auth, (req, res) => {
    const r = normalizeRequest(req.body ?? {});
    const check = checkRequest(r);
    if (!r.title || !r.from_city || !r.to_city || !r.needed_by) check.errors.push('title, cities and needed_by are required');
    if (check.errors.length) return res.status(400).json(check);
    const out = db.prepare(`INSERT INTO requests (sender_id, from_country, from_city, to_country, to_city, needed_by, weight_kg,
      category, title, description, declared_value, currency, type, item_url)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
      req.user.id, r.from_country, r.from_city, r.to_country, r.to_city, r.needed_by, r.weight_kg,
      r.category, r.title, r.description ?? null, r.declared_value, r.currency, r.type, r.item_url ?? null);
    res.status(201).json({ ...db.prepare('SELECT * FROM requests WHERE id = ?').get(out.lastInsertRowid), warnings: check.warnings });
  });

  api.get('/requests', (req, res) => {
    const { from, to } = req.query;
    const where = ["status = 'open'"];
    const args = [];
    if (from) { where.push('from_country = ?'); args.push(from); }
    if (to) { where.push('to_country = ?'); args.push(to); }
    res.json(db.prepare(`SELECT * FROM requests WHERE ${where.join(' AND ')} ORDER BY needed_by LIMIT 100`).all(...args));
  });

  // Trips that can carry this request in time.
  api.get('/requests/:id/matches', (req, res) => {
    const r = db.prepare('SELECT * FROM requests WHERE id = ?').get(req.params.id);
    if (!r) return res.status(404).json({ error: 'Not found' });
    const trips = db.prepare(`SELECT t.*, u.name AS traveler_name, u.kyc_status AS traveler_kyc FROM trips t
      JOIN users u ON u.id = t.traveler_id
      WHERE t.from_country = ? AND t.to_country = ? AND t.status = 'open' AND t.traveler_id != ?
      ORDER BY t.arrive_date`).all(r.from_country, r.to_country, r.sender_id);
    res.json(trips.filter((t) => tripFitsRequest(t, r))
      .map((t) => ({ ...t, estimated_reward: Math.round(t.price_per_kg * r.weight_kg * 100) / 100 })));
  });

  // ---- Bookings --------------------------------------------------------------
  const loadBooking = (id) => db.prepare(`SELECT b.*, t.traveler_id, r.sender_id, r.weight_kg, r.title, t.available_kg
    FROM bookings b JOIN trips t ON t.id = b.trip_id JOIN requests r ON r.id = b.request_id WHERE b.id = ?`).get(id);

  api.post('/bookings', auth, (req, res) => {
    const { trip_id, request_id } = req.body ?? {};
    const trip = db.prepare('SELECT * FROM trips WHERE id = ?').get(trip_id);
    const request = db.prepare('SELECT * FROM requests WHERE id = ?').get(request_id);
    if (!trip || !request) return res.status(404).json({ error: 'Trip or request not found' });
    if (req.user.id !== trip.traveler_id && req.user.id !== request.sender_id) {
      return res.status(403).json({ error: 'Only the traveler or the sender can propose a booking' });
    }
    if (trip.traveler_id === request.sender_id) return res.status(400).json({ error: 'You cannot carry your own request' });
    if (req.user.kyc_status !== 'verified') return res.status(403).json({ error: 'Verify your identity (KYC) before booking' });
    if (!tripFitsRequest(trip, request)) return res.status(400).json({ error: 'This trip does not fit the request (route, date, weight or type)' });
    if (request.status !== 'open') return res.status(400).json({ error: 'Request is no longer open' });

    const reward = Math.round(trip.price_per_kg * request.weight_kg * 100) / 100;
    const code = String(crypto.randomInt(100000, 1000000));
    const r = db.prepare(`INSERT INTO bookings (trip_id, request_id, proposed_by, reward, currency, delivery_code)
      VALUES (?, ?, ?, ?, ?, ?)`).run(trip.id, request.id, req.user.id, reward, trip.currency, code);
    res.status(201).json(viewBooking(loadBooking(r.lastInsertRowid), req.user.id));
  });

  api.get('/bookings', auth, (req, res) => {
    const rows = db.prepare(`SELECT b.id FROM bookings b JOIN trips t ON t.id = b.trip_id JOIN requests r ON r.id = b.request_id
      WHERE t.traveler_id = ? OR r.sender_id = ? ORDER BY b.updated_at DESC`).all(req.user.id, req.user.id);
    res.json(rows.map((x) => viewBooking(loadBooking(x.id), req.user.id)));
  });

  // Actions: accept | decline | cancel | pay | inspect | depart | deliver | dispute
  api.post('/bookings/:id/:action', auth, (req, res, next) => {
    if (!ACTOR[req.params.action]) return next();
    const b = loadBooking(req.params.id);
    if (!b) return res.status(404).json({ error: 'Not found' });
    const { action } = req.params;
    const role = req.user.id === b.traveler_id ? 'traveler' : req.user.id === b.sender_id ? 'sender' : null;
    if (!role) return res.status(403).json({ error: 'Not your booking' });

    const nextStatus = TRANSITIONS[b.status]?.[action];
    if (!nextStatus) return res.status(409).json({ error: `Cannot ${action} a booking that is ${b.status}` });

    const allowed = ACTOR[action];
    const ok = allowed === 'either'
      || (allowed === 'counterparty' && req.user.id !== b.proposed_by)
      || allowed === role;
    if (!ok) return res.status(403).json({ error: `Only the ${allowed} can ${action}` });

    if (action === 'inspect') {
      const { opened, matches_description, no_prohibited_items } = req.body ?? {};
      if (!(opened && matches_description && no_prohibited_items)) {
        return res.status(400).json({ error: 'Traveler must confirm the item was opened, matches the description and contains no prohibited items' });
      }
    }
    if (action === 'deliver' && String(req.body?.delivery_code) !== b.delivery_code) {
      return res.status(400).json({ error: 'Wrong delivery code. Ask the recipient for the 6-digit code.' });
    }

    db.exec('BEGIN');
    try {
      if (action === 'accept') {
        if (b.available_kg < b.weight_kg) throw new HttpError(409, 'Not enough space left on this trip');
        db.prepare('UPDATE trips SET available_kg = available_kg - ? WHERE id = ?').run(b.weight_kg, b.trip_id);
        db.prepare("UPDATE requests SET status = 'booked' WHERE id = ?").run(b.request_id);
      }
      if ((action === 'cancel' || action === 'decline') && ['accepted', 'paid'].includes(b.status)) {
        db.prepare('UPDATE trips SET available_kg = available_kg + ? WHERE id = ?').run(b.weight_kg, b.trip_id);
        db.prepare("UPDATE requests SET status = 'open' WHERE id = ?").run(b.request_id);
      }
      if (action === 'deliver') db.prepare("UPDATE requests SET status = 'delivered' WHERE id = ?").run(b.request_id);
      db.prepare(`UPDATE bookings SET status = ?, updated_at = datetime('now')${action === 'inspect' ? ", inspected_at = datetime('now')" : ''} WHERE id = ?`)
        .run(nextStatus, b.id);
      db.exec('COMMIT');
    } catch (e) {
      db.exec('ROLLBACK');
      if (e instanceof HttpError) return res.status(e.status).json({ error: e.message });
      throw e;
    }
    res.json(viewBooking(loadBooking(b.id), req.user.id));
  });

  api.get('/bookings/:id/messages', auth, (req, res) => {
    const b = loadBooking(req.params.id);
    if (!b || ![b.traveler_id, b.sender_id].includes(req.user.id)) return res.status(404).json({ error: 'Not found' });
    res.json(db.prepare('SELECT * FROM messages WHERE booking_id = ? ORDER BY id').all(b.id));
  });

  api.post('/bookings/:id/messages', auth, (req, res) => {
    const b = loadBooking(req.params.id);
    if (!b || ![b.traveler_id, b.sender_id].includes(req.user.id)) return res.status(404).json({ error: 'Not found' });
    const body = String(req.body?.body ?? '').trim();
    if (!body) return res.status(400).json({ error: 'Message is empty' });
    const r = db.prepare('INSERT INTO messages (booking_id, sender_id, body) VALUES (?, ?, ?)').run(b.id, req.user.id, body.slice(0, 2000));
    res.status(201).json(db.prepare('SELECT * FROM messages WHERE id = ?').get(r.lastInsertRowid));
  });

  api.post('/bookings/:id/review', auth, (req, res) => {
    const b = loadBooking(req.params.id);
    if (!b || ![b.traveler_id, b.sender_id].includes(req.user.id)) return res.status(404).json({ error: 'Not found' });
    if (b.status !== 'delivered') return res.status(409).json({ error: 'You can review after delivery' });
    const stars = Number(req.body?.stars);
    if (!(stars >= 1 && stars <= 5)) return res.status(400).json({ error: 'stars must be 1-5' });
    const subject = req.user.id === b.traveler_id ? b.sender_id : b.traveler_id;
    try {
      db.prepare('INSERT INTO reviews (booking_id, author_id, subject_id, stars, comment) VALUES (?, ?, ?, ?, ?)')
        .run(b.id, req.user.id, subject, Math.round(stars), req.body?.comment ?? null);
    } catch {
      return res.status(409).json({ error: 'Already reviewed' });
    }
    res.status(201).json({ ok: true });
  });

  app.use('/api', api);
  app.use(express.static(WEB_DIR));

  app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  });
  return app;
}

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

function normalizeRequest(b) {
  return {
    ...b,
    weight_kg: Number(b.weight_kg),
    declared_value: Number(b.declared_value),
    currency: b.currency ?? 'USD',
    type: b.type ?? 'buy_for_me',
  };
}

// The delivery code is only shown to the sender (recipient), never the traveler.
function viewBooking(b, viewerId) {
  const { delivery_code, ...rest } = b;
  return viewerId === b.sender_id ? { ...rest, delivery_code } : rest;
}
