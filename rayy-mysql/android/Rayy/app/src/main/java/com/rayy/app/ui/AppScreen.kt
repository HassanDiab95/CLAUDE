package com.rayy.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rayy.app.Crop
import com.rayy.app.CropType
import com.rayy.app.R
import com.rayy.app.RayyViewModel
import com.rayy.app.User

/**
 * The app after signing in. The name is always "ري" (Rayy); inside it the user
 * manages many crops. Bottom tabs: My crops · Devices · Users (admin only).
 * Tapping a crop opens its page (CropScreen). Messages appear as snackbars.
 */
@Composable
fun AppScreen(vm: RayyViewModel, user: User) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    val openCrop by vm.openCrop.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()
    val info by vm.info.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val doneText = stringResource(R.string.saved)

    BackHandler(enabled = openCrop != null) { vm.closeCrop() }
    LaunchedEffect(error) { error?.let { snackbar.showSnackbar("⚠️ $it"); vm.clearMessages() } }
    LaunchedEffect(info) { info?.let { snackbar.showSnackbar(doneText); vm.clearMessages() } }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        bottomBar = {
            if (openCrop == null) NavigationBar(containerColor = MaterialTheme.colorScheme.surface, tonalElevation = 0.dp) {
                val items = buildList {
                    add("🌾" to R.string.nav_crops)
                    add("📡" to R.string.nav_devices)
                    if (user.isAdmin) add("👥" to R.string.nav_users)
                }
                items.forEachIndexed { i, (icon, label) ->
                    NavigationBarItem(
                        selected = tab == i,
                        onClick = { tab = i },
                        icon = { Text(icon, fontSize = 22.sp) },
                        label = { Text(stringResource(label), fontWeight = if (tab == i) FontWeight.Bold else FontWeight.Normal) },
                        colors = NavigationBarItemDefaults.colors(indicatorColor = MaterialTheme.colorScheme.primaryContainer),
                    )
                }
            }
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Box(Modifier.padding(bottom = padding.calculateBottomPadding()).fillMaxSize()) {
            AnimatedContent(
                targetState = openCrop ?: -tab - 1,
                transitionSpec = { fadeIn() togetherWith fadeOut() },
                label = "screen",
            ) { target ->
                when {
                    target >= 0 -> CropScreen(vm)
                    target == -1 -> CropsScreen(vm, user)
                    target == -2 -> DevicesScreen(vm)
                    else -> UsersScreen(vm, user)
                }
            }
        }
    }
}

// ---------------------------------------------------------------------
//  My crops
// ---------------------------------------------------------------------
@Composable
fun CropsScreen(vm: RayyViewModel, user: User) {
    val crops by vm.crops.collectAsStateWithLifecycle()
    val types by vm.types.collectAsStateWithLifecycle()
    CropsContent(user, crops, types, onOpen = vm::openCrop, onAdd = vm::addCrop, onSignOut = vm::signOut)
}

@Composable
fun CropsContent(
    user: User,
    crops: List<Crop>,
    types: List<CropType>,
    onOpen: (Int) -> Unit,
    onAdd: (String, String, String) -> Unit,
    onSignOut: () -> Unit,
    now: Long = System.currentTimeMillis(),
) {
    var adding by remember { mutableStateOf(false) }
    val online = crops.count { it.live?.isOnline(now) == true }
    val attention = crops.count { it.live?.isOnline(now) == true && moodUi(it.live.mood).alert }

    Box(Modifier.fillMaxSize()) {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = ListEndPadding, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            item {
                GradientHeader {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("🌱 " + stringResource(R.string.app_name), color = Color.White.copy(alpha = 0.85f),
                                fontWeight = FontWeight.Bold)
                            Text(stringResource(R.string.hello_name, user.fullName.substringBefore(' ')), color = Color.White,
                                style = MaterialTheme.typography.headlineSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                        if (user.isAdmin) Pill(stringResource(R.string.role_admin), Color.White)
                        IconButton(onClick = onSignOut) {
                            Icon(Icons.AutoMirrored.Filled.ExitToApp, stringResource(R.string.sign_out), tint = Color.White)
                        }
                    }
                    Text(stringResource(R.string.crops_hint_short), color = Color.White.copy(alpha = 0.85f),
                        style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 2.dp, bottom = 14.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        GlassTile("🌾", crops.size.toString(), stringResource(R.string.stat_crops), Modifier.weight(1f))
                        GlassTile("⚠️", attention.toString(), stringResource(R.string.stat_attention), Modifier.weight(1f))
                        GlassTile("📡", online.toString(), stringResource(R.string.stat_online), Modifier.weight(1f))
                    }
                }
            }
            if (crops.isEmpty()) item {
                EmptyState("🌾", stringResource(R.string.no_crops), stringResource(R.string.no_crops_hint))
            }
            items(crops, key = { it.cropId }) { c ->
                CropCard(c, user.isAdmin, now, Modifier.padding(horizontal = 16.dp)) { onOpen(c.cropId) }
            }
        }
        ExtendedFloatingActionButton(
            onClick = { adding = true },
            icon = { Icon(Icons.Filled.Add, null) },
            text = { Text(stringResource(R.string.add_crop_short), fontWeight = FontWeight.Bold) },
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary,
            modifier = Modifier.align(Alignment.BottomEnd).navigationBarsPadding().padding(20.dp),
        )
    }

    if (adding) AddCropSheet(types, onDismiss = { adding = false }) { name, type, location ->
        adding = false
        onAdd(name, type, location)
    }
}

