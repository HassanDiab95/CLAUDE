import { DatabaseSync } from 'node:sqlite';

const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  phone         TEXT,
  country       TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  -- unverified -> pending -> verified (ID + selfie checked by a KYC provider)
  kyc_status    TEXT NOT NULL DEFAULT 'unverified',
  accepted_terms_at TEXT NOT NULL,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS trips (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  traveler_id    INTEGER NOT NULL REFERENCES users(id),
  from_country   TEXT NOT NULL,
  from_city      TEXT NOT NULL,
  to_country     TEXT NOT NULL,
  to_city        TEXT NOT NULL,
  depart_date    TEXT NOT NULL,
  arrive_date    TEXT NOT NULL,
  available_kg   REAL NOT NULL,
  price_per_kg   REAL NOT NULL,
  currency       TEXT NOT NULL DEFAULT 'USD',
  accepts_buy_for_me INTEGER NOT NULL DEFAULT 1,
  accepts_handover   INTEGER NOT NULL DEFAULT 0,
  notes          TEXT,
  status         TEXT NOT NULL DEFAULT 'open',
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS requests (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  sender_id      INTEGER NOT NULL REFERENCES users(id),
  from_country   TEXT NOT NULL,
  from_city      TEXT NOT NULL,
  to_country     TEXT NOT NULL,
  to_city        TEXT NOT NULL,
  needed_by      TEXT NOT NULL,
  weight_kg      REAL NOT NULL,
  category       TEXT NOT NULL,
  title          TEXT NOT NULL,
  description    TEXT,
  declared_value REAL NOT NULL,
  currency       TEXT NOT NULL DEFAULT 'USD',
  -- buy_for_me: traveler buys a new item from a shop (with invoice) and brings it.
  -- handover:   sender hands an item to the traveler, who MUST inspect it open.
  type           TEXT NOT NULL DEFAULT 'buy_for_me',
  item_url       TEXT,
  status         TEXT NOT NULL DEFAULT 'open',
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS bookings (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  trip_id          INTEGER NOT NULL REFERENCES trips(id),
  request_id       INTEGER NOT NULL REFERENCES requests(id),
  proposed_by      INTEGER NOT NULL REFERENCES users(id),
  reward           REAL NOT NULL,
  currency         TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'proposed',
  inspected_at     TEXT,
  delivery_code    TEXT NOT NULL,
  created_at       TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS messages (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id  INTEGER NOT NULL REFERENCES bookings(id),
  sender_id   INTEGER NOT NULL REFERENCES users(id),
  body        TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS reviews (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id  INTEGER NOT NULL REFERENCES bookings(id),
  author_id   INTEGER NOT NULL REFERENCES users(id),
  subject_id  INTEGER NOT NULL REFERENCES users(id),
  stars       INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (booking_id, author_id)
);
`;

export function openDb(file = process.env.SHANTA_DB || 'shanta.db') {
  const db = new DatabaseSync(file);
  db.exec('PRAGMA foreign_keys = ON;');
  db.exec(SCHEMA);
  return db;
}
