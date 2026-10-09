package com.rayy.app.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rayy.app.CropSettings
import com.rayy.app.CropType
import com.rayy.app.DeviceInfo
import com.rayy.app.DeviceRef
import com.rayy.app.HistoryPoint
import com.rayy.app.PlantEvent
import com.rayy.app.PlantLive
import com.rayy.app.R
import com.rayy.app.RayyViewModel
import kotlinx.coroutines.delay

/** Page of one crop (data from the ViewModel) */
@Composable
fun CropScreen(vm: RayyViewModel) {
    val live by vm.live.collectAsStateWithLifecycle()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val types by vm.types.collectAsStateWithLifecycle()
    val device by vm.cropDevice.collectAsStateWithLifecycle()
    val devices by vm.devices.collectAsStateWithLifecycle()
    val history by vm.history.collectAsStateWithLifecycle()
    val events by vm.events.collectAsStateWithLifecycle()

    // Refresh the "online" badge every 15 s
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        vm.loadDevices()
        while (true) { delay(15_000); now = System.currentTimeMillis() }
    }
    CropContent(
        live, settings, types, device, devices, history, events, now,
        onBack = vm::closeCrop,
        onMoveHere = { vm.assignDevice(it, vm.openCrop.value) },
        onRemoveDevice = { vm.assignDevice(it, null) },
        onPlay = vm::playSound,
        onMute = vm::setMuted,
        onSave = vm::saveSettings,
        onDelete = vm::deleteCrop,
    )
}

@Composable
fun CropContent(
    live: PlantLive?,
    settings: CropSettings,
    types: List<CropType>,
    device: DeviceRef?,
    devices: List<DeviceInfo>,
    history: List<HistoryPoint>,
    events: List<PlantEvent>,
    now: Long,
    onBack: () -> Unit,
    onMoveHere: (String) -> Unit,
    onRemoveDevice: (String) -> Unit,
    onPlay: (Int) -> Unit,
    onMute: (Boolean) -> Unit,
    onSave: (CropSettings) -> Unit,
    onDelete: () -> Unit,
    startTab: Int = 0,
) {
    var tab by rememberSaveable { mutableIntStateOf(startTab) }
    val online = live?.isOnline(now) == true
    val mood = live?.mood ?: "unknown"
    val ui = moodUi(mood)
    val colors = moodColors(mood)
    val type = types.firstOrNull { it.code == settings.typeCode }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        // ---------- hero ----------
        GradientHeader(colors.top, colors.bottom) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back), tint = Color.White) }
                Column(Modifier.weight(1f)) {
                    Text(settings.name.ifEmpty { "…" }, color = Color.White, style = MaterialTheme.typography.titleLarge,
                        maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(type?.let { "${it.emoji} ${it.name}" } ?: "", color = Color.White.copy(alpha = 0.9f),
                            style = MaterialTheme.typography.bodySmall)
                        if (settings.location.isNotEmpty()) {
                            Spacer(Modifier.width(8.dp))
                            Icon(Icons.Filled.LocationOn, null, Modifier.size(14.dp), tint = Color.White.copy(alpha = 0.9f))
                            Text(settings.location, color = Color.White.copy(alpha = 0.9f), style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
                OnlinePill(online, stringResource(R.string.online), stringResource(R.string.offline), onGradient = true)
            }
            Column(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.size(132.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.2f)), contentAlignment = Alignment.Center) {
                    FloatingEmoji(ui.emoji, fontSize = 78)
                }
                Spacer(Modifier.height(10.dp))
                Text(stringResource(ui.title), color = Color.White, style = MaterialTheme.typography.headlineMedium)
                Text(stringResource(ui.message), color = Color.White.copy(alpha = 0.92f), textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodyLarge)
                Text("🕒 " + stringResource(R.string.last_update) + ": " + formatTime(live?.ts ?: 0),
                    color = Color.White.copy(alpha = 0.8f), style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(top = 6.dp))
            }
        }

        Segmented(
            listOf(stringResource(R.string.tab_crop), stringResource(R.string.tab_history), stringResource(R.string.tab_diary)),
            tab, { tab = it }, Modifier.padding(16.dp),
        )

        AnimatedContent(tab, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "tab") { t ->
            Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                when (t) {
                    0 -> Overview(live, settings, types, device, devices, online, onMoveHere, onRemoveDevice, onPlay, onMute, onSave, onDelete)
                    1 -> HistoryTab(history, settings)
                    else -> DiaryTab(events)
                }
            }
        }
    }
}

