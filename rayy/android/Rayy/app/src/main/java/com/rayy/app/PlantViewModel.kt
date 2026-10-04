package com.rayy.app

import androidx.lifecycle.ViewModel
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.Query
import com.google.firebase.database.ValueEventListener
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Connects the app to Firebase and keeps the latest plant data in StateFlows
 * that the Compose screens observe.
 */
class PlantViewModel : ViewModel() {

    private val auth = FirebaseAuth.getInstance()
    private val db = if (DATABASE_URL.isBlank()) FirebaseDatabase.getInstance()
                     else FirebaseDatabase.getInstance(DATABASE_URL)
    private val base: DatabaseReference = db.getReference("plants").child(PLANT_ID)

    private val _signedIn = MutableStateFlow(auth.currentUser != null)
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

    private val listeners = mutableListOf<Pair<Query, ValueEventListener>>()

    private val authListener = FirebaseAuth.AuthStateListener { a ->
        val ok = a.currentUser != null
        _signedIn.value = ok
        if (ok) startListening() else stopListening()
    }

    init {
        auth.addAuthStateListener(authListener)
    }

    // ------------------------------------------------------------------
    fun signIn(email: String, password: String) {
        if (email.isBlank() || password.isBlank()) return
        _busy.value = true
        _error.value = null
        auth.signInWithEmailAndPassword(email.trim(), password)
            .addOnCompleteListener { task ->
                _busy.value = false
                if (!task.isSuccessful) _error.value = task.exception?.localizedMessage ?: "Sign-in failed"
            }
    }

    fun signOut() = auth.signOut()

    /** Ask the plant to play buzzer melody [track] (1..9) */
    fun playSound(track: Int) {
        base.child("command").setValue(mapOf("play" to track))
    }

    fun setMuted(muted: Boolean) {
        base.child("config").child("muted").setValue(muted)
    }

    // ------------------------------------------------------------------
    private fun listen(query: Query, onData: (DataSnapshot) -> Unit) {
        val l = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) = onData(snapshot)
            override fun onCancelled(error: DatabaseError) {
                _error.value = error.message
            }
        }
        query.addValueEventListener(l)
        listeners += query to l
    }

    private fun startListening() {
        if (listeners.isNotEmpty()) return
        listen(base.child("live")) { _live.value = it.toLive() }
        // 288 points x 5 minutes = last 24 hours
        listen(base.child("history").limitToLast(288)) { s ->
            _history.value = s.children.map { it.toHistory() }.sortedBy { it.ts }
        }
        listen(base.child("events").limitToLast(30)) { s ->
            _events.value = s.children.map { it.toEvent() }.sortedByDescending { it.ts }
        }
        listen(base.child("config")) { _settings.value = it.toSettings() }
    }

    private fun stopListening() {
        listeners.forEach { (q, l) -> q.removeEventListener(l) }
        listeners.clear()
        _live.value = null
        _history.value = emptyList()
        _events.value = emptyList()
    }

    override fun onCleared() {
        auth.removeAuthStateListener(authListener)
        stopListening()
    }
}
