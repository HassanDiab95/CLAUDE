package com.rayy.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rayy.app.HistoryPoint
import com.rayy.app.PlantLive
import com.rayy.app.PlantViewModel
import com.rayy.app.R
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(vm: PlantViewModel) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    val live by vm.live.collectAsStateWithLifecycle()
    val history by vm.history.collectAsStateWithLifecycle()
    val events by vm.events.collectAsStateWithLifecycle()
    val settings by vm.settings.collectAsStateWithLifecycle()

    // Refresh the "online" badge every 15 s
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) { delay(15_000); now = System.currentTimeMillis() }
    }
    // Power-saving mode uploads every 2 min, so allow 5 min before "offline"
    val online = live != null && now - live!!.ts < (if (live!!.saving) 300_000 else 120_000)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("🌱 " + settings.name.ifEmpty { stringResource(R.string.app_name) }) },
                actions = {
                    Text(
                        if (online) "● " + stringResource(R.string.online) else "● " + stringResource(R.string.offline),
                        color = if (online) Color(0xFF9FF0B9) else Color(0xFFFFB3A8),
                        fontSize = 13.sp,
                    )
                    TextButton(onClick = vm::signOut) {
                        Text(stringResource(R.string.sign_out), color = MaterialTheme.colorScheme.onPrimary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        },
        bottomBar = {
            NavigationBar {
                val items = listOf("🏠" to R.string.tab_home, "📈" to R.string.tab_history, "📔" to R.string.tab_diary)
                items.forEachIndexed { i, (icon, label) ->
                    NavigationBarItem(
                        selected = tab == i,
                        onClick = { tab = i },
                        icon = { Text(icon, fontSize = 20.sp) },
                        label = { Text(stringResource(label)) },
                    )
                }
            }
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            when (tab) {
                0 -> HomeTab(live, settings.muted, settings.moistureMin, vm)
                1 -> HistoryTab(history)
                else -> DiaryTab(events)
            }
        }
    }
}

// ---------------------------------------------------------------------
//  Home: big emoji + live values
// ---------------------------------------------------------------------
@Composable
private fun HomeTab(live: PlantLive?, muted: Boolean, moistureMin: Double, vm: PlantViewModel) {
    val ui = moodUi(live?.mood ?: "unknown")
    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
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
                Column {
                    Text(stringResource(ui.title), style = MaterialTheme.typography.headlineSmall,
                        color = if (ui.alert) Color(0xFF6B3D00) else Color.Unspecified)
                    Text(stringResource(ui.message),
                        color = if (ui.alert) Color(0xFF6B3D00) else Color.Unspecified)
                    Text(
                        stringResource(R.string.last_update) + ": " + formatTime(live?.ts ?: 0),
                        style = MaterialTheme.typography.bodySmall,
                        color = if (ui.alert) Color(0xFF6B3D00) else Color.Unspecified,
                    )
                }
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Metric("💧", stringResource(R.string.soil), live?.moisture.show(), "%", Modifier.weight(1f),
                progress = live?.moisture?.div(100),
                progressColor = if ((live?.moisture ?: 100.0) < moistureMin) AlertRed else null)
            Metric("🌡️", stringResource(R.string.temperature), live?.temperature.show(1), "°C", Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Metric("💨", stringResource(R.string.humidity), live?.humidity.show(), "%", Modifier.weight(1f))
            Metric("☀️", stringResource(R.string.light), live?.lux.show(), "lux", Modifier.weight(1f))
        }
        Metric("📶", stringResource(R.string.wifi), live?.rssi.show(), "dBm", Modifier.fillMaxWidth(),
            note = live?.rssi?.let {
                stringResource(if (it > -60) R.string.signal_good else if (it > -75) R.string.signal_ok else R.string.signal_bad)
            })

        // Solar part: shown only when the plant sends battery data
        val power = live
        val pct = power?.batteryPct
        if (power != null && pct != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Metric(if (power.charging) "⚡" else if (pct < 20) "🪫" else "🔋", stringResource(R.string.battery),
                    pct.show(), "%", Modifier.weight(1f),
                    progress = pct / 100, progressColor = if (pct < 20) AlertRed else null,
                    note = power.batteryV.show(2) + " V · " +
                        stringResource(if (power.saving) R.string.power_saving else R.string.power_normal))
                Metric("🔆", stringResource(R.string.solar), power.solarV.show(1), "V", Modifier.weight(1f),
                    note = stringResource(if (power.charging) R.string.charging else R.string.not_charging))
            }
        }

        SpeakCard(muted, vm)
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

@Composable
private fun SpeakCard(muted: Boolean, vm: PlantViewModel) {
    var menu by remember { mutableStateOf(false) }
    var track by rememberSaveable { mutableIntStateOf(1) }
    var sent by remember { mutableStateOf(false) }
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(stringResource(R.string.speak_title), style = MaterialTheme.typography.titleMedium)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    OutlinedButton(onClick = { menu = true }, modifier = Modifier.fillMaxWidth()) {
                        Text("$track. " + stringResource(TRACK_NAMES[track - 1]))
                    }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        TRACK_NAMES.forEachIndexed { i, res ->
                            DropdownMenuItem(
                                text = { Text("${i + 1}. " + stringResource(res)) },
                                onClick = { track = i + 1; menu = false },
                            )
                        }
                    }
                }
                Spacer(Modifier.width(8.dp))
                Button(onClick = { vm.playSound(track); sent = true }) { Text(stringResource(R.string.speak_now)) }
            }
            if (sent) Text(stringResource(R.string.speak_sent), style = MaterialTheme.typography.bodySmall)
            HorizontalDivider()
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.mute), Modifier.weight(1f))
                Switch(checked = muted, onCheckedChange = vm::setMuted)
            }
        }
    }
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
        R.string.battery to { p: HistoryPoint -> p.batteryPct },
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
//  Diary: list of mood changes
// ---------------------------------------------------------------------
@Composable
private fun DiaryTab(events: List<com.rayy.app.PlantEvent>) {
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
