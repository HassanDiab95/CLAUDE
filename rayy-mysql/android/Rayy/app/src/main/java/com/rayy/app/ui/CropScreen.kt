package com.rayy.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rayy.app.CropSettings
import com.rayy.app.CropType
import com.rayy.app.DeviceInfo
import com.rayy.app.DeviceRef
import com.rayy.app.HistoryPoint
import com.rayy.app.PlantEvent
import com.rayy.app.R
import com.rayy.app.RayyViewModel
import kotlinx.coroutines.delay

/** Detail page of one crop: three tabs Crop · History · Diary */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CropScreen(vm: RayyViewModel) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    val history by vm.history.collectAsStateWithLifecycle()
    val events by vm.events.collectAsStateWithLifecycle()

    Column {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(R.string.tab_crop, R.string.tab_history, R.string.tab_diary).forEachIndexed { i, label ->
                FilterChip(selected = tab == i, onClick = { tab = i }, label = { Text(stringResource(label)) })
            }
        }
        when (tab) {
            0 -> CropTab(vm)
            1 -> HistoryTab(history)
            else -> DiaryTab(events)
        }
    }
}

// ---------------------------------------------------------------------
//  Crop tab: big emoji + live values + device + sound + settings
// ---------------------------------------------------------------------
@Composable
private fun CropTab(vm: RayyViewModel) {
    val live by vm.live.collectAsStateWithLifecycle()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val types by vm.types.collectAsStateWithLifecycle()
    val device by vm.cropDevice.collectAsStateWithLifecycle()
    val devices by vm.devices.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()
    val info by vm.info.collectAsStateWithLifecycle()

    // Refresh the "online" badge every 15 s
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        vm.loadDevices()
        while (true) { delay(15_000); now = System.currentTimeMillis() }
    }
    val l = live
    val online = l?.isOnline(now) == true
    val ui = moodUi(l?.mood ?: "unknown")
    val type = types.firstOrNull { it.code == settings.typeCode }

    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Card(
            Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = if (ui.alert) Color(0xFFFFF3E0) else MaterialTheme.colorScheme.secondaryContainer,
            ),
        ) {
            Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(ui.emoji, fontSize = 72.sp)
                Spacer(Modifier.width(16.dp))
                val c = if (ui.alert) Color(0xFF6B3D00) else Color.Unspecified
                Column {
                    Text((type?.let { "${it.emoji} ${it.name}" } ?: "") + if (settings.location.isNotEmpty()) " · ${settings.location}" else "",
                        style = MaterialTheme.typography.bodySmall, color = c)
                    Text(stringResource(ui.title), style = MaterialTheme.typography.headlineSmall, color = c)
                    Text(stringResource(ui.message), color = c)
                    Text(
                        (if (online) "● " + stringResource(R.string.online) else "● " + stringResource(R.string.offline)) +
                            "  ·  " + stringResource(R.string.last_update) + ": " + formatTime(l?.ts ?: 0),
                        style = MaterialTheme.typography.bodySmall, color = c,
                    )
                }
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Metric("💧", stringResource(R.string.soil), l?.moisture.show(), "%", Modifier.weight(1f),
                progress = l?.moisture?.div(100),
                progressColor = if ((l?.moisture ?: 100.0) < settings.moistureMin) AlertRed else null)
            Metric("🌡️", stringResource(R.string.temperature), l?.temperature.show(1), "°C", Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Metric("💨", stringResource(R.string.humidity), l?.humidity.show(), "%", Modifier.weight(1f))
            Metric("☀️", stringResource(R.string.light), l?.lux.show(), "lux", Modifier.weight(1f))
        }
        Metric("📶", stringResource(R.string.wifi), l?.rssi.show(), "dBm", Modifier.fillMaxWidth(),
            note = l?.rssi?.let {
                stringResource(if (it > -60) R.string.signal_good else if (it > -75) R.string.signal_ok else R.string.signal_bad)
            })

        DeviceCard(device, devices,
            onMoveHere = { vm.assignDevice(it.deviceId, vm.openCrop.value) },
            onRemove = { d -> vm.assignDevice(d.deviceId, null) })
        SpeakCard(settings.muted, vm)
        SettingsCard(settings, types, vm)

        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        info?.let { Text(stringResource(R.string.done) + " " + it, color = MaterialTheme.colorScheme.primary) }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun Metric(
    icon: String, title: String, value: String, unit: String, modifier: Modifier = Modifier,
    progress: Double? = null, progressColor: Color? = null, note: String? = null,
) {
    Card(modifier) {
        Column(Modifier.padding(14.dp)) {
            Text("$icon  $title", style = MaterialTheme.typography.bodySmall)
            Row(verticalAlignment = Alignment.Bottom) {
                Text(value, fontSize = 30.sp, fontWeight = FontWeight.Bold)
                Text(" $unit", style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(bottom = 6.dp))
            }
            if (progress != null) {
                LinearProgressIndicator(
                    progress = { progress.toFloat().coerceIn(0f, 1f) },
                    modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                    color = progressColor ?: MaterialTheme.colorScheme.primary,
                )
            }
            if (note != null) Text(note, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 4.dp))
        }
    }
}

