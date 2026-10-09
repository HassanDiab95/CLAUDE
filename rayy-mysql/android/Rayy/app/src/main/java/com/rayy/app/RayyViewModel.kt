package com.rayy.app

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * The "brain" of the app: talks to the XAMPP server (PHP API + MySQL) and keeps
 * everything the screens show in StateFlows.
 *
 *  - user: who is signed in (null = show the sign-in screen)
 *  - crops: the list of my crops (refreshed every 10 s)
 *  - openCrop: the crop shown in detail (live every 5 s, diary every 15 s, history every 5 min)
 *  - devices / users: the Devices page and the admin Users page
 */
class RayyViewModel(app: Application) : AndroidViewModel(app) {

    private val prefs = app.getSharedPreferences("rayy", Context.MODE_PRIVATE)
    private val api = ApiClient(prefs.getString("token", null))

    private val _user = MutableStateFlow<User?>(null)
    val user: StateFlow<User?> = _user

    /** true while we check a saved login at start-up */
    private val _starting = MutableStateFlow(api.token != null)
    val starting: StateFlow<Boolean> = _starting

    private val _types = MutableStateFlow<List<CropType>>(emptyList())
    val types: StateFlow<List<CropType>> = _types

    private val _crops = MutableStateFlow<List<Crop>>(emptyList())
    val crops: StateFlow<List<Crop>> = _crops

    // ---- the open crop ----
    private val _openCrop = MutableStateFlow<Int?>(null)
    val openCrop: StateFlow<Int?> = _openCrop

    private val _live = MutableStateFlow<PlantLive?>(null)
    val live: StateFlow<PlantLive?> = _live

    private val _settings = MutableStateFlow(CropSettings())
    val settings: StateFlow<CropSettings> = _settings

    private val _cropDevice = MutableStateFlow<DeviceRef?>(null)
    val cropDevice: StateFlow<DeviceRef?> = _cropDevice

    private val _history = MutableStateFlow<List<HistoryPoint>>(emptyList())
    val history: StateFlow<List<HistoryPoint>> = _history

    private val _events = MutableStateFlow<List<PlantEvent>>(emptyList())
    val events: StateFlow<List<PlantEvent>> = _events

    // ---- devices and users ----
    private val _devices = MutableStateFlow<List<DeviceInfo>>(emptyList())
    val devices: StateFlow<List<DeviceInfo>> = _devices

    private val _users = MutableStateFlow<List<AdminUser>>(emptyList())
    val users: StateFlow<List<AdminUser>> = _users

    // ---- messages ----
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error

    /** Short confirmation shown under a form ("Saved ✔") */
    private val _info = MutableStateFlow<String?>(null)
    val info: StateFlow<String?> = _info

    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy

    private val listPolling = mutableListOf<Job>()
    private val cropPolling = mutableListOf<Job>()

    init {
        if (api.token != null) {
            viewModelScope.launch {
                safely { signedIn(api.call("me.php").getJSONObject("user").toUser()) }
                _starting.value = false
            }
        }
    }

    // ------------------------------------------------------------------
    //  Sign in / create account / sign out
    // ------------------------------------------------------------------
    fun signIn(email: String, password: String) = login("login.php",
        JSONObject().put("email", email.trim()).put("password", password))

    /** Anyone can create an account (role "user") */
    fun register(fullName: String, email: String, password: String) = login("register.php",
        JSONObject().put("full_name", fullName.trim()).put("email", email.trim()).put("password", password))

    private fun login(path: String, body: JSONObject) {
        _busy.value = true
        _error.value = null
        viewModelScope.launch {
            try {
                val r = api.call(path, body)
                api.token = r.getString("token")
                prefs.edit().putString("token", api.token).apply()
                signedIn(r.getJSONObject("user").toUser())
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _error.value = e.message ?: "Error"
            } finally {
                _busy.value = false
            }
        }
    }

    private suspend fun signedIn(u: User) {
        _user.value = u
        _types.value = api.call("crop_types.php").getJSONArray("types").mapObjects { it.toCropType() }
        startListPolling()
        loadDevices()
    }

    fun signOut() {
        viewModelScope.launch {
            runCatching { api.call("logout.php", JSONObject()) }
            signedOut()
        }
    }

    private fun signedOut() {
        (listPolling + cropPolling).forEach { it.cancel() }
        listPolling.clear(); cropPolling.clear()
        api.token = null
        prefs.edit().remove("token").apply()
        _user.value = null
        _openCrop.value = null
        _crops.value = emptyList(); _devices.value = emptyList(); _users.value = emptyList()
    }

    // ------------------------------------------------------------------
    //  Crops
    // ------------------------------------------------------------------
    private fun startListPolling() {
        if (listPolling.isNotEmpty()) return
        listPolling += viewModelScope.launch {
            while (isActive) {
                safely { refreshCrops() }
                delay(10_000)
            }
        }
    }

    private suspend fun refreshCrops() {
        _crops.value = api.call("crops.php").getJSONArray("crops").mapObjects { it.toCrop() }
    }

    fun addCrop(name: String, typeCode: String, location: String) {
        viewModelScope.launch {
            safely {
                val r = api.call("crops.php", JSONObject().put("name", name.trim()).put("type_code", typeCode).put("location", location.trim()))
                refreshCrops()
                openCrop(r.getInt("crop_id"))
            }
        }
    }

