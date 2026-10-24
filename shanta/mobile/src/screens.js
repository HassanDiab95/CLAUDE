import { useEffect, useState } from 'react';
import { Alert, ScrollView, Text, View } from 'react-native';
import { api, setToken } from './api';
import { Button, Card, Chips, Field, s } from './ui';

const ROUTES = [['SA', 'Saudi Arabia'], ['AE', 'UAE'], ['KW', 'Kuwait'], ['QA', 'Qatar'], ['EG', 'Egypt'], ['JO', 'Jordan']];
const day = (n) => new Date(Date.now() + n * 864e5).toISOString().slice(0, 10);

export function LoginScreen({ onLogin }) {
  const [register, setRegister] = useState(false);
  const [f, setF] = useState({ name: '', email: '', password: '', country: 'EG', accept_terms: false });
  const set = (k) => (v) => setF({ ...f, [k]: v });

  async function submit() {
    try {
      const out = register ? await api('POST', '/auth/register', f) : await api('POST', '/auth/login', f);
      await setToken(out.token);
      onLogin(out.user);
    } catch (e) { Alert.alert('Error', e.message); }
  }

  return (
    <ScrollView contentContainerStyle={{ padding: 16 }}>
      <Text style={s.h1}>🧳 Shanta | شنطة</Text>
      <Text style={[s.muted, { marginBottom: 16 }]}>Travelers with spare kilos meet people who need items brought.</Text>
      {register && <Field label="Full name" value={f.name} onChangeText={set('name')} autoCapitalize="words" />}
      <Field label="Email" value={f.email} onChangeText={set('email')} keyboardType="email-address" />
      <Field label="Password" value={f.password} onChangeText={set('password')} secureTextEntry />
      {register && (
        <>
          <Text style={s.label}>Country</Text>
          <Chips options={ROUTES} value={f.country} onChange={set('country')} />
          <Chips options={[['yes', f.accept_terms ? '✔ I accept the terms & prohibited-items policy' : 'Tap to accept the terms & prohibited-items policy']]}
            value={f.accept_terms ? 'yes' : null} onChange={() => set('accept_terms')(!f.accept_terms)} />
        </>
      )}
      <Button title={register ? 'Create account' : 'Log in'} onPress={submit} />
      <Button ghost title={register ? 'I have an account' : 'Create account'} onPress={() => setRegister(!register)} />
    </ScrollView>
  );
}

export function SearchScreen() {
  const [from, setFrom] = useState('SA');
  const [to, setTo] = useState('EG');
  const [trips, setTrips] = useState([]);

  useEffect(() => { api('GET', `/trips?from=${from}&to=${to}`).then(setTrips).catch((e) => Alert.alert('Error', e.message)); }, [from, to]);

  return (
    <ScrollView contentContainerStyle={{ padding: 16 }}>
      <Text style={s.h1}>Find a traveler</Text>
      <Text style={s.label}>From</Text>
      <Chips options={ROUTES} value={from} onChange={setFrom} />
      <Text style={s.label}>To</Text>
      <Chips options={ROUTES} value={to} onChange={setTo} />
      {trips.length === 0 && <Text style={s.muted}>No travelers on this route yet. Post a request and get notified.</Text>}
      {trips.map((t) => (
        <Card key={t.id}>
          <Text style={{ fontWeight: '700' }}>{t.from_city} → {t.to_city}</Text>
          <Text style={s.muted}>✈ {t.depart_date} · {t.available_kg} kg free</Text>
          <Text>{t.traveler_name} {t.traveler_kyc === 'verified' ? '✔' : ''}</Text>
          <Text style={{ fontWeight: '700', color: '#0f766e' }}>{t.price_per_kg} {t.currency}/kg</Text>
        </Card>
      ))}
    </ScrollView>
  );
}