/** Which device measures this crop, and moving another device here */
@Composable
private fun DeviceCard(device: DeviceRef?, devices: List<DeviceInfo>, onMoveHere: (DeviceInfo) -> Unit, onRemove: (DeviceRef) -> Unit) {
    var chosen by remember { mutableStateOf<DeviceInfo?>(null) }
    val others = devices.filter { it.deviceId != device?.deviceId }
    Section("📡 " + stringResource(R.string.crop_device)) {
        Text(
            if (device != null) stringResource(R.string.device_on) + " ${device.name} (${device.deviceId})"
            else stringResource(R.string.no_device_here),
            style = MaterialTheme.typography.bodyMedium,
        )
        if (device != null) TextButton(onClick = { onRemove(device) }) { Text(stringResource(R.string.remove_device)) }
        if (devices.isEmpty()) {
            Text(stringResource(R.string.no_devices_yet), style = MaterialTheme.typography.bodySmall)
        } else if (others.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            Picker("", others, chosen, { d -> d.name + if (d.cropName.isNotEmpty()) " · ${d.cropEmoji} ${d.cropName}" else "" },
                { chosen = it }, placeholder = stringResource(R.string.choose_device))
            Button(onClick = { chosen?.let(onMoveHere); chosen = null }, enabled = chosen != null, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.move_here))
            }
        }
    }
}

@Composable
private fun SpeakCard(muted: Boolean, vm: RayyViewModel) {
    var track by rememberSaveable { mutableIntStateOf(1) }
    val names = TRACK_NAMES.map { stringResource(it) }
    Section(stringResource(R.string.speak_title)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Picker("", (1..9).toList(), track, { "$it. ${names[it - 1]}" }, { track = it }, Modifier.weight(1f))
            Spacer(Modifier.width(8.dp))
            Button(onClick = { vm.playSound(track) }) { Text(stringResource(R.string.speak_now)) }
        }
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.mute), Modifier.weight(1f))
            Switch(checked = muted, onCheckedChange = vm::setMuted)
        }
    }
}

