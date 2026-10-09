package com.rayy.app

import org.json.JSONObject

// Address of the PHP API on the computer that runs XAMPP (same Wi-Fi as the phone).
// Windows: open cmd → ipconfig → "IPv4 Address". Keep "/rayy/api" at the end, no "/" after it.
// Android emulator on the same computer: use "http://10.0.2.2/rayy/api".
const val SERVER_URL = "http://192.168.1.10/rayy/api"

// Must be the same as PLANT_ID in the ESP32 firmware (config.h)
const val PLANT_ID = "plant01"

/** Latest readings: api/live.php → "live" */
data class PlantLive(
    val moisture: Double? = null,
    val temperature: Double? = null,
    val humidity: Double? = null,
    val lux: Double? = null,
    val rssi: Double? = null,
    val mood: String = "unknown",
    val ts: Long = 0,
)

/** One point of api/history.php (every 5 minutes) */
data class HistoryPoint(
    val ts: Long,
    val moisture: Double?,
    val temperature: Double?,
    val humidity: Double?,
    val lux: Double?,
)

/** One entry of api/events.php (mood changes) */
data class PlantEvent(val ts: Long, val mood: String, val message: String)

/** api/live.php → "config" (table plant_settings) */
data class PlantSettings(
    val name: String = "",
    val moistureMin: Double = 30.0,
    val moistureMax: Double = 85.0,
    val muted: Boolean = false,
)

// ---------------------------------------------------------------------
//  Read values from the JSON answers of the PHP API (null when missing)
// ---------------------------------------------------------------------
private fun JSONObject.num(key: String): Double? = if (isNull(key)) null else optDouble(key).takeIf { !it.isNaN() }

fun JSONObject.toLive(): PlantLive = PlantLive(
    moisture = num("moisture"),
    temperature = num("temperature"),
    humidity = num("humidity"),
    lux = num("lux"),
    rssi = num("rssi"),
    mood = optString("mood").ifEmpty { "unknown" },
    ts = optLong("ts"),
)

fun JSONObject.toHistory(): HistoryPoint = HistoryPoint(
    ts = optLong("ts"),
    moisture = num("moisture"),
    temperature = num("temperature"),
    humidity = num("humidity"),
    lux = num("lux"),
)

fun JSONObject.toEvent(): PlantEvent = PlantEvent(optLong("ts"), optString("mood"), optString("message"))

fun JSONObject.toSettings(): PlantSettings = PlantSettings(
    name = optString("name"),
    moistureMin = num("moisture_min") ?: 30.0,
    moistureMax = num("moisture_max") ?: 85.0,
    muted = optBoolean("muted"),
)
