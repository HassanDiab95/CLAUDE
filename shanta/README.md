# Shanta | شنطة

A website and mobile app that connects **travelers with spare luggage weight** to people who need
an item brought on their route. Built for the Middle East (Egypt, Saudi Arabia, the GCC, Jordan and
others) and for routes to and from the rest of the world.

> I'm in Egypt and need something from Saudi Arabia → I search for a verified traveler flying
> Riyadh → Cairo before my date, book their spare kilos, pay into escrow, and release the money with a
> delivery code when I receive the item.

## What's inside
| Folder | What |
|---|---|
| `server/` | Node.js + Express API with SQLite (`node:sqlite`). Covers accounts, trips, requests, matching, bookings (escrow state machine), chat, reviews, and the compliance rules engine. |
| `web/` | Bilingual Arabic/English website (RTL support), served by the API and installable as a PWA. |
| `mobile/` | Expo / React Native app for Android and iOS. |
| `docs/LEGAL_AND_COMPLIANCE.md` | Egyptian, GCC and international law, user eligibility, and required licences (EN + Arabic summary). |
| `docs/HOW_TO_START.md` | Step-by-step launch plan, costs, and first actions. |

## Run it
Requires Node.js ≥ 22.13.

```bash
cd server
npm install
npm run seed      # demo users: ahmed@example.com / mona@example.com, password: password123
npm start         # http://localhost:3000  (website + API under /api)
npm test          # API + rules tests
```

Mobile app:
```bash
cd mobile
npm install
npx expo start    # scan the QR code with Expo Go
```
On a real phone, set `expo.extra.apiUrl` in `mobile/app.json` to your computer's LAN address
(e.g. `http://192.168.1.20:3000/api`).

## Booking lifecycle
```
proposed → accepted → paid (escrow) → inspected (traveler opened & checked item) → in_transit → delivered (6-digit code)
     ↘ declined / cancelled                          ↘ disputed
```
- Only verified (KYC) users can book.
- The traveler must confirm the item was **opened, matches the description, and contains nothing prohibited**.
- Only the recipient sees the delivery code. The traveler enters it on handover, which releases the escrow.

## Demo-only parts to replace before production
- `POST /api/me/kyc` auto-verifies. Replace it with an eKYC provider webhook.
- The `pay` action simulates escrow. Replace it with a CBE-licensed payment provider (Paymob, Fawry and others).
- Static FX rates in `server/src/rules.js`. Use a live rate API.
- Set `SHANTA_SECRET` in production. Otherwise tokens reset on every restart.