/** Name, type, location and thresholds of the crop */
@Composable
private fun SettingsCard(s: CropSettings, types: List<CropType>, vm: RayyViewModel) {
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
    var confirmDelete by remember { mutableStateOf(false) }

    Section(stringResource(R.string.settings)) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Field(stringResource(R.string.crop_name), name, { name = it })
            Picker(stringResource(R.string.crop_type), types, type, { "${it.emoji} ${it.name}" }, {
                // a new type fills its ideal values (they can still be edited)
                type = it
                mMin = it.moistureMin.clean(); mMax = it.moistureMax.clean()
                tMin = it.tempMin.clean(); tMax = it.tempMax.clean(); lux = it.luxMin.clean()
            })
            Field(stringResource(R.string.location), location, { location = it })
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                NumberField(stringResource(R.string.moisture_min), mMin, { mMin = it }, Modifier.weight(1f))
                NumberField(stringResource(R.string.moisture_max), mMax, { mMax = it }, Modifier.weight(1f))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                NumberField(stringResource(R.string.temp_min), tMin, { tMin = it }, Modifier.weight(1f))
                NumberField(stringResource(R.string.temp_max), tMax, { tMax = it }, Modifier.weight(1f))
            }
            NumberField(stringResource(R.string.lux_min), lux, { lux = it })
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                NumberField(stringResource(R.string.quiet_start), qStart, { qStart = it }, Modifier.weight(1f))
                NumberField(stringResource(R.string.quiet_end), qEnd, { qEnd = it }, Modifier.weight(1f))
            }
            Button(
                onClick = {
                    vm.saveSettings(s.copy(
                        name = name, location = location, typeCode = type?.code ?: s.typeCode,
                        moistureMin = mMin.toDoubleOrNull() ?: s.moistureMin, moistureMax = mMax.toDoubleOrNull() ?: s.moistureMax,
                        tempMin = tMin.toDoubleOrNull() ?: s.tempMin, tempMax = tMax.toDoubleOrNull() ?: s.tempMax,
                        luxMin = lux.toDoubleOrNull() ?: s.luxMin,
                        quietStart = qStart.toIntOrNull() ?: s.quietStart, quietEnd = qEnd.toIntOrNull() ?: s.quietEnd,
                    ))
                },
                enabled = name.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.save)) }
            OutlinedButton(
                onClick = { confirmDelete = true },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = AlertRed),
            ) { Text(stringResource(R.string.delete_crop)) }
        }
    }

    if (confirmDelete) AlertDialog(
        onDismissRequest = { confirmDelete = false },
        text = { Text(stringResource(R.string.confirm_delete_crop)) },
        confirmButton = { TextButton(onClick = { confirmDelete = false; vm.deleteCrop() }) { Text(stringResource(R.string.delete)) } },
        dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.cancel)) } },
    )
}

@Composable
private fun NumberField(label: String, value: String, onChange: (String) -> Unit, modifier: Modifier = Modifier) {
    OutlinedTextField(
        value = value, onValueChange = onChange, label = { Text(label, fontSize = 12.sp) }, singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        modifier = modifier.fillMaxWidth(),
    )
}

// ---------------------------------------------------------------------
//  History: line chart of the last 24 hours
// ---------------------------------------------------------------------
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HistoryTab(history: List<HistoryPoint>) {
    val metrics = listOf<Pair<Int, (HistoryPoint) -> Double?>>(
        R.string.soil to { p: HistoryPoint -> p.moisture },
        R.string.temperature to { p: HistoryPoint -> p.temperature },
        R.string.humidity to { p: HistoryPoint -> p.humidity },
        R.string.light to { p: HistoryPoint -> p.lux },
    )
    var selected by rememberSaveable { mutableIntStateOf(0) }
    val pick = metrics[selected].second
    val points = history.filter { pick(it) != null }
    val values = points.map { pick(it)!! }

    Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.history_title), style = MaterialTheme.typography.titleMedium)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            metrics.take(2).forEachIndexed { i, (label, _) ->
                FilterChip(selected = selected == i, onClick = { selected = i }, label = { Text(stringResource(label)) })
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            metrics.drop(2).forEachIndexed { j, (label, _) ->
                val i = j + 2
                FilterChip(selected = selected == i, onClick = { selected = i }, label = { Text(stringResource(label)) })
            }
        }
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                LineChart(values)
                Spacer(Modifier.height(8.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(formatTime(points.firstOrNull()?.ts ?: 0, "HH:mm"), style = MaterialTheme.typography.bodySmall)
                    Text(formatTime(points.lastOrNull()?.ts ?: 0, "HH:mm"), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        if (values.isNotEmpty()) {
            Card(Modifier.fillMaxWidth()) {
                Row(Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(stringResource(R.string.min) + ": " + values.min().show(1))
                    Text(stringResource(R.string.avg) + ": " + values.average().show(1))
                    Text(stringResource(R.string.max) + ": " + values.max().show(1))
                }
            }
        }
    }
}

// ---------------------------------------------------------------------
//  Diary: list of mood changes of the crop
// ---------------------------------------------------------------------
@Composable
private fun DiaryTab(events: List<PlantEvent>) {
    if (events.isEmpty()) {
        Text(stringResource(R.string.no_events), Modifier.padding(16.dp))
        return
    }
    LazyColumn(Modifier.padding(horizontal = 16.dp)) {
        items(events) { e ->
            val ui = moodUi(e.mood)
            Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(ui.emoji, fontSize = 32.sp)
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(stringResource(ui.message))
                    Text(formatTime(e.ts), style = MaterialTheme.typography.bodySmall)
                }
            }
            HorizontalDivider()
        }
    }
}
