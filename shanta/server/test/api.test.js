import { test } from 'node:test';
import assert from 'node:assert/strict';
import { openDb } from '../src/db.js';
import { createApp } from '../src/app.js';
import { checkRequest } from '../src/rules.js';

const day = (n) => new Date(Date.now() + n * 864e5).toISOString().slice(0, 10);

async function withServer(fn) {
  const server = createApp(openDb(':memory:')).listen(0);
  const base = `http://localhost:${server.address().port}/api`;
  const call = async (method, path, body, token) => {
    const res = await fetch(base + path, {
      method,
      headers: { 'Content-Type': 'application/json', ...(token && { Authorization: `Bearer ${token}` }) },
      body: body && JSON.stringify(body),
    });
    return { status: res.status, body: await res.json() };
  };
  try { await fn(call); } finally { server.close(); }
}

const register = async (call, name, country) => {
  const r = await call('POST', '/auth/register', {
    name, email: `${name}@t.com`, country, password: 'password123', accept_terms: true,
  });
  assert.equal(r.status, 201);
  return r.body.token;
};

test('rules: prohibited items are rejected, restricted items warn', () => {
  const base = { from_country: 'SA', to_country: 'EG', weight_kg: 1, declared_value: 50, type: 'buy_for_me' };
  assert.equal(checkRequest({ ...base, category: 'cash' }).ok, false);
  assert.equal(checkRequest({ ...base, category: 'drugs' }).ok, false);
  const med = checkRequest({ ...base, category: 'medicine' });
  assert.equal(med.ok, true);
  assert.equal(med.warnings.length, 1);
  const pricey = checkRequest({ ...base, category: 'clothing', declared_value: 2000 });
  assert.ok(pricey.warnings.some((w) => w.includes('declare')));
  assert.equal(checkRequest({ ...base, category: 'books', to_country: 'SA' }).ok, false);
});

test('full flow: search, match, book, escrow, inspect, deliver, review', () => withServer(async (call) => {
  const traveler = await register(call, 'ahmed', 'SA');
  const sender = await register(call, 'mona', 'EG');

  const trip = await call('POST', '/trips', {
    from_country: 'SA', from_city: 'Riyadh', to_country: 'EG', to_city: 'Cairo',
    depart_date: day(5), arrive_date: day(5), available_kg: 8, price_per_kg: 6, accepts_handover: true,
  }, traveler);
  assert.equal(trip.status, 201);

  const found = await call('GET', `/trips?from=SA&to=EG&by=${day(10)}&min_kg=2`);
  assert.equal(found.body.length, 1);

  const bad = await call('POST', '/requests', {
    from_country: 'SA', from_city: 'Riyadh', to_country: 'EG', to_city: 'Cairo', needed_by: day(10),
    weight_kg: 1, category: 'precious', title: 'Gold ring', declared_value: 900,
  }, sender);
  assert.equal(bad.status, 400);

  const reqRes = await call('POST', '/requests', {
    from_country: 'SA', from_city: 'Riyadh', to_country: 'EG', to_city: 'Cairo', needed_by: day(10),
    weight_kg: 3, category: 'clothing', title: 'Abaya x2', declared_value: 120, currency: 'USD',
  }, sender);
  assert.equal(reqRes.status, 201);
  const requestId = reqRes.body.id;

  const matches = await call('GET', `/requests/${requestId}/matches`);
  assert.equal(matches.body.length, 1);
  assert.equal(matches.body[0].estimated_reward, 18);

  // KYC required before booking
  let booking = await call('POST', '/bookings', { trip_id: trip.body.id, request_id: requestId }, sender);
  assert.equal(booking.status, 403);
  await call('POST', '/me/kyc', null, sender);
  await call('POST', '/me/kyc', null, traveler);

  booking = await call('POST', '/bookings', { trip_id: trip.body.id, request_id: requestId }, sender);
  assert.equal(booking.status, 201);
  const id = booking.body.id;
  const code = booking.body.delivery_code;
  assert.match(code, /^\d{6}$/);

  // proposer cannot accept own proposal; traveler can
  assert.equal((await call('POST', `/bookings/${id}/accept`, null, sender)).status, 403);
  assert.equal((await call('POST', `/bookings/${id}/accept`, null, traveler)).body.status, 'accepted');
  assert.equal((await call('GET', `/trips/${trip.body.id}`)).body.available_kg, 5);

  // traveler never sees the delivery code
  const travelerView = await call('GET', '/bookings', null, traveler);
  assert.equal(travelerView.body[0].delivery_code, undefined);

  assert.equal((await call('POST', `/bookings/${id}/pay`, null, sender)).body.status, 'paid');
  assert.equal((await call('POST', `/bookings/${id}/inspect`, { opened: true }, traveler)).status, 400);
  assert.equal((await call('POST', `/bookings/${id}/inspect`, { opened: true, matches_description: true, no_prohibited_items: true }, traveler)).body.status, 'inspected');
  assert.equal((await call('POST', `/bookings/${id}/depart`, null, traveler)).body.status, 'in_transit');
  assert.equal((await call('POST', `/bookings/${id}/deliver`, { delivery_code: '000000' }, traveler)).status, 400);
  assert.equal((await call('POST', `/bookings/${id}/deliver`, { delivery_code: code }, traveler)).body.status, 'delivered');

  assert.equal((await call('POST', `/bookings/${id}/messages`, { body: 'Thanks!' }, sender)).status, 201);
  assert.equal((await call('POST', `/bookings/${id}/review`, { stars: 5 }, sender)).status, 201);
  assert.equal((await call('POST', `/bookings/${id}/review`, { stars: 5 }, sender)).status, 409);
}));

test('auth: rejects missing terms acceptance and bad login', () => withServer(async (call) => {
  const r = await call('POST', '/auth/register', { name: 'x', email: 'x@t.com', country: 'EG', password: 'password123' });
  assert.equal(r.status, 400);
  await register(call, 'sara', 'EG');
  assert.equal((await call('POST', '/auth/login', { email: 'sara@t.com', password: 'wrong' })).status, 401);
  assert.equal((await call('POST', '/auth/login', { email: 'sara@t.com', password: 'password123' })).status, 200);
}));
