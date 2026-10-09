package com.rayy.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
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
 * Tapping a crop opens its detail page (CropScreen).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppScreen(vm: RayyViewModel, user: User) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    val openCrop by vm.openCrop.collectAsStateWithLifecycle()
    val settings by vm.settings.collectAsStateWithLifecycle()

    BackHandler(enabled = openCrop != null) { vm.closeCrop() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(if (openCrop != null) settings.name.ifEmpty { "…" } else "🌱 " + stringResource(R.string.app_name))
                },
                navigationIcon = {
                    if (openCrop != null) TextButton(onClick = vm::closeCrop) {
                        Text(stringResource(R.string.back), color = MaterialTheme.colorScheme.onPrimary)
                    }
                },
                actions = {
                    if (openCrop == null) Text(
                        user.fullName + if (user.isAdmin) " · " + stringResource(R.string.role_admin) else "",
                        fontSize = 13.sp,
                    )
                    TextButton(onClick = vm::signOut) {
                        Text(stringResource(R.string.sign_out), color = MaterialTheme.colorScheme.onPrimary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                    actionIconContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        },
        bottomBar = {
            if (openCrop == null) NavigationBar {
                val items = buildList {
                    add("🌾" to R.string.nav_crops)
                    add("📡" to R.string.nav_devices)
                    if (user.isAdmin) add("👥" to R.string.nav_users)
                }
                items.forEachIndexed { i, (icon, label) ->
                    NavigationBarItem(
                        selected = tab == i,
                        onClick = { tab = i; vm.clearMessages() },
                        icon = { Text(icon, fontSize = 20.sp) },
                        label = { Text(stringResource(label)) },
                    )
                }
            }
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            when {
                openCrop != null -> CropScreen(vm)
                tab == 0 -> CropsScreen(vm, user)
                tab == 1 -> DevicesScreen(vm)
                else -> UsersScreen(vm, user)
            }
        }
    }
}

// ---------------------------------------------------------------------
//  My crops: one card per crop with the emoji of its current feeling
// ---------------------------------------------------------------------
@Composable
fun CropsScreen(vm: RayyViewModel, user: User) {
    val crops by vm.crops.collectAsStateWithLifecycle()
    val types by vm.types.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()
    var adding by remember { mutableStateOf(false) }

    Scaffold(
        floatingActionButton = {
            ExtendedFloatingActionButton(onClick = { adding = true }) { Text(stringResource(R.string.add_crop)) }
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        LazyColumn(
            Modifier.padding(padding).fillMaxSize().padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Spacer(Modifier.padding(top = 4.dp))
                Text(stringResource(R.string.crops_hint), style = MaterialTheme.typography.bodySmall)
                error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            }
            if (crops.isEmpty()) item {
                Text("🌾  " + stringResource(R.string.no_crops), Modifier.padding(vertical = 32.dp))
            }
            items(crops, key = { it.cropId }) { c -> CropCard(c, user.isAdmin) { vm.openCrop(c.cropId) } }
            item { Spacer(Modifier.padding(bottom = 80.dp)) }
        }
    }

    if (adding) AddCropDialog(types, onDismiss = { adding = false }) { name, type, location ->
        adding = false
        vm.addCrop(name, type, location)
    }
}

@Composable
private fun CropCard(c: Crop, showOwner: Boolean, onClick: () -> Unit) {
    val live = c.live
    val online = live?.isOnline() == true
    val ui = moodUi(if (online) live!!.mood else "unknown")
    Card(
        Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = if (online && ui.alert) Color(0xFFFFF3E0) else MaterialTheme.colorScheme.surface),
    ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(c.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text("${c.typeEmoji} ${c.typeName}" + if (c.location.isNotEmpty()) " · ${c.location}" else "",
                    style = MaterialTheme.typography.bodySmall)
                Text(
                    when {
                        online -> stringResource(ui.title)
                        live != null -> stringResource(R.string.offline)
                        else -> stringResource(R.string.no_data)
                    },
                    fontWeight = FontWeight.Bold,
                )
                if (live != null) Text("💧 ${live.moisture.show()}%   🌡️ ${live.temperature.show(1)}°C   ☀️ ${live.lux.show()} lux",
                    style = MaterialTheme.typography.bodySmall)
                Text("📡 " + (c.device?.name ?: stringResource(R.string.no_device)) + if (showOwner) "  ·  👤 ${c.ownerName}" else "",
                    style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.width(12.dp))
            Text(if (online) ui.emoji else c.typeEmoji, fontSize = 48.sp)
        }
    }
}

/** Form to add a crop: name, type (fills the ideal values) and location */
@Composable
private fun AddCropDialog(types: List<CropType>, onDismiss: () -> Unit, onSave: (String, String, String) -> Unit) {
    var name by remember { mutableStateOf("") }
    var location by remember { mutableStateOf("") }
    var type by remember { mutableStateOf(types.firstOrNull()) }
    LaunchedEffect(types) { if (type == null) type = types.firstOrNull() }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.new_crop)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Field(stringResource(R.string.crop_name), name, { name = it })
                Picker(stringResource(R.string.crop_type), types, type, { "${it.emoji} ${it.name}" }, { type = it })
                type?.let {
                    Text(stringResource(R.string.ideal_values) +
                        ": 💧 ${it.moistureMin.clean()}–${it.moistureMax.clean()}%  🌡️ ${it.tempMin.clean()}–${it.tempMax.clean()}°C  ☀️ ≥ ${it.luxMin.clean()} lux",
                        style = MaterialTheme.typography.bodySmall)
                }
                Field(stringResource(R.string.location), location, { location = it })
            }
        },
        confirmButton = {
            TextButton(onClick = { type?.let { onSave(name, it.code, location) } }, enabled = name.isNotBlank() && type != null) {
                Text(stringResource(R.string.save))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}