export function TripScreen() {
  const [f, setF] = useState({ from_country: 'SA', from_city: '', to_country: 'EG', to_city: '', depart_date: day(7), arrive_date: day(7), available_kg: '5', price_per_kg: '5' });
  const set = (k) => (v) => setF({ ...f, [k]: v });

  async function submit() {
    try {
      await api('POST', '/trips', { ...f, available_kg: Number(f.available_kg), price_per_kg: Number(f.price_per_kg), accepts_buy_for_me: true });
      Alert.alert('Published', 'Your trip is live. People on your route can now book your spare kilos.');
    } catch (e) { Alert.alert('Error', e.message); }
  }

  return (
    <ScrollView contentContainerStyle={{ padding: 16 }}>
      <Text style={s.h1}>I'm traveling</Text>
      <Text style={s.label}>From</Text>
      <Chips options={ROUTES} value={f.from_country} onChange={set('from_country')} />
      <Field label="From city" value={f.from_city} onChangeText={set('from_city')} autoCapitalize="words" />
      <Text style={s.label}>To</Text>
      <Chips options={ROUTES} value={f.to_country} onChange={set('to_country')} />
      <Field label="To city" value={f.to_city} onChangeText={set('to_city')} autoCapitalize="words" />
      <Field label="Departure (YYYY-MM-DD)" value={f.depart_date} onChangeText={set('depart_date')} />
      <Field label="Arrival (YYYY-MM-DD)" value={f.arrive_date} onChangeText={set('arrive_date')} />
      <Field label="Spare kg" value={f.available_kg} onChangeText={set('available_kg')} keyboardType="decimal-pad" />
      <Field label="Price per kg (USD)" value={f.price_per_kg} onChangeText={set('price_per_kg')} keyboardType="decimal-pad" />
      <Button title="Publish trip" onPress={submit} />
    </ScrollView>
  );
}

export function RequestScreen() {
  const [meta, setMeta] = useState(null);
  const [f, setF] = useState({ type: 'buy_for_me', title: '', category: 'clothing', weight_kg: '1', declared_value: '50', from_country: 'SA', from_city: '', to_country: 'EG', to_city: '', needed_by: day(21) });
  const [check, setCheck] = useState(null);
  const [matches, setMatches] = useState(null);
  const set = (k) => (v) => setF({ ...f, [k]: v });
  const payload = { ...f, weight_kg: Number(f.weight_kg), declared_value: Number(f.declared_value) };

  useEffect(() => { api('GET', '/meta').then(setMeta); }, []);
  useEffect(() => { api('POST', '/requests/check', payload).then(setCheck).catch(() => {}); }, [f.category, f.declared_value, f.to_country, f.type, f.weight_kg]);

  async function submit() {
    try {
      const r = await api('POST', '/requests', payload);
      const m = await api('GET', `/requests/${r.id}/matches`);
      setMatches(m.map((t) => ({ ...t, request_id: r.id })));
    } catch (e) { Alert.alert('Error', e.message); }
  }

  async function book(t) {
    try {
      await api('POST', '/bookings', { trip_id: t.id, request_id: t.request_id });
      Alert.alert('Booking sent', 'The traveler will accept it, then you pay into escrow.');
    } catch (e) { Alert.alert('Error', e.message); }
  }

  const categories = meta ? [...meta.categories.allowed, ...Object.keys(meta.categories.restricted)].map((c) => [c, c.replace(/_/g, ' ')]) : [];

  return (
    <ScrollView contentContainerStyle={{ padding: 16 }}>
      <Text style={s.h1}>Send something</Text>
      <Chips options={[['buy_for_me', 'Buy it for me'], ['handover', "I'll hand it over"]]} value={f.type} onChange={set('type')} />
      <Field label="Item" value={f.title} onChangeText={set('title')} autoCapitalize="sentences" />
      <Text style={s.label}>Category</Text>
      <Chips options={categories} value={f.category} onChange={set('category')} />
      <Field label="Weight (kg)" value={f.weight_kg} onChangeText={set('weight_kg')} keyboardType="decimal-pad" />
      <Field label="Declared value (USD)" value={f.declared_value} onChangeText={set('declared_value')} keyboardType="decimal-pad" />
      <Text style={s.label}>From</Text>
      <Chips options={ROUTES} value={f.from_country} onChange={set('from_country')} />
      <Field label="From city" value={f.from_city} onChangeText={set('from_city')} autoCapitalize="words" />
      <Text style={s.label}>To</Text>
      <Chips options={ROUTES} value={f.to_country} onChange={set('to_country')} />
      <Field label="To city" value={f.to_city} onChangeText={set('to_city')} autoCapitalize="words" />
      <Field label="Needed by (YYYY-MM-DD)" value={f.needed_by} onChangeText={set('needed_by')} />
      {check && (check.errors.length > 0 || check.warnings.length > 0) && (
        <View style={s.notice}>
          {check.errors.map((x) => <Text key={x} style={{ color: '#b42318' }}>⛔ {x}</Text>)}
          {check.warnings.map((x) => <Text key={x}>⚠️ {x}</Text>)}
        </View>
      )}
      <Button title="Post & find travelers" onPress={submit} />
      {matches?.length === 0 && <Text style={s.muted}>No matching trips yet.</Text>}
      {matches?.map((t) => (
        <Card key={t.id}>
          <Text style={{ fontWeight: '700' }}>{t.from_city} → {t.to_city} · {t.arrive_date}</Text>
          <Text>{t.traveler_name} · reward {t.estimated_reward} {t.currency}</Text>
          <Button title="Book" onPress={() => book(t)} />
        </Card>
      ))}
    </ScrollView>
  );
}

