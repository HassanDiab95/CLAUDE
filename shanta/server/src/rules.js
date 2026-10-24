// Compliance rules applied before a request can be posted or booked.
// These are product guardrails, not legal advice: limits change, so keep them
// in config and review them with a customs broker / lawyer before launch.

export const COUNTRIES = {
  EG: 'Egypt', SA: 'Saudi Arabia', AE: 'United Arab Emirates', KW: 'Kuwait',
  QA: 'Qatar', BH: 'Bahrain', OM: 'Oman', JO: 'Jordan', LB: 'Lebanon',
  IQ: 'Iraq', MA: 'Morocco', TN: 'Tunisia', DZ: 'Algeria', LY: 'Libya',
  SD: 'Sudan', TR: 'Turkey', GB: 'United Kingdom', DE: 'Germany',
  FR: 'France', IT: 'Italy', US: 'United States', CA: 'Canada',
  CN: 'China', MY: 'Malaysia',
};

// Never allowed on the platform, whatever the route.
export const PROHIBITED = {
  drugs: 'Narcotics, cannabis products or controlled substances',
  weapons: 'Weapons, ammunition, replicas, knives, pepper spray',
  explosives: 'Explosives, fireworks, flammable gas or liquids',
  cash: 'Cash, cheques, bank cards or negotiable instruments',
  precious: 'Gold, jewellery, gemstones or precious metals',
  counterfeit: 'Counterfeit or pirated goods',
  documents_official: 'Passports, IDs or official documents of other people',
  wildlife: 'Animals, plants, seeds or wildlife products',
  tobacco_alcohol: 'Tobacco, e-cigarettes or alcohol',
  sealed_unknown: 'Sealed packages whose contents cannot be inspected',
};

// Allowed but flagged with a warning the traveler must acknowledge.
export const RESTRICTED = {
  medicine: 'Medicine needs the original pharmacy box + prescription in the patient\'s name; never controlled drugs.',
  electronics: 'Electronics may be dutiable. Mobile phones entering Egypt are subject to tax since 21 Jan 2026 (pay via the Telephony app).',
  batteries: 'Lithium batteries / power banks must travel in cabin baggage only (IATA DGR).',
  food: 'Only sealed, shelf-stable, commercially packed food. No meat or dairy.',
  cosmetics: 'Liquids over 100 ml must go in checked baggage.',
};

export const ALLOWED = ['clothing', 'books', 'documents_personal', 'toys', 'accessories', 'household', 'other'];

export const CATEGORIES = [...ALLOWED, ...Object.keys(RESTRICTED), ...Object.keys(PROHIBITED)];

// Approx. duty-free personal-effects ceilings on ARRIVAL, in USD.
// GCC Common Customs Law art. 103: 3,000 SAR/AED (~800 USD).
// Egypt: personal-use, non-commercial quantities; we apply a conservative cap.
const ARRIVAL_CAP_USD = { SA: 800, AE: 815, KW: 800, QA: 820, BH: 800, OM: 780, EG: 500 };
const DEFAULT_CAP_USD = 500;

export function arrivalCapUsd(country) {
  return ARRIVAL_CAP_USD[country] ?? DEFAULT_CAP_USD;
}

const MAX_KG_PER_REQUEST = 23;

// Returns { ok, errors[], warnings[] } for a shipment request.
export function checkRequest(r) {
  const errors = [];
  const warnings = [];

  if (!COUNTRIES[r.from_country]) errors.push(`Unsupported origin country: ${r.from_country}`);
  if (!COUNTRIES[r.to_country]) errors.push(`Unsupported destination country: ${r.to_country}`);
  if (r.from_country && r.from_country === r.to_country) errors.push('Origin and destination must be different countries');

  if (PROHIBITED[r.category]) errors.push(`Prohibited item: ${PROHIBITED[r.category]}`);
  else if (RESTRICTED[r.category]) warnings.push(RESTRICTED[r.category]);
  else if (!ALLOWED.includes(r.category)) errors.push(`Unknown category: ${r.category}`);

  if (!(r.weight_kg > 0)) errors.push('Weight must be greater than 0');
  if (r.weight_kg > MAX_KG_PER_REQUEST) errors.push(`Max ${MAX_KG_PER_REQUEST} kg per request`);
  if (!(r.declared_value >= 0)) errors.push('Declared value is required');

  if (!['buy_for_me', 'handover'].includes(r.type)) errors.push('Type must be buy_for_me or handover');

  const cap = arrivalCapUsd(r.to_country);
  const valueUsd = toUsd(r.declared_value, r.currency);
  if (valueUsd > cap) {
    warnings.push(`Declared value (~${Math.round(valueUsd)} USD) is above the ~${cap} USD personal duty-free allowance for ${COUNTRIES[r.to_country] ?? r.to_country}. The traveler must declare it at customs and duty may be payable.`);
  }

  if (r.type === 'handover') {
    warnings.push('Handover items must be shown OPEN to the traveler, who will inspect and may refuse. Keep the original invoice.');
  }

  return { ok: errors.length === 0, errors, warnings };
}

// Very rough static FX table; replace with a live rate provider in production.
const USD_RATE = { USD: 1, EGP: 1 / 48, SAR: 0.2667, AED: 0.2723, KWD: 3.25, QAR: 0.2747, EUR: 1.08, GBP: 1.27 };
export function toUsd(amount, currency = 'USD') {
  return amount * (USD_RATE[currency] ?? 1);
}

// Does this trip fit this request? Same route, enough room, arrives in time.
export function tripFitsRequest(trip, req) {
  return trip.from_country === req.from_country
    && trip.to_country === req.to_country
    && trip.available_kg >= req.weight_kg
    && trip.arrive_date <= req.needed_by
    && trip.status === 'open'
    && (req.type === 'buy_for_me' ? !!trip.accepts_buy_for_me : !!trip.accepts_handover);
}

// Booking lifecycle. Money is held by a licensed payment provider (escrow)
// from `paid` until `delivered`, then released to the traveler.
export const TRANSITIONS = {
  proposed:  { accept: 'accepted', decline: 'declined', cancel: 'cancelled' },
  accepted:  { pay: 'paid', cancel: 'cancelled' },
  paid:      { inspect: 'inspected', cancel: 'cancelled' },
  inspected: { depart: 'in_transit', dispute: 'disputed' },
  in_transit:{ deliver: 'delivered', dispute: 'disputed' },
  delivered: {},
  declined: {}, cancelled: {}, disputed: {},
};

// Which party may perform each action.
export const ACTOR = {
  accept: 'counterparty', decline: 'counterparty', cancel: 'either',
  pay: 'sender', inspect: 'traveler', depart: 'traveler',
  deliver: 'traveler', dispute: 'either',
};
