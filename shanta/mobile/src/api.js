import AsyncStorage from '@react-native-async-storage/async-storage';
import Constants from 'expo-constants';

// On a real phone, set extra.apiUrl in app.json to your computer's LAN IP, e.g. http://192.168.1.20:3000/api
export const API_URL = Constants.expoConfig?.extra?.apiUrl ?? 'http://localhost:3000/api';

let token = null;

export async function loadToken() {
  token = await AsyncStorage.getItem('shanta_token');
  return token;
}

export async function setToken(value) {
  token = value;
  if (value) await AsyncStorage.setItem('shanta_token', value);
  else await AsyncStorage.removeItem('shanta_token');
}

export async function api(method, path, body) {
  const res = await fetch(API_URL + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token && { Authorization: `Bearer ${token}` }) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || (data.errors || []).join('\n') || `HTTP ${res.status}`);
  return data;
}