    /** Opens the detail page of a crop and starts refreshing it */
    fun openCrop(cropId: Int) {
        closeCrop()
        _openCrop.value = cropId
        _info.value = null
        every(5_000) { loadLive(cropId) }
        every(15_000) {
            _events.value = api.call("events.php?crop=$cropId&limit=30").getJSONArray("events").mapObjects { it.toEvent() }
        }
        every(300_000) {
            _history.value = api.call("history.php?crop=$cropId&hours=24").getJSONArray("history").mapObjects { it.toHistory() }
        }
    }

    fun closeCrop() {
        cropPolling.forEach { it.cancel() }
        cropPolling.clear()
        _openCrop.value = null
        _live.value = null; _history.value = emptyList(); _events.value = emptyList()
        _cropDevice.value = null; _settings.value = CropSettings()
    }

    private suspend fun loadLive(cropId: Int) {
        val r = api.call("live.php?crop=$cropId")
        _live.value = r.optJSONObject("live")?.toLive()
        _settings.value = r.getJSONObject("config").toSettings()
        _cropDevice.value = r.optJSONObject("device")?.toDeviceRef()
    }

    /** Saves name, type, location, thresholds and mute of the open crop */
    fun saveSettings(s: CropSettings) {
        val id = _openCrop.value ?: return
        viewModelScope.launch {
            safely {
                api.call("crop_update.php?crop=$id", s.toJson())
                loadLive(id)
                refreshCrops()
                _info.value = "✔"
            }
        }
    }

    fun setMuted(muted: Boolean) = saveSettings(_settings.value.copy(muted = muted))

    fun deleteCrop() {
        val id = _openCrop.value ?: return
        viewModelScope.launch {
            safely {
                api.call("crop_delete.php?crop=$id", JSONObject())
                closeCrop()
                refreshCrops()
                loadDevices()
            }
        }
    }

    /** Ask the device of the open crop to play buzzer melody [track] (1..9) */
    fun playSound(track: Int) {
        val id = _openCrop.value ?: return
        viewModelScope.launch { safely { api.call("command.php?crop=$id", JSONObject().put("play", track)); _info.value = "♪" } }
    }

    // ------------------------------------------------------------------
    //  Devices
    // ------------------------------------------------------------------
    fun loadDevices() {
        viewModelScope.launch {
            safely { _devices.value = api.call("devices.php").getJSONArray("devices").mapObjects { it.toDeviceInfo() } }
        }
    }

    /** Adds a device with the DEVICE_ID / DEVICE_KEY of its firmware (an admin can register a new ID) */
    fun addDevice(deviceId: String, key: String, name: String) {
        viewModelScope.launch {
            safely {
                api.call("devices.php", JSONObject().put("device_id", deviceId.trim()).put("device_key", key).put("name", name.trim()))
                _info.value = "✔"
                _devices.value = api.call("devices.php").getJSONArray("devices").mapObjects { it.toDeviceInfo() }
            }
        }
    }

    /** Moves a device to a crop (cropId = null → not assigned) */
    fun assignDevice(deviceId: String, cropId: Int?) {
        viewModelScope.launch {
            safely {
                api.call("device_assign.php", JSONObject().put("device_id", deviceId).put("crop_id", cropId ?: JSONObject.NULL))
                _devices.value = api.call("devices.php").getJSONArray("devices").mapObjects { it.toDeviceInfo() }
                refreshCrops()
                _openCrop.value?.let { loadLive(it) }
                _info.value = "✔"
            }
        }
    }

    // ------------------------------------------------------------------
    //  Users (admin only)
    // ------------------------------------------------------------------
    fun loadUsers() {
        viewModelScope.launch {
            safely { _users.value = api.call("users.php").getJSONArray("users").mapObjects { it.toAdminUser() } }
        }
    }

    private fun usersAction(body: JSONObject) {
        viewModelScope.launch {
            safely {
                api.call("users.php", body)
                _info.value = "✔"
                _users.value = api.call("users.php").getJSONArray("users").mapObjects { it.toAdminUser() }
            }
        }
    }

    fun createUser(fullName: String, email: String, password: String, role: String) = usersAction(
        JSONObject().put("action", "create").put("full_name", fullName.trim()).put("email", email.trim())
            .put("password", password).put("role", role))

    fun setRole(userId: Int, role: String) = usersAction(JSONObject().put("action", "role").put("user_id", userId).put("role", role))

    fun deleteUser(userId: Int) = usersAction(JSONObject().put("action", "delete").put("user_id", userId))

    fun clearMessages() { _error.value = null; _info.value = null }

    // ------------------------------------------------------------------
    private suspend fun safely(block: suspend () -> Unit) {
        try {
            block()
            _error.value = null
        } catch (e: CancellationException) {
            throw e                                   // polling stopped (sign out / other crop)
        } catch (e: ApiException) {
            if (e.code == 401 && api.token != null) signedOut() else _error.value = e.message
        } catch (e: Exception) {
            _error.value = "Server not reachable: ${e.message}"
        }
    }

    private fun every(ms: Long, block: suspend () -> Unit) {
        cropPolling += viewModelScope.launch {
            while (isActive) {
                safely(block)
                delay(ms)
            }
        }
    }
}