const NEXT = {
  proposed: ['accept', 'decline'], accepted: ['pay', 'cancel'], paid: ['inspect', 'cancel'],
  inspected: ['depart', 'dispute'], in_transit: ['deliver', 'dispute'],
};

export function BookingsScreen({ user, onLogout }) {
  const [list, setList] = useState([]);
  const [me, setMe] = useState(user);
  const [code, setCode] = useState('');
  const load = () => Promise.all([api('GET', '/bookings').then(setList), api('GET', '/me').then(setMe)]).catch((e) => Alert.alert('Error', e.message));
  useEffect(() => { load(); }, []);

  async function act(b, action) {
    const body = action === 'inspect' ? { opened: true, matches_description: true, no_prohibited_items: true }
      : action === 'deliver' ? { delivery_code: code } : undefined;
    try { await api('POST', `/bookings/${b.id}/${action}`, body); load(); } catch (e) { Alert.alert('Error', e.message); }
  }

  return (
    <ScrollView contentContainerStyle={{ padding: 16 }}>
      <Text style={s.h1}>My bookings</Text>
      {me?.kyc_status !== 'verified' && (
        <View style={s.notice}>
          <Text>Verify your identity (ID + selfie) before booking.</Text>
          <Button title="Verify now" onPress={async () => { await api('POST', '/me/kyc'); load(); }} />
        </View>
      )}
      {list.map((b) => (
        <Card key={b.id}>
          <Text style={{ fontWeight: '700' }}>#{b.id} {b.title} · {b.weight_kg} kg</Text>
          <Text>Status: {b.status} · reward {b.reward} {b.currency}</Text>
          {b.delivery_code && <Text style={s.notice}>Delivery code (give only on receipt): {b.delivery_code}</Text>}
          {b.status === 'in_transit' && b.traveler_id === me?.id && (
            <Field label="Recipient's delivery code" value={code} onChangeText={setCode} keyboardType="number-pad" />
          )}
          {(NEXT[b.status] || []).filter((a) => !(['accept', 'decline'].includes(a) && b.proposed_by === me?.id)).map((a) => <Button key={a} title={a} ghost={['cancel', 'decline', 'dispute'].includes(a)} onPress={() => act(b, a)} />)}
        </Card>
      ))}
      {list.length === 0 && <Text style={s.muted}>No bookings yet.</Text>}
      <Button ghost title="Log out" onPress={async () => { await setToken(null); onLogout(); }} />
    </ScrollView>
  );
}
