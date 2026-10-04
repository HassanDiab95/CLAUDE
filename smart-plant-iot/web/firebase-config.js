// =====================================================================
//  Paste YOUR Firebase web-app configuration here
//  (Firebase console > Project settings > General > Your apps > Web app)
//  See docs/04-firebase-setup.md
//
//  While the values below are still placeholders, the dashboard runs in
//  DEMO MODE with simulated data (useful for testing the design).
//  You can also force demo mode by opening  index.html?demo=1
// =====================================================================
export const firebaseConfig = {
  apiKey: "YOUR_FIREBASE_WEB_API_KEY",
  authDomain: "YOUR-PROJECT.firebaseapp.com",
  databaseURL: "https://YOUR-PROJECT-default-rtdb.firebaseio.com",
  projectId: "YOUR-PROJECT",
  storageBucket: "YOUR-PROJECT.appspot.com",
  messagingSenderId: "000000000000",
  appId: "1:000000000000:web:0000000000000000",
};

// Must be the same as PLANT_ID in the ESP32 firmware (config.h)
export const PLANT_ID = "plant01";