// ---------------------------------------------------------------------
//  Overview tab
// ---------------------------------------------------------------------
@Composable
private fun Overview(
    l: PlantLive?, s: CropSettings, types: List<CropType>, device: DeviceRef?, devices: List<DeviceInfo>, online: Boolean,
    onMoveHere: (String) -> Unit, onRemoveDevice: (String) -> Unit, onPlay: (Int) -> Unit, onMute: (Boolean) -> Unit,
    onSave: (CropSettings) -> Unit, onDelete: () -> Unit,
) {
    val ideal = stringResource(R.string.ideal)
    val m = l?.moisture
    val moistureColor = when {
        m == null -> MaterialTheme.colorScheme.onSurfaceVariant
        m < s.moistureMin -> AlertOrange
        m > s.moistureMax -> Water
        else -> Leaf500
    }
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        MetricTile("💧", stringResource(R.string.soil), m.show(), "%", moistureColor, Modifier.weight(1f),
            progress = ((m ?: 0.0) / 100).toFloat(), note = "$ideal " + ltr("${s.moistureMin.clean()}–${s.moistureMax.clean()}%"))
        val t = l?.temperature
        MetricTile("🌡️", stringResource(R.string.temperature), t.show(1), "°C",
            if (t != null && (t > s.tempMax || t < s.tempMin)) AlertOrange else Leaf500, Modifier.weight(1f),
            note = "$ideal " + ltr("${s.tempMin.clean()}–${s.tempMax.clean()}°"))
    }
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        MetricTile("💨", stringResource(R.string.humidity), l?.humidity.show(), "%", Water, Modifier.weight(1f),
            progress = ((l?.humidity ?: 0.0) / 100).toFloat())
        val lux = l?.lux
        MetricTile("☀️", stringResource(R.string.light), lux.show(), "lux",
            if (lux != null && lux < s.luxMin) AlertOrange else Leaf500, Modifier.weight(1f), note = "$ideal " + ltr("≥ ${s.luxMin.clean()}"))
    }
    l?.rssi?.let {
        Text(
            "📶 " + stringResource(R.string.wifi) + ": " + ltr("${it.show()} dBm") + " · " +
                stringResource(if (it > -60) R.string.signal_good else if (it > -75) R.string.signal_ok else R.string.signal_bad),
            style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 4.dp),
        )
    }
    DeviceCard(device, devices, online, onMoveHere, onRemoveDevice)
    SoundCard(s.muted, onPlay, onMute)
    SettingsCard(s, types, onSave)
    DeleteCropButton(onDelete)
}

