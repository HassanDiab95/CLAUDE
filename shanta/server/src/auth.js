import crypto from 'node:crypto';

const SECRET = process.env.SHANTA_SECRET || crypto.randomBytes(32).toString('hex');
const TOKEN_TTL_MS = 7 * 24 * 3600 * 1000;

export function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${hash}`;
}

export function verifyPassword(password, stored) {
  const [salt, hash] = stored.split(':');
  const candidate = crypto.scryptSync(password, salt, 64);
  return crypto.timingSafeEqual(candidate, Buffer.from(hash, 'hex'));
}

// Minimal signed token: base64url(payload).hmac
export function signToken(userId) {
  const payload = Buffer.from(JSON.stringify({ uid: userId, exp: Date.now() + TOKEN_TTL_MS })).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

export function readToken(token) {
  if (!token) return null;
  const [payload, sig] = token.split('.');
  if (!payload || !sig) return null;
  const expected = crypto.createHmac('sha256', SECRET).update(payload).digest('base64url');
  if (sig.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return null;
  const data = JSON.parse(Buffer.from(payload, 'base64url').toString());
  return data.exp > Date.now() ? data.uid : null;
}

export function requireAuth(db) {
  return (req, res, next) => {
    const header = req.get('authorization') || '';
    const uid = readToken(header.replace(/^Bearer /, ''));
    const user = uid && db.prepare('SELECT * FROM users WHERE id = ?').get(uid);
    if (!user) return res.status(401).json({ error: 'Login required' });
    req.user = user;
    next();
  };
}

export function publicUser(u) {
  return { id: u.id, name: u.name, country: u.country, kyc_status: u.kyc_status, created_at: u.created_at };
}
