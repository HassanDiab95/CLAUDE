package com.rayy.app.ui

import com.rayy.app.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Emoji + text resources for every mood sent by the ESP32 */
data class MoodUi(val emoji: String, val title: Int, val message: Int, val alert: Boolean)

fun moodUi(mood: String): MoodUi = when (mood) {
    "happy" -> MoodUi("😊", R.string.mood_happy, R.string.msg_happy, false)
    "thirsty" -> MoodUi("😫", R.string.mood_thirsty, R.string.msg_thirsty, true)
    "drowning" -> MoodUi("🥴", R.string.mood_drowning, R.string.msg_drowning, true)
    "hot" -> MoodUi("🥵", R.string.mood_hot, R.string.msg_hot, true)
    "cold" -> MoodUi("🥶", R.string.mood_cold, R.string.msg_cold, true)
    "need_light" -> MoodUi("😞", R.string.mood_need_light, R.string.msg_need_light, true)
    "sleepy" -> MoodUi("😴", R.string.mood_sleepy, R.string.msg_sleepy, false)
    else -> MoodUi("🌱", R.string.mood_unknown, R.string.msg_unknown, false)
}

/** Buzzer melodies (same numbers as the firmware, sound.cpp) */
val TRACK_NAMES = listOf(
    R.string.track_1, R.string.track_2, R.string.track_3, R.string.track_4, R.string.track_5,
    R.string.track_6, R.string.track_7, R.string.track_8, R.string.track_9,
)

fun formatTime(ts: Long, pattern: String = "HH:mm  d MMM"): String =
    if (ts <= 0) "—" else SimpleDateFormat(pattern, Locale.getDefault()).format(Date(ts))

fun Double?.show(digits: Int = 0): String = this?.let { "%.${digits}f".format(Locale.US, it) } ?: "—"
