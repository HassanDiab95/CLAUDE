import { useEffect, useState } from 'react';
import { Pressable, SafeAreaView, Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { api, loadToken } from './src/api';
import { colors } from './src/ui';
import { BookingsScreen, LoginScreen, RequestScreen, SearchScreen, TripScreen } from './src/screens';

const TABS = [
  ['search', '🔎', 'Find'],
  ['trip', '✈️', 'Travel'],
  ['request', '📦', 'Send'],
  ['bookings', '🧾', 'Bookings'],
];

export default function App() {
  const [user, setUser] = useState(null);
  const [ready, setReady] = useState(false);
  const [tab, setTab] = useState('search');

  useEffect(() => {
    loadToken()
      .then((t) => (t ? api('GET', '/me').then(setUser) : null))
      .catch(() => null)
      .finally(() => setReady(true));
  }, []);

  if (!ready) return null;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }}>
      <StatusBar style="auto" />
      {!user ? <LoginScreen onLogin={setUser} /> : (
        <>
          <View style={{ flex: 1 }}>
            {tab === 'search' && <SearchScreen />}
            {tab === 'trip' && <TripScreen />}
            {tab === 'request' && <RequestScreen />}
            {tab === 'bookings' && <BookingsScreen user={user} onLogout={() => setUser(null)} />}
          </View>
          <View style={{ flexDirection: 'row', borderTopWidth: 1, borderColor: colors.line, backgroundColor: '#fff' }}>
            {TABS.map(([key, icon, label]) => (
              <Pressable key={key} onPress={() => setTab(key)} style={{ flex: 1, alignItems: 'center', paddingVertical: 8 }}>
                <Text style={{ fontSize: 20 }}>{icon}</Text>
                <Text style={{ fontSize: 12, color: tab === key ? colors.brand : colors.muted }}>{label}</Text>
              </Pressable>
            ))}
          </View>
        </>
      )}
    </SafeAreaView>
  );
}
