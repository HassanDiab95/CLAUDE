package com.rayy.app.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val PlantGreen = Color(0xFF2F7D4F)
val PlantGreenLight = Color(0xFF5CC287)
val AlertOrange = Color(0xFFC77700)
val AlertRed = Color(0xFFC0392B)

private val Light = lightColorScheme(
    primary = PlantGreen,
    onPrimary = Color.White,
    secondaryContainer = Color(0xFFE3F2E7),
    background = Color(0xFFF3F7F2),
    surface = Color.White,
)

private val Dark = darkColorScheme(
    primary = PlantGreenLight,
    onPrimary = Color(0xFF0B2615),
    secondaryContainer = Color(0xFF213A2B),
    background = Color(0xFF111A14),
    surface = Color(0xFF1A251E),
)

@Composable
fun RayyTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) Dark else Light, content = content)
}
