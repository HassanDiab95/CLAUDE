package com.rayy.app

import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

// Address of the PHP API on the computer that runs XAMPP (same Wi-Fi as the phone).
// Windows: open cmd → ipconfig → "IPv4 Address". Keep "/rayy/api" at the end, no "/" after it.
// Android emulator on the same computer: use "http://10.0.2.2/rayy/api".
const val SERVER_URL = "http://192.168.1.10/rayy/api"

/** A crop is "online" when its device sent data in the last 2 minutes */
const val ONLINE_MS = 120_000L

/** Arabic text when the phone is in Arabic, otherwise English */
fun localized(ar: String, en: String): String = if (Locale.getDefault().language == "ar") ar else en

/** The signed-in user */
data class User(val userId: Int, val email: String, val fullName: String, val role: String) {
    val isAdmin get() = role == "admin"
}

/** Crop library: strawberry, tomato, mint ... with their ideal values */
data class CropType(
    val code: String, val nameAr: String, val nameEn: String, val emoji: String,
    val moistureMin: Double, val moistureMax: Double, val tempMin: Double, val tempMax: Double, val luxMin: Double,
) {
    val name get() = localized(nameAr, nameEn)
}

/** Latest values of a crop: api/live.php → "live" */
data class PlantLive(
    val moisture: Double? = null,
    val temperature: Double? = null,
    val humidity: Double? = null,
    val lux: Double? = null,
    val rssi: Double? = null,
    val mood: String = "unknown",
    val ts: Long = 0,
) {
    fun isOnline(now: Long = System.currentTimeMillis()) = ts > 0 && now - ts < ONLINE_MS
}

/** Name, type and thresholds of a crop (table crops) */
data class CropSettings(
    val name: String = "",
    val location: String = "",
    val typeCode: String = "",
    val moistureMin: Double = 30.0,
    val moistureMax: Double = 85.0,
    val tempMin: Double = 10.0,
    val tempMax: Double = 35.0,
    val luxMin: Double = 200.0,
    val quietStart: Int = 22,
    val quietEnd: Int = 7,
    val muted: Boolean = false,
)

data class DeviceRef(val deviceId: String, val name: String)

/** One card of the crops list: api/crops.php */
data class Crop(
    val cropId: Int,
    val name: String,
    val location: String,
    val typeName: String,
    val typeEmoji: String,
    val ownerName: String,
    val device: DeviceRef?,
    val live: PlantLive?,
)

/** A sensor device (ESP32) and the crop it measures now: api/devices.php */
data class DeviceInfo(
    val deviceId: String,
    val name: String,
    val ownerName: String,
    val lastSeen: Long,
    val cropId: Int?,
    val cropName: String,
    val cropEmoji: String,
)

/** A user in the admin page: api/users.php */
data class AdminUser(
    val userId: Int, val email: String, val fullName: String, val role: String, val crops: Int, val devices: Int,
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

// ---------------------------------------------------------------------
//  Read values from the JSON answers of the PHP API (null when missing)
// ---------------------------------------------------------------------
private fun JSONObject.num(key: String): Double? = if (!has(key) || isNull(key)) null else optDouble(key).takeIf { !it.isNaN() }
private fun JSONObject.str(key: String): String = if (isNull(key)) "" else optString(key)

fun <T> JSONArray.mapObjects(f: (JSONObject) -> T): List<T> = (0 until length()).map { f(getJSONObject(it)) }

fun JSONObject.toUser() = User(optInt("user_id"), str("email"), str("full_name"), str("role"))

fun JSONObject.toCropType() = CropType(
    code = str("type_code"), nameAr = str("name_ar"), nameEn = str("name_en"), emoji = str("emoji"),
    moistureMin = num("moisture_min") ?: 30.0, moistureMax = num("moisture_max") ?: 85.0,
    tempMin = num("temp_min") ?: 10.0, tempMax = num("temp_max") ?: 35.0, luxMin = num("lux_min") ?: 200.0,
)

fun JSONObject.toLive(): PlantLive = PlantLive(
    moisture = num("moisture"),
    temperature = num("temperature"),
    humidity = num("humidity"),
    lux = num("lux"),
    rssi = num("rssi"),
    mood = str("mood").ifEmpty { "unknown" },
    ts = optLong("ts"),
)

fun JSONObject.toSettings(): CropSettings = CropSettings(
    name = str("name"),
    location = str("location"),
    typeCode = str("type_code"),
    moistureMin = num("moisture_min") ?: 30.0,
    moistureMax = num("moisture_max") ?: 85.0,
    tempMin = num("temp_min") ?: 10.0,
    tempMax = num("temp_max") ?: 35.0,
    luxMin = num("lux_min") ?: 200.0,
    quietStart = optInt("quiet_start", 22),
    quietEnd = optInt("quiet_end", 7),
    muted = optBoolean("muted"),
)

fun JSONObject.toDeviceRef(): DeviceRef = DeviceRef(str("device_id"), str("name"))

fun JSONObject.toCrop() = Crop(
    cropId = optInt("crop_id"),
    name = str("name"),
    location = str("location"),
    typeName = localized(str("type_ar"), str("type_en")),
    typeEmoji = str("type_emoji"),
    ownerName = str("owner_name"),
    device = optJSONObject("device")?.toDeviceRef(),
    live = optJSONObject("live")?.toLive(),
)

fun JSONObject.toDeviceInfo(): DeviceInfo {
    val crop = optJSONObject("crop")
    return DeviceInfo(
        deviceId = str("device_id"), name = str("name"), ownerName = str("owner_name"), lastSeen = optLong("last_seen"),
        cropId = crop?.optInt("crop_id"), cropName = crop?.str("name") ?: "", cropEmoji = crop?.str("emoji") ?: "",
    )
}

fun JSONObject.toAdminUser() = AdminUser(
    optInt("user_id"), str("email"), str("full_name"), str("role"), optInt("crops"), optInt("devices"),
)

fun JSONObject.toHistory(): HistoryPoint = HistoryPoint(
    ts = optLong("ts"),
    moisture = num("moisture"),
    temperature = num("temperature"),
    humidity = num("humidity"),
    lux = num("lux"),
)

fun JSONObject.toEvent(): PlantEvent = PlantEvent(optLong("ts"), str("mood"), str("message"))

/** CropSettings → JSON body for api/crop_update.php */
fun CropSettings.toJson(): JSONObject = JSONObject()
    .put("name", name).put("location", location).put("type_code", typeCode)
    .put("moisture_min", moistureMin).put("moisture_max", moistureMax)
    .put("temp_min", tempMin).put("temp_max", tempMax).put("lux_min", luxMin)
    .put("quiet_start", quietStart).put("quiet_end", quietEnd).put("muted", muted)
