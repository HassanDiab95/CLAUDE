# How to start Shanta — step-by-step launch plan

## The idea in one line
Travelers across the Middle East and the world have **unused luggage kilos**. People need items brought
**on a specific route by a specific date**. Shanta matches them, verifies both sides, holds the money in
escrow, and releases it when the recipient confirms delivery with a code.

**Example:** you are in Cairo and need something from Riyadh. You search *SA → EG, needed by 30 Nov*.
You find a verified traveler flying on 29 Oct with 8 kg free at 6 USD/kg. You book and pay into escrow.
The traveler buys or receives the item and inspects it. On arrival you give them your 6-digit code
and the money is released.

---

## Phase 0 — Validate (weeks 0–4, almost free)
1. **Pick one corridor first:** **Saudi Arabia ↔ Egypt** has a very large Egyptian expatriate community
   and frequent flights. Add UAE → Egypt second.
2. Join the Facebook / WhatsApp / Telegram groups where Egyptians abroad already ask "who's travelling
   to Cairo?". This demand already exists informally. Note what people send, the prices per kg, and the problems.
3. Run 20–30 matches **manually** (WhatsApp + a Google Form) using the safety rules in this repo:
   inspection, a ban on sealed packages, and ID checks.
4. **Success signal:** people pay, come back, and refer others. Target ≥ 30% repeat in the first month.

## Phase 1 — Legal set-up (weeks 2–8, in parallel)
| Step | Who | Est. cost (EGP) **[verify quotes]** |
|---|---|---|
| Incorporate LLC / One-Person Company via GAFI | Lawyer / GAFI online | 15k – 40k incl. lawyer |
| Tax card + VAT registration + ETA e-invoice | Accountant | 5k – 15k |
| Written legal opinion: NPA postal licensing, customs, CBE payments | Law firm | 30k – 100k |
| PDPL licence application + privacy policy + DPO | Law firm / consultant | 20k – 80k |
| Trademark "Shanta / شنطة" (Egypt, then KSA, UAE) | Trademark agent | 10k – 25k per country |
| Terms of Service + prohibited-items policy (AR/EN) | Law firm | included above |

See `LEGAL_AND_COMPLIANCE.md` for what each step covers.

## Phase 2 — MVP product (weeks 4–12)
This repository already contains a working MVP:
- **Backend API** (`server/`): accounts, trips, requests, matching by route + date + weight, bookings
  with an escrow state machine, inspection confirmation, delivery code, chat and reviews, plus a
  **compliance rules engine** (prohibited items, value warnings per destination, weight caps).
- **Website** (`web/`): Arabic / English (RTL), installable on phones as a PWA.
- **Mobile app** (`mobile/`): Expo / React Native for **Android and iPhone** from one codebase.

To go from MVP to production:
1. **eKYC:** integrate an ID + selfie provider (e.g. Valify (Egypt), Sumsub, Onfido) and replace the
   demo `/me/kyc` endpoint with the provider's webhook.
2. **Payments/escrow:** integrate Paymob or Fawry (Egypt) and Tap or HyperPay (GCC). Use authorize/hold
   then capture, or marketplace split payouts. Replace the demo `pay` step with the provider webhook.
3. **Hosting:** move from SQLite to PostgreSQL. Host on a cloud with a region that meets PDPL
   cross-border rules, after legal advice on where data may be stored.
4. **Notifications:** push (Expo Notifications / FCM), SMS OTP for phone verification, and email.
5. **Trust and safety:** photo upload at inspection and delivery, report and block users, admin dashboard,
   fraud rules (new accounts, high values, repeated routes).
6. **Publish:** Google Play (one-time USD 25) and Apple App Store (USD 99/year). Build with `eas build`.

## Phase 3 — Launch and grow (months 3–9)
- Launch on SA → EG with 50–100 seeded travelers recruited from the expat groups. Offer zero commission for the first trips.
- Revenue: **10–15% service fee** on the reward, a small "buy it for me" handling fee, and optional insurance.
- Example unit economics: a 3 kg item at 6 USD/kg gives an 18 USD reward. A 15% fee is 2.7 USD per booking.
  1,000 bookings/month ≈ 2,700 USD gross. Keep customer-acquisition cost below the first booking's fee.
- Expand to UAE, Kuwait, Qatar → Egypt, then Egypt → Gulf (food, clothes, medicines with prescription),
  then Europe / Turkey ↔ Middle East.
- Funding: Egyptian accelerators and VCs (e.g. Flat6Labs, Algebra Ventures, Sawari Ventures), ITIDA's
  startup programmes, and Saudi programmes for the KSA expansion (a MISA licence is needed to operate there).

## Key metrics to track
Matches per week · % requests matched within 7 days · completion rate · disputes per 100 bookings
(target < 2) · repeat rate · average reward · time from request to delivery.

## Your first 10 actions this week
1. Choose the corridor (SA → EG).
2. Join 5 expat groups and collect 50 real requests and offers.
3. Run the MVP locally (`README.md`) and show it to 10 potential users.
4. Book a consultation with an Egyptian law firm and send them `LEGAL_AND_COMPLIANCE.md`.
5. Check the trademark and domain (shanta.app / shanta.com.eg) availability.
6. Open conversations with Paymob or Fawry about marketplace escrow.
7. Ask an eKYC provider for pricing.
8. Draft the Terms and prohibited-items policy from §5 of the legal guide.
9. Recruit 20 trusted travelers (family and friends abroad) as founding travelers.
10. Run 10 manual deliveries and write down every problem.