/** Which device measures this crop, and moving another device here */
@Composable
private fun DeviceCard(device: DeviceRef?, devices: List<DeviceInfo>, online: Boolean, onMoveHere: (String) -> Unit, onRemove: (String) -> Unit) {
    var chosen by remember { mutableStateOf<DeviceInfo?>(null) }
    val others = devices.filter { it.deviceId != device?.deviceId }
    SectionCard(stringResource(R.string.crop_device), "📡") {
        if (device != null) {
            Row(
                Modifier.fillMaxWidth().clip(MaterialTheme.shapes.medium).background(MaterialTheme.colorScheme.primaryContainer).padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(device.name, fontWeight = FontWeight.Bold)
                    Text(device.deviceId, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                OnlinePill(online, stringResource(R.string.online), stringResource(R.string.offline))
            }
            TextButton(onClick = { onRemove(device.deviceId) }) { Text(stringResource(R.string.remove_device), color = AlertRed) }
        } else {
            Text(stringResource(R.string.no_device_here), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (devices.isEmpty()) {
            Text(stringResource(R.string.no_devices_yet), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else if (others.isNotEmpty()) {
            Picker("", others, chosen, { d -> "📡 " + d.name + if (d.cropName.isNotEmpty()) "  ·  ${d.cropEmoji} ${d.cropName}" else "" },
                { chosen = it }, placeholder = stringResource(R.string.choose_device))
            Button(
                onClick = { chosen?.let { onMoveHere(it.deviceId) }; chosen = null },
                enabled = chosen != null, modifier = Modifier.fillMaxWidth(), shape = MaterialTheme.shapes.medium,
            ) { Text("⇄  " + stringResource(R.string.move_here)) }
        }
    }
}

/** Melody chips + Play + Mute */
@Composable
private fun SoundCard(muted: Boolean, onPlay: (Int) -> Unit, onMute: (Boolean) -> Unit) {
    var track by rememberSaveable { mutableIntStateOf(1) }
    val names = TRACK_NAMES.map { stringResource(it) }
    SectionCard(stringResource(R.string.speak_title), "🎵") {
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            itemsIndexed(names) { i, n ->
                val sel = track == i + 1
                Column(
                    Modifier
                        .width(78.dp)
                        .clip(MaterialTheme.shapes.medium)
                        .background(if (sel) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant)
                        .border(2.dp, if (sel) MaterialTheme.colorScheme.primary else Color.Transparent, MaterialTheme.shapes.medium)
                        .clickable { track = i + 1 }
                        .padding(vertical = 10.dp, horizontal = 4.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(TRACK_EMOJI[i], fontSize = 24.sp)
                    Text(n, style = MaterialTheme.typography.labelSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
        Button(onClick = { onPlay(track) }, modifier = Modifier.fillMaxWidth(), shape = MaterialTheme.shapes.medium) {
            Icon(Icons.Filled.PlayArrow, null)
            Spacer(Modifier.width(6.dp))
            Text(stringResource(R.string.speak_now) + "  ·  " + names[track - 1])
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(if (muted) "🔇" else "🔊", fontSize = 20.sp)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.mute), Modifier.weight(1f))
            Switch(checked = muted, onCheckedChange = onMute)
        }
    }
}

/** Name, type, location and thresholds of the crop (folds open) */
@Composable
private fun SettingsCard(s: CropSettings, types: List<CropType>, onSave: (CropSettings) -> Unit) {
    var open by rememberSaveable { mutableStateOf(false) }
    // The form keeps its own copy; it is reloaded when the saved settings change
    var name by remember(s) { mutableStateOf(s.name) }
    var location by remember(s) { mutableStateOf(s.location) }
    var type by remember(s, types) { mutableStateOf(types.firstOrNull { it.code == s.typeCode }) }
    var mMin by remember(s) { mutableStateOf(s.moistureMin.clean()) }
    var mMax by remember(s) { mutableStateOf(s.moistureMax.clean()) }
    var tMin by remember(s) { mutableStateOf(s.tempMin.clean()) }
    var tMax by remember(s) { mutableStateOf(s.tempMax.clean()) }
    var lux by remember(s) { mutableStateOf(s.luxMin.clean()) }
    var qStart by remember(s) { mutableStateOf(s.quietStart.toString()) }
    var qEnd by remember(s) { mutableStateOf(s.quietEnd.toString()) }

    SectionCard(
        stringResource(R.string.settings), "⚙️", Modifier.animateContentSize(),
        trailing = {
            IconButton(onClick = { open = !open }) {
                Icon(if (open) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown, null)
            }
        },
    ) {
        if (!open) Text(
            "💧 " + ltr("${s.moistureMin.clean()}–${s.moistureMax.clean()}%") + "   🌡️ " + ltr("${s.tempMin.clean()}–${s.tempMax.clean()}°") +
                "   ☀️ " + ltr("≥ ${s.luxMin.clean()}") + "   🌙 " + ltr("${s.quietStart}–${s.quietEnd}"),
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.clickable { open = true },
        )
        AnimatedVisibility(open) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Field(stringResource(R.string.crop_name), name, { name = it })
                Picker(stringResource(R.string.crop_type), types, type, { "${it.emoji} ${it.name}" }, {
                    // a new type fills its ideal values (they can still be edited)
                    type = it
                    mMin = it.moistureMin.clean(); mMax = it.moistureMax.clean()
                    tMin = it.tempMin.clean(); tMax = it.tempMax.clean(); lux = it.luxMin.clean()
                })
                Field(stringResource(R.string.location), location, { location = it }, icon = Icons.Filled.LocationOn)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    NumberField("💧 " + stringResource(R.string.moisture_min), mMin, { mMin = it }, Modifier.weight(1f))
                    NumberField("💧 " + stringResource(R.string.moisture_max), mMax, { mMax = it }, Modifier.weight(1f))
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    NumberField("🌡️ " + stringResource(R.string.temp_min), tMin, { tMin = it }, Modifier.weight(1f))
                    NumberField("🌡️ " + stringResource(R.string.temp_max), tMax, { tMax = it }, Modifier.weight(1f))
                }
                NumberField("☀️ " + stringResource(R.string.lux_min), lux, { lux = it })
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    NumberField("🌙 " + stringResource(R.string.quiet_start), qStart, { qStart = it }, Modifier.weight(1f))
                    NumberField("☀️ " + stringResource(R.string.quiet_end), qEnd, { qEnd = it }, Modifier.weight(1f))
                }
                Button(
                    onClick = {
                        onSave(s.copy(
                            name = name, location = location, typeCode = type?.code ?: s.typeCode,
                            moistureMin = mMin.toDoubleOrNull() ?: s.moistureMin, moistureMax = mMax.toDoubleOrNull() ?: s.moistureMax,
                            tempMin = tMin.toDoubleOrNull() ?: s.tempMin, tempMax = tMax.toDoubleOrNull() ?: s.tempMax,
                            luxMin = lux.toDoubleOrNull() ?: s.luxMin,
                            quietStart = qStart.toIntOrNull() ?: s.quietStart, quietEnd = qEnd.toIntOrNull() ?: s.quietEnd,
                        ))
                        open = false
                    },
                    enabled = name.isNotBlank(),
                    modifier = Modifier.fillMaxWidth().height(50.dp), shape = MaterialTheme.shapes.medium,
                ) { Text(stringResource(R.string.save)) }
            }
        }
    }
}

@Composable
private fun DeleteCropButton(onDelete: () -> Unit) {
    var confirm by remember { mutableStateOf(false) }
    OutlinedButton(
        onClick = { confirm = true },
        modifier = Modifier.fillMaxWidth(), shape = MaterialTheme.shapes.medium,
        colors = ButtonDefaults.outlinedButtonColors(contentColor = AlertRed),
    ) {
        Icon(Icons.Filled.Delete, null)
        Spacer(Modifier.width(6.dp))
        Text(stringResource(R.string.delete_crop))
    }
    if (confirm) AlertDialog(
        onDismissRequest = { confirm = false },
        icon = { Text("🗑️", fontSize = 32.sp) },
        text = { Text(stringResource(R.string.confirm_delete_crop)) },
        confirmButton = { TextButton(onClick = { confirm = false; onDelete() }) { Text(stringResource(R.string.delete), color = AlertRed) } },
        dismissButton = { TextButton(onClick = { confirm = false }) { Text(stringResource(R.string.cancel)) } },
    )
}

@Composable
private fun NumberField(label: String, value: String, onChange: (String) -> Unit, modifier: Modifier = Modifier) {
    OutlinedTextField(
        value = value, onValueChange = onChange, label = { Text(label, fontSize = 12.sp, maxLines = 1) }, singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        shape = MaterialTheme.shapes.medium,
        modifier = modifier.fillMaxWidth(),
    )
}

// ---------------------------------------------------------------------
//  History tab: chart of the last 24 hours with the ideal range
// ---------------------------------------------------------------------
@Composable
private fun HistoryTab(history: List<HistoryPoint>, s: CropSettings) {
    data class M(val emoji: String, val label: Int, val unit: String, val color: Color, val pick: (HistoryPoint) -> Double?, val low: Double?, val high: Double?)
    val metrics = listOf(
        M("💧", R.string.soil, "%", Leaf500, { it.moisture }, s.moistureMin, s.moistureMax),
        M("🌡️", R.string.temperature, "°C", AlertOrange, { it.temperature }, s.tempMin, s.tempMax),
        M("💨", R.string.humidity, "%", Water, { it.humidity }, null, null),
        M("☀️", R.string.light, "lux", Sun, { it.lux }, s.luxMin, null),
    )
    var selected by rememberSaveable { mutableIntStateOf(0) }
    val m = metrics[selected]
    val points = history.filter { m.pick(it) != null }
    val values = points.map { m.pick(it)!! }

    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        metrics.forEachIndexed { i, x ->
            val sel = i == selected
            Column(
                Modifier.weight(1f).clip(MaterialTheme.shapes.medium)
                    .background(if (sel) x.color.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surface)
                    .border(2.dp, if (sel) x.color else MaterialTheme.colorScheme.outlineVariant, MaterialTheme.shapes.medium)
                    .clickable { selected = i }.padding(vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(x.emoji, fontSize = 20.sp)
                Text(stringResource(x.label), style = MaterialTheme.typography.labelSmall, maxLines = 1,
                    fontWeight = if (sel) FontWeight.Bold else FontWeight.Normal)
            }
        }
    }
    SectionCard(stringResource(R.string.history_title), "📈") {
        LineChart(values, m.color, low = m.low, high = m.high)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(formatTime(points.firstOrNull()?.ts ?: 0, "HH:mm"), style = MaterialTheme.typography.labelSmall)
            if (m.low != null || m.high != null) Text("- - " + stringResource(R.string.ideal_range), style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(formatTime(points.lastOrNull()?.ts ?: 0, "HH:mm"), style = MaterialTheme.typography.labelSmall)
        }
    }
    if (values.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StatBox(stringResource(R.string.min), values.min().show(1) + " " + m.unit, Modifier.weight(1f))
        StatBox(stringResource(R.string.avg), values.average().show(1) + " " + m.unit, Modifier.weight(1f))
        StatBox(stringResource(R.string.max), values.max().show(1) + " " + m.unit, Modifier.weight(1f))
    }
}

@Composable
private fun StatBox(label: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier.clip(MaterialTheme.shapes.medium).background(MaterialTheme.colorScheme.surface).padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, maxLines = 1)
    }
}

// ---------------------------------------------------------------------
//  Diary tab: timeline of the mood changes
// ---------------------------------------------------------------------
@Composable
private fun DiaryTab(events: List<PlantEvent>) {
    if (events.isEmpty()) {
        EmptyState("📔", stringResource(R.string.no_events))
        return
    }
    SectionCard {
        events.forEachIndexed { i, e ->
            val ui = moodUi(e.mood)
            val c = moodColors(e.mood)
            Row {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    EmojiBadge(ui.emoji, c.soft(), size = 44.dp, fontSize = 22)
                    if (i < events.lastIndex) Box(Modifier.width(2.dp).height(28.dp).background(MaterialTheme.colorScheme.outlineVariant))
                }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.padding(top = 2.dp)) {
                    Text(stringResource(ui.title), fontWeight = FontWeight.Bold, color = c.strong)
                    Text(stringResource(ui.message), style = MaterialTheme.typography.bodyMedium)
                    Text(formatTime(e.ts), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}
