// Demo data: two users and a Riyadh -> Cairo trip. Password for both: password123
import { openDb } from './db.js';
import { hashPassword } from './auth.js';

const db = openDb();
const day = (n) => new Date(Date.now() + n * 864e5).toISOString().slice(0, 10);
const addUser = (name, email, country) => db.prepare(`INSERT OR IGNORE INTO users
  (name, email, country, password_hash, kyc_status, accepted_terms_at) VALUES (?, ?, ?, ?, 'verified', datetime('now'))`)
  .run(name, email, country, hashPassword('password123'));

addUser('Ahmed (traveler)', 'ahmed@example.com', 'SA');
addUser('Mona (sender)', 'mona@example.com', 'EG');
const ahmed = db.prepare('SELECT id FROM users WHERE email = ?').get('ahmed@example.com').id;

const trips = [
  ['SA', 'Riyadh', 'EG', 'Cairo', day(5), day(5), 8, 6, 'USD'],
  ['SA', 'Jeddah', 'EG', 'Alexandria', day(9), day(9), 5, 25, 'SAR'],
  ['AE', 'Dubai', 'EG', 'Cairo', day(3), day(3), 10, 7, 'USD'],
  ['EG', 'Cairo', 'KW', 'Kuwait City', day(12), day(12), 6, 5, 'USD'],
];
for (const t of trips) {
  db.prepare(`INSERT INTO trips (traveler_id, from_country, from_city, to_country, to_city, depart_date, arrive_date,
    available_kg, price_per_kg, currency, accepts_buy_for_me, accepts_handover) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1)`).run(ahmed, ...t);
}
console.log('Seeded demo users ahmed@example.com / mona@example.com (password123) and', trips.length, 'trips');
