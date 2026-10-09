package com.rayy.app.ui

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// =====================================================================
//  Small design kit used by every screen of ري
// =====================================================================

/** Green (or mood) gradient header with rounded bottom corners */
@Composable
fun GradientHeader(
    top: Color = Leaf700,
    bottom: Color = Leaf500,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(bottomStart = 32.dp, bottomEnd = 32.dp))
            .background(Brush.verticalGradient(listOf(top, bottom)))
            .statusBarsPadding()
            .padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 24.dp),
        content = content,
    )
}

/** Rounded "glass" tile used on top of gradient headers */
@Composable
fun GlassTile(emoji: String, value: String, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier
            .clip(MaterialTheme.shapes.medium)
            .background(Color.White.copy(alpha = 0.18f))
            .padding(vertical = 10.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(emoji, fontSize = 18.sp)
        Text(value, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
        Text(label, color = Color.White.copy(alpha = 0.85f), fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** Little coloured pill: "● Online", "Admin", a crop type … */
@Composable
fun Pill(text: String, color: Color, modifier: Modifier = Modifier, filled: Boolean = false, dot: Boolean = false) {
    Row(
        modifier
            .clip(CircleShape)
            .background(if (filled) color else color.copy(alpha = 0.13f))
            .padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (dot) {
            Box(Modifier.size(7.dp).clip(CircleShape).background(if (filled) Color.White else color))
            Spacer(Modifier.width(6.dp))
        }
        Text(text, color = if (filled) Color.White else color, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

@Composable
fun OnlinePill(online: Boolean, onlineText: String, offlineText: String, onGradient: Boolean = false) {
    val c = when {
        onGradient -> Color.White
        online -> Leaf500
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Pill(if (online) onlineText else offlineText, c, dot = true)
}

/** Emoji inside a soft circle */
@Composable
fun EmojiBadge(emoji: String, background: Color, size: Dp = 56.dp, fontSize: Int = 30) {
    Box(Modifier.size(size).clip(CircleShape).background(background), contentAlignment = Alignment.Center) {
        Text(emoji, fontSize = fontSize.sp)
    }
}

/** Emoji that gently floats up and down (the crop is "alive") */
@Composable
fun FloatingEmoji(emoji: String, fontSize: Int = 84) {
    val t = rememberInfiniteTransition(label = "float")
    val dy by t.animateFloat(
        initialValue = 0f, targetValue = -10f,
        animationSpec = infiniteRepeatable(tween(1600, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "dy",
    )
    Text(emoji, fontSize = fontSize.sp, modifier = Modifier.graphicsLayer { translationY = dy * density })
}

/** Circle with the first letter of a name */
@Composable
fun Avatar(name: String, size: Dp = 44.dp) {
    val palette = listOf(Leaf500, Water, AlertOrange, NightPurple, Color(0xFFB0457A), Color(0xFF00897B))
    val c = palette[(name.hashCode() and 0x7fffffff) % palette.size]
    Box(Modifier.size(size).clip(CircleShape).background(c.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) {
        Text(name.trim().take(1).uppercase(), color = c, fontWeight = FontWeight.Bold, fontSize = (size.value / 2.4f).sp)
    }
}

/** White rounded card with an optional emoji + title row */
@Composable
fun SectionCard(
    title: String? = null,
    emoji: String? = null,
    modifier: Modifier = Modifier,
    trailing: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (title != null) Row(verticalAlignment = Alignment.CenterVertically) {
                if (emoji != null) {
                    EmojiBadge(emoji, MaterialTheme.colorScheme.primaryContainer, size = 36.dp, fontSize = 18)
                    Spacer(Modifier.width(10.dp))
                }
                Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                trailing()
            }
            content()
        }
    }
}

/** Kept for compatibility with older screens: a simple titled card */
@Composable
fun Section(title: String, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    SectionCard(title, modifier = modifier) { content() }
}

/** Metric tile: icon, value + unit, label, and an optional ring showing the value (0..1) */
@Composable
fun MetricTile(
    emoji: String, label: String, value: String, unit: String, accent: Color,
    modifier: Modifier = Modifier, progress: Float? = null, note: String? = null,
) {
    Card(
        modifier,
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(emoji, fontSize = 16.sp)
                    Spacer(Modifier.width(6.dp))
                    Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Spacer(Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(value, style = NumberStyle)
                    Text(" $unit", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(bottom = 4.dp))
                }
                if (note != null) Text(note, style = MaterialTheme.typography.labelSmall, color = accent, maxLines = 1,
                    overflow = TextOverflow.Ellipsis)
            }
            if (progress != null) Ring(progress, accent, size = 42.dp)
        }
    }
}

/** Circular gauge (value 0..1) */
@Composable
fun Ring(progress: Float, color: Color, size: Dp = 44.dp, stroke: Dp = 6.dp) {
    val track = color.copy(alpha = 0.15f)
    Canvas(Modifier.size(size)) {
        val s = stroke.toPx()
        val arc = Size(this.size.width - s, this.size.height - s)
        val tl = Offset(s / 2, s / 2)
        drawArc(track, -90f, 360f, false, tl, arc, style = Stroke(s, cap = StrokeCap.Round))
        drawArc(color, -90f, 360f * progress.coerceIn(0f, 1f), false, tl, arc, style = Stroke(s, cap = StrokeCap.Round))
    }
}

/** A button-like field that opens a list to choose one option (crop type, device, crop, role …) */
@Composable
fun <T> Picker(
    label: String,
    options: List<T>,
    selected: T?,
    text: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "—",
) {
    var open by remember { mutableStateOf(false) }
    Column(modifier) {
        if (label.isNotEmpty()) Text(label, style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(bottom = 4.dp))
        Box {
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(MaterialTheme.shapes.medium)
                    .border(1.dp, MaterialTheme.colorScheme.outline, MaterialTheme.shapes.medium)
                    .clickable { open = true }
                    .padding(horizontal = 14.dp, vertical = 13.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(selected?.let(text) ?: placeholder, Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis,
                    color = if (selected == null) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
                Icon(Icons.Filled.ArrowDropDown, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                options.forEach { o ->
                    DropdownMenuItem(text = { Text(text(o)) }, onClick = { onSelect(o); open = false })
                }
            }
        }
    }
}

/** Rounded text field with an optional leading icon and a show/hide button for passwords */
@Composable
fun Field(
    label: String, value: String, onChange: (String) -> Unit, modifier: Modifier = Modifier,
    keyboard: KeyboardType = KeyboardType.Text, password: Boolean = false, icon: ImageVector? = null,
) {
    var visible by remember { mutableStateOf(false) }
    OutlinedTextField(
        value = value, onValueChange = onChange,
        label = { Text(label) },
        singleLine = true,
        leadingIcon = icon?.let { { Icon(it, contentDescription = null) } },
        trailingIcon = if (password) {
            { Text(if (visible) "🙈" else "👁️", fontSize = 18.sp, modifier = Modifier.clip(CircleShape).clickable { visible = !visible }.padding(8.dp)) }
        } else null,
        keyboardOptions = KeyboardOptions(keyboardType = keyboard),
        visualTransformation = if (password && !visible) PasswordVisualTransformation() else VisualTransformation.None,
        shape = MaterialTheme.shapes.medium,
        colors = OutlinedTextFieldDefaults.colors(unfocusedBorderColor = MaterialTheme.colorScheme.outline),
        modifier = modifier.fillMaxWidth(),
    )
}

/** Friendly empty state: big emoji, title, hint */
@Composable
fun EmptyState(emoji: String, title: String, hint: String? = null, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth().padding(vertical = 40.dp, horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        EmojiBadge(emoji, MaterialTheme.colorScheme.primaryContainer, size = 96.dp, fontSize = 48)
        Spacer(Modifier.height(16.dp))
        Text(title, style = MaterialTheme.typography.titleMedium)
        if (hint != null) Text(hint, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp))
    }
}

/** Segmented control: [ A | B | C ] */
@Composable
fun Segmented(options: List<String>, selected: Int, onSelect: (Int) -> Unit, modifier: Modifier = Modifier) {
    Surface(modifier.fillMaxWidth(), shape = CircleShape, color = MaterialTheme.colorScheme.surfaceVariant) {
        Row(Modifier.padding(4.dp)) {
            options.forEachIndexed { i, o ->
                val sel = i == selected
                Box(
                    Modifier
                        .weight(1f)
                        .clip(CircleShape)
                        .background(if (sel) MaterialTheme.colorScheme.surface else Color.Transparent)
                        .clickable { onSelect(i) }
                        .padding(vertical = 10.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(o, fontWeight = if (sel) FontWeight.Bold else FontWeight.Medium,
                        color = if (sel) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

/** Space at the end of scrolling lists so the last card is not hidden by the button / bar */
val ListEndPadding = PaddingValues(bottom = 96.dp)

/** "12.0" → "12", "12.5" → "12.5" for number fields */
/** Keeps a number range like "40–80%" or "-58 dBm" in order inside Arabic (RTL) text */
fun ltr(s: String) = "\u2066$s\u2069"

fun Double.clean(): String = if (this % 1.0 == 0.0) toLong().toString() else toString()
