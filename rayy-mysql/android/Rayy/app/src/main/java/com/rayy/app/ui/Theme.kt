package com.rayy.app.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ---------------------------------------------------------------------
//  ري colours: fresh greens + one colour family per feeling
// ---------------------------------------------------------------------
val Leaf900 = Color(0xFF0F3D26)
val Leaf700 = Color(0xFF1E6B43)
val Leaf500 = Color(0xFF2F9E5F)
val Leaf300 = Color(0xFF7FD3A0)
val Leaf100 = Color(0xFFE2F5E9)
val Mint50 = Color(0xFFF4FAF6)
val Sun = Color(0xFFFFB020)
val Water = Color(0xFF2D8CFF)
val AlertOrange = Color(0xFFE07A00)
val AlertRed = Color(0xFFD64545)
val NightPurple = Color(0xFF5B5BD6)

/** Colours of a feeling: gradient for headers, soft tint for cards, strong colour for text/pills */
data class MoodColors(val top: Color, val bottom: Color, val tint: Color, val strong: Color)

fun moodColors(mood: String): MoodColors = when (mood) {
    "happy" -> MoodColors(Color(0xFF1E8C56), Color(0xFF4CC38A), Color(0xFFE6F7EE), Color(0xFF1E8C56))
    "thirsty", "hot" -> MoodColors(Color(0xFFE0682B), Color(0xFFFFB347), Color(0xFFFFF1E3), Color(0xFFC25A12))
    "drowning", "cold" -> MoodColors(Color(0xFF2468D8), Color(0xFF5FB1FF), Color(0xFFE6F1FF), Color(0xFF1D5BC0))
    "need_light" -> MoodColors(Color(0xFFC79100), Color(0xFFFFD45C), Color(0xFFFFF8DD), Color(0xFF8F6A00))
    "sleepy" -> MoodColors(Color(0xFF3E3FA8), Color(0xFF8C8CF0), Color(0xFFEDEDFD), Color(0xFF4141B5))
    else -> MoodColors(Leaf700, Leaf500, Leaf100, Leaf700)
}

/** Soft card background of a feeling: the light tint by day, a dim mood colour in dark mode */
@Composable
fun MoodColors.soft(): Color {
    val surface = MaterialTheme.colorScheme.surface
    return if (surface.luminance() < 0.5f) strong.copy(alpha = 0.28f).compositeOver(surface) else tint
}

private val Light = lightColorScheme(
    primary = Leaf500,
    onPrimary = Color.White,
    primaryContainer = Leaf100,
    onPrimaryContainer = Leaf900,
    secondary = Leaf700,
    secondaryContainer = Leaf100,
    onSecondaryContainer = Leaf900,
    tertiary = Sun,
    background = Mint50,
    onBackground = Color(0xFF15231B),
    surface = Color.White,
    onSurface = Color(0xFF15231B),
    surfaceVariant = Color(0xFFEFF5F1),
    onSurfaceVariant = Color(0xFF5B6B61),
    outline = Color(0xFFCBD9CF),
    outlineVariant = Color(0xFFE3ECE6),
    error = AlertRed,
)

private val Dark = darkColorScheme(
    primary = Leaf300,
    onPrimary = Leaf900,
    primaryContainer = Color(0xFF1C3A2A),
    onPrimaryContainer = Leaf100,
    secondary = Leaf300,
    secondaryContainer = Color(0xFF1C3A2A),
    onSecondaryContainer = Leaf100,
    tertiary = Sun,
    background = Color(0xFF0E1712),
    onBackground = Color(0xFFE3EEE7),
    surface = Color(0xFF16221B),
    onSurface = Color(0xFFE3EEE7),
    surfaceVariant = Color(0xFF1E2C24),
    onSurfaceVariant = Color(0xFFA7BAAE),
    outline = Color(0xFF34473B),
    outlineVariant = Color(0xFF26352C),
    error = Color(0xFFFF8A80),
)

private val RayyShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(18.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(32.dp),
)

private val Base = Typography()
private val RayyTypography = Typography(
    headlineLarge = Base.headlineLarge.copy(fontWeight = FontWeight.ExtraBold),
    headlineMedium = Base.headlineMedium.copy(fontWeight = FontWeight.Bold),
    headlineSmall = Base.headlineSmall.copy(fontWeight = FontWeight.Bold),
    titleLarge = Base.titleLarge.copy(fontWeight = FontWeight.Bold),
    titleMedium = Base.titleMedium.copy(fontWeight = FontWeight.SemiBold),
    labelLarge = Base.labelLarge.copy(fontWeight = FontWeight.SemiBold),
)

/** Big numbers of the metric tiles */
val NumberStyle = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.ExtraBold)

@Composable
fun RayyTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (dark) Dark else Light,
        shapes = RayyShapes,
        typography = RayyTypography,
        content = content,
    )
}