@Composable
fun CropCard(c: Crop, showOwner: Boolean, now: Long, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val live = c.live
    val online = live?.isOnline(now) == true
    val mood = if (online) live!!.mood else "unknown"
    val ui = moodUi(mood)
    val colors = moodColors(mood)
    val container by animateColorAsState(if (online) colors.soft() else MaterialTheme.colorScheme.surface, label = "card")

    Card(
        modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = MaterialTheme.shapes.extraLarge,
        colors = CardDefaults.cardColors(containerColor = container),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                EmojiBadge(if (online) ui.emoji else c.typeEmoji, MaterialTheme.colorScheme.surface.copy(alpha = if (online) 0.85f else 1f), size = 64.dp, fontSize = 36)
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(c.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold,
                        maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("${c.typeEmoji} ${c.typeName}", style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (c.location.isNotEmpty()) {
                            Spacer(Modifier.width(8.dp))
                            Icon(Icons.Filled.LocationOn, null, Modifier.padding(end = 2.dp).width(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(c.location, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                    Text(
                        when {
                            online -> stringResource(ui.title)
                            live != null -> stringResource(R.string.offline)
                            else -> stringResource(R.string.no_data)
                        },
                        color = if (online) colors.strong else MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.Bold,
                    )
                }
                OnlinePill(online, stringResource(R.string.online), stringResource(R.string.offline))
            }
            if (live != null) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MiniStat("💧", live.moisture.show() + "%", Modifier.weight(1f))
                MiniStat("🌡️", live.temperature.show(1) + "°", Modifier.weight(1f))
                MiniStat("☀️", live.lux.show(), Modifier.weight(1f))
            }
            Text(
                "📡 " + (c.device?.name ?: stringResource(R.string.no_device)) + if (showOwner) "   ·   👤 ${c.ownerName}" else "",
                style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun MiniStat(emoji: String, value: String, modifier: Modifier = Modifier) {
    Row(
        modifier.clip(MaterialTheme.shapes.small).background(MaterialTheme.colorScheme.surface.copy(alpha = 0.7f)).padding(vertical = 8.dp, horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center,
    ) {
        Text(emoji, fontSize = 14.sp)
        Spacer(Modifier.width(4.dp))
        Text(value, fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface, maxLines = 1)
    }
}

/** Bottom sheet to add a crop: name, crop type (tiles), location; shows the ideal values */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddCropSheet(types: List<CropType>, onDismiss: () -> Unit, onSave: (String, String, String) -> Unit) {
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = MaterialTheme.colorScheme.surface) {
        AddCropForm(types, onSave)
    }
}

@Composable
fun AddCropForm(types: List<CropType>, onSave: (String, String, String) -> Unit) {
    var name by remember { mutableStateOf("") }
    var location by remember { mutableStateOf("") }
    var type by remember { mutableStateOf(types.firstOrNull()) }
    LaunchedEffect(types) { if (type == null) type = types.firstOrNull() }

    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(stringResource(R.string.new_crop), style = MaterialTheme.typography.headlineSmall)
        Field(stringResource(R.string.crop_name), name, { name = it })
        Text(stringResource(R.string.crop_type), style = MaterialTheme.typography.labelLarge)
        types.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { t -> TypeTile(t, t == type, Modifier.weight(1f)) { type = t } }
                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        type?.let {
            Row(
                Modifier.fillMaxWidth().clip(MaterialTheme.shapes.medium).background(MaterialTheme.colorScheme.primaryContainer).padding(12.dp),
                horizontalArrangement = Arrangement.SpaceAround,
            ) {
                IdealValue("💧", ltr("${it.moistureMin.clean()}–${it.moistureMax.clean()}%"))
                IdealValue("🌡️", ltr("${it.tempMin.clean()}–${it.tempMax.clean()}°C"))
                IdealValue("☀️", "≥ ${it.luxMin.clean()}")
            }
            Text(stringResource(R.string.ideal_values_hint), style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Field(stringResource(R.string.location), location, { location = it }, icon = Icons.Filled.LocationOn)
        Button(
            onClick = { type?.let { onSave(name, it.code, location) } },
            enabled = name.isNotBlank() && type != null,
            modifier = Modifier.fillMaxWidth().height(52.dp), shape = MaterialTheme.shapes.medium,
        ) { Text(stringResource(R.string.save), fontSize = 16.sp) }
    }
}

@Composable
private fun TypeTile(t: CropType, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(
        modifier
            .clip(MaterialTheme.shapes.medium)
            .background(if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant)
            .border(2.dp, if (selected) MaterialTheme.colorScheme.primary else Color.Transparent, MaterialTheme.shapes.medium)
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(t.emoji, fontSize = 26.sp)
        Text(t.name, style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
    }
}

@Composable
private fun IdealValue(emoji: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(emoji, fontSize = 18.sp)
        Text(value, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer)
    }
}
