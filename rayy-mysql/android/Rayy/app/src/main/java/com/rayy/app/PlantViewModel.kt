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
 * Connects the app to the XAMPP server (PHP API + MySQL) and keeps the latest
 * plant data in StateFlows that the Compose screens observe.
 * The data is refreshed by polling: live every 5 s, diary every 15 s, history every 5 min.
 */
class PlantViewModel(app: Application) : AndroidViewModel(app) {

    private val prefs = app.getSharedPreferences("rayy", Context.MODE_PRIVATE)
    private val api = ApiClient(prefs.getString("token", null))

    private val _signedIn = MutableStateFlow(api.token != null)
    val signedIn: StateFlow<Boolean> = _signedIn

    private val _live = MutableStateFlow<PlantLive?>(null)
    val live: StateFlow<PlantLive?> = _live

    private val _history = MutableStateFlow<List<HistoryPoint>>(emptyList())
    val history: StateFlow<List<HistoryPoint>> = _history

    private val _events = MutableStateFlow<List<PlantEvent>>(emptyList())
    val events: StateFlow<List<PlantEvent>> = _events

    private val _settings = MutableStateFlow(PlantSettings())
    val settings: StateFlow<PlantSettings> = _settings

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error

    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy

    private val polling = mutableListOf<Job>()

    init {
        if (_signedIn.value) startPolling()
    }

    // ------------------------------------------------------------------
    fun signIn(email: String, password: String) {
        if (email.isBlank() || password.isBlank()) return
        _busy.value = true
        _error.value = null
        viewModelScope.launch {
            try {
                val r = api.call("login.php", JSONObject().put("email", email.trim()).put("password", password))
                api.token = r.getString("token")
                prefs.edit().putString("token", api.token).apply()
                _signedIn.value = true
                startPolling()
            } catch (e: Exception) {
                _error.value = e.message ?: "Sign-in failed"
            } finally {
                _busy.value = false
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            runCatching { api.call("logout.php", JSONObject()) }
            signedOut()
        }
    }

    /** Ask the plant to play buzzer melody [track] (1..9) */
    fun playSound(track: Int) {
        viewModelScope.launch { safely { api.call("command.php", JSONObject().put("play", track)) } }
    }

    fun setMuted(muted: Boolean) {
        _settings.value = _settings.value.copy(muted = muted)
        viewModelScope.launch {
            safely { _settings.value = api.call("settings.php", JSONObject().put("muted", muted)).getJSONObject("config").toSettings() }
        }
    }

    // ------------------------------------------------------------------
    private suspend fun safely(block: suspend () -> Unit) {
        try {
            block()
            _error.value = null
        } catch (e: CancellationException) {
            throw e                                   // the polling was stopped (sign out)
        } catch (e: ApiException) {
            if (e.code == 401) signedOut() else _error.value = e.message
        } catch (e: Exception) {
            _error.value = "Server not reachable: ${e.message}"
        }
    }

    private fun every(ms: Long, block: suspend () -> Unit) {
        polling += viewModelScope.launch {
            while (isActive) {
                safely(block)
                delay(ms)
            }
        }
    }

    private fun startPolling() {
        if (polling.isNotEmpty()) return
        every(5_000) {
            val r = api.call("live.php")
            _live.value = r.optJSONObject("live")?.toLive()
            _settings.value = r.getJSONObject("config").toSettings()
        }
        every(15_000) {
            val a = api.call("events.php?limit=30").getJSONArray("events")
            _events.value = (0 until a.length()).map { a.getJSONObject(it).toEvent() }
        }
        every(300_000) {
            val a = api.call("history.php?hours=24").getJSONArray("history")
            _history.value = (0 until a.length()).map { a.getJSONObject(it).toHistory() }
        }
    }

    private fun signedOut() {
        polling.forEach { it.cancel() }
        polling.clear()
        api.token = null
        prefs.edit().remove("token").apply()
        _signedIn.value = false
        _live.value = null
        _history.value = emptyList()
        _events.value = emptyList()
    }
}
