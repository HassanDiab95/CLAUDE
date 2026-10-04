package com.smartplant.app

import com.google.firebase.database.DataSnapshot

// Must be the same as PLANT_ID in the ESP32 firmware (config.h)
const val PLANT_ID = "plant01"

// Leave empty to use the database URL from google-services.json.
// If your database is outside the US (e.g. europe-west1), paste its URL here:
// "https://YOUR-PROJECT-default-rtdb.europe-west1.firebasedatabase.app"
const val DATABASE_URL = ""

/** Latest readings: plants/<id>/live */
data class PlantLive(
    val moisture: Double? = null,
    val temperature: Double? = null,
    val humidity: Double? = null,
    val lux: Double? = null,
    val batteryPct: Double? = null,
    val batteryV: Double? = null,
    val solarV: Double? = null,
    val charging: Boolean = false,
    val rssi: Double? = null,
    val mood: String = "unknown",
    val ts: Long = 0,
)

/** One point of plants/<id>/history (every 5 minutes) */
data class HistoryPoint(
    val ts: Long,
    val moisture: Double?,
    val temperature: Double?,
    val humidity: Double?,
    val lux: Double?,
    val batteryPct: Double?,
)

/** One entry of plants/<id>/events (mood changes) */
data class PlantEvent(val ts: Long, val mood: String, val message: String)

/** plants/<id>/config (written by the web app or this app) */
data class PlantSettings(
    val name: String = "",
    val moistureMin: Double = 30.0,
    val moistureMax: Double = 85.0,
    val muted: Boolean = false,
)

// ---------------------------------------------------------------------
//  Read values from Firebase snapshots (numbers may be Long or Double)
// ---------------------------------------------------------------------
private fun DataSnapshot.num(key: String): Double? = (child(key).value as? Number)?.toDouble()
private fun DataSnapshot.long(key: String): Long = (child(key).value as? Number)?.toLong() ?: 0L
private fun DataSnapshot.str(key: String): String = child(key).value as? String ?: ""
private fun DataSnapshot.bool(key: String): Boolean = child(key).value as? Boolean ?: false

fun DataSnapshot.toLive(): PlantLive? = if (!exists()) null else PlantLive(
    moisture = num("moisture"),
    temperature = num("temperature"),
    humidity = num("humidity"),
    lux = num("lux"),
    batteryPct = num("battery_pct"),
    batteryV = num("battery_v"),
    solarV = num("solar_v"),
    charging = bool("charging"),
    rssi = num("rssi"),
    mood = str("mood").ifEmpty { "unknown" },
    ts = long("ts"),
)

fun DataSnapshot.toHistory(): HistoryPoint = HistoryPoint(
    ts = long("ts"),
    moisture = num("moisture"),
    temperature = num("temperature"),
    humidity = num("humidity"),
    lux = num("lux"),
    batteryPct = num("battery_pct"),
)

fun DataSnapshot.toEvent(): PlantEvent = PlantEvent(long("ts"), str("mood"), str("message"))

fun DataSnapshot.toSettings(): PlantSettings = PlantSettings(
    name = str("name"),
    moistureMin = num("moisture_min") ?: 30.0,
    moistureMax = num("moisture_max") ?: 85.0,
    muted = bool("muted"),
)
