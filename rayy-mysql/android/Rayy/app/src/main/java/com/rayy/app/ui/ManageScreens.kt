package com.rayy.app.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rayy.app.AdminUser
import com.rayy.app.Crop
import com.rayy.app.DeviceInfo
import com.rayy.app.ONLINE_MS
import com.rayy.app.R
import com.rayy.app.RayyViewModel
import com.rayy.app.User

// ---------------------------------------------------------------------
//  Devices: the sensor units (ESP32). Move a device from one crop to
//  another, or add a device with its DEVICE_ID + DEVICE_KEY.
// ---------------------------------------------------------------------
@Composable
fun DevicesScreen(vm: RayyViewModel) {
    val devices by vm.devices.collectAsStateWithLifecycle()
    val crops by vm.crops.collectAsStateWithLifecycle()
    val user by vm.user.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { vm.loadDevices() }
    DevicesContent(devices, crops, user?.isAdmin == true, onMove = vm::assignDevice, onAdd = vm::addDevice)
}

@Composable
fun DevicesContent(
    devices: List<DeviceInfo>,
    crops: List<Crop>,
    isAdmin: Boolean,
    onMove: (String, Int?) -> Unit,
    onAdd: (String, String, String) -> Unit,
    now: Long = System.currentTimeMillis(),
) {
    var id by remember { mutableStateOf("") }
    var key by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }

    LazyColumn(Modifier.fillMaxSize(), contentPadding = ListEndPadding, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            GradientHeader {
                Text("📡 " + stringResource(R.string.nav_devices), color = Color.White, style = MaterialTheme.typography.headlineSmall)
                Text(stringResource(R.string.devices_hint), color = Color.White.copy(alpha = 0.88f), style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = 4.dp))
            }
        }
        if (devices.isEmpty()) item { EmptyState("📡", stringResource(R.string.no_devices_yet)) }
        items(devices, key = { it.deviceId }) { d ->
            DeviceRow(d, crops, now, Modifier.padding(horizontal = 16.dp)) { c -> onMove(d.deviceId, c?.cropId) }
        }
        item {
            SectionCard(stringResource(R.string.add_device), "➕", Modifier.padding(horizontal = 16.dp)) {
                Text(stringResource(R.string.add_device_hint), style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                Field(stringResource(R.string.device_id), id, { id = it })
                Field(stringResource(R.string.device_key), key, { key = it }, keyboard = KeyboardType.Password, password = true, icon = Icons.Filled.Lock)
                Field(stringResource(R.string.device_name), name, { name = it })
                if (isAdmin) Text("👑 " + stringResource(R.string.admin_device_hint), style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                Button(
                    onClick = { onAdd(id, key, name); id = ""; key = ""; name = "" },
                    enabled = id.isNotBlank() && key.length >= 8,
                    modifier = Modifier.fillMaxWidth().height(50.dp), shape = MaterialTheme.shapes.medium,
                ) {
                    Icon(Icons.Filled.Add, null)
                    Spacer(Modifier.width(6.dp))
                    Text(stringResource(R.string.add))
                }
            }
        }
    }
}

@Composable
private fun DeviceRow(d: DeviceInfo, crops: List<Crop>, now: Long, modifier: Modifier = Modifier, onMove: (Crop?) -> Unit) {
    var chosen by remember(d) { mutableStateOf<Crop?>(null) }
    val online = d.lastSeen > 0 && now - d.lastSeen < ONLINE_MS
    SectionCard(modifier = modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            EmojiBadge("📡", MaterialTheme.colorScheme.primaryContainer, size = 52.dp, fontSize = 26)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(d.name, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(d.deviceId, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            OnlinePill(online, stringResource(R.string.online), stringResource(R.string.offline))
        }
        Row(
            Modifier.fillMaxWidth().clip(MaterialTheme.shapes.medium).background(MaterialTheme.colorScheme.surfaceVariant).padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(if (d.cropId != null) d.cropEmoji else "➖", fontSize = 22.sp)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(if (d.cropId != null) R.string.measures else R.string.not_assigned),
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (d.cropId != null) Text(d.cropName, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Text(
            "🕒 " + stringResource(R.string.last_seen) + " " + (if (d.lastSeen > 0) formatTime(d.lastSeen) else stringResource(R.string.never)) +
                if (d.ownerName.isNotEmpty()) "   ·   👤 ${d.ownerName}" else "",
            style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Picker("", crops, chosen, { "${it.typeEmoji} ${it.name}" }, { chosen = it }, placeholder = "⇄  " + stringResource(R.string.move_to))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { onMove(chosen) }, enabled = chosen != null, modifier = Modifier.weight(1f), shape = MaterialTheme.shapes.medium) {
                Text(stringResource(R.string.move))
            }
            if (d.cropId != null) OutlinedButton(onClick = { onMove(null) }, modifier = Modifier.weight(1f), shape = MaterialTheme.shapes.medium) {
                Text(stringResource(R.string.unassign))
            }
        }
    }
}

// ---------------------------------------------------------------------
//  Users (admin only): create users, make a user admin, delete users
// ---------------------------------------------------------------------
@Composable
fun UsersScreen(vm: RayyViewModel, me: User) {
    val users by vm.users.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { vm.loadUsers() }
    UsersContent(users, me, onCreate = vm::createUser, onRole = vm::setRole, onDelete = vm::deleteUser)
}

@Composable
fun UsersContent(
    users: List<AdminUser>,
    me: User,
    onCreate: (String, String, String, String) -> Unit,
    onRole: (Int, String) -> Unit,
    onDelete: (Int) -> Unit,
) {
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var role by remember { mutableStateOf("user") }
    var toDelete by remember { mutableStateOf<AdminUser?>(null) }
    var showForm by remember { mutableStateOf(false) }
    val roles = listOf("user", "admin")
    val roleNames = mapOf("user" to stringResource(R.string.role_user), "admin" to stringResource(R.string.role_admin))

    LazyColumn(Modifier.fillMaxSize(), contentPadding = ListEndPadding, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            GradientHeader {
                Text("👥 " + stringResource(R.string.nav_users), color = Color.White, style = MaterialTheme.typography.headlineSmall)
                Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    GlassTile("👤", users.size.toString(), stringResource(R.string.stat_users), Modifier.weight(1f))
                    GlassTile("👑", users.count { it.role == "admin" }.toString(), stringResource(R.string.stat_admins), Modifier.weight(1f))
                    GlassTile("🌾", users.sumOf { it.crops }.toString(), stringResource(R.string.stat_crops), Modifier.weight(1f))
                }
            }
        }
        item {
            // the form opens only when needed, so the list of users stays on the first screen
            AnimatedContent(showForm, Modifier.padding(horizontal = 16.dp), label = "newUser") { open ->
                if (!open) FilledTonalButton(
                    onClick = { showForm = true }, modifier = Modifier.fillMaxWidth().height(52.dp), shape = MaterialTheme.shapes.medium,
                ) {
                    Icon(Icons.Filled.Add, null)
                    Spacer(Modifier.width(6.dp))
                    Text(stringResource(R.string.new_user))
                } else SectionCard(stringResource(R.string.new_user), "➕") {
                    Field(stringResource(R.string.full_name), name, { name = it }, icon = Icons.Filled.Person)
                    Field(stringResource(R.string.email), email, { email = it }, keyboard = KeyboardType.Email, icon = Icons.Filled.Email)
                    Field(stringResource(R.string.password), password, { password = it }, keyboard = KeyboardType.Password, password = true, icon = Icons.Filled.Lock)
                    Segmented(roles.map { roleNames.getValue(it) }, roles.indexOf(role), { role = roles[it] })
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { showForm = false }, modifier = Modifier.weight(1f).height(50.dp), shape = MaterialTheme.shapes.medium) {
                            Text(stringResource(R.string.cancel))
                        }
                        Button(
                            onClick = { onCreate(name, email, password, role); name = ""; email = ""; password = ""; showForm = false },
                            enabled = name.isNotBlank() && email.isNotBlank() && password.length >= 8,
                            modifier = Modifier.weight(2f).height(50.dp), shape = MaterialTheme.shapes.medium,
                        ) { Text(stringResource(R.string.create_account)) }
                    }
                }
            }
        }
        items(users, key = { it.userId }) { u ->
            val isMe = u.userId == me.userId
            SectionCard(modifier = Modifier.padding(horizontal = 16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Avatar(u.fullName)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(u.fullName + if (isMe) " " + stringResource(R.string.you) else "", fontWeight = FontWeight.Bold,
                            maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(u.email, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text("🌾 ${u.crops}    📡 ${u.devices}", style = MaterialTheme.typography.labelMedium)
                    }
                    Pill(roleNames.getValue(u.role), if (u.role == "admin") AlertOrange else Leaf500)
                    if (!isMe) IconButton(onClick = { toDelete = u }) { Icon(Icons.Filled.Delete, stringResource(R.string.delete), tint = AlertRed) }
                }
                if (!isMe) Segmented(roles.map { roleNames.getValue(it) }, roles.indexOf(u.role), { onRole(u.userId, roles[it]) })
            }
        }
    }

    toDelete?.let { u ->
        AlertDialog(
            onDismissRequest = { toDelete = null },
            icon = { Text("🗑️", fontSize = 32.sp) },
            text = { Text(stringResource(R.string.confirm_delete_user) + "\n" + u.fullName) },
            confirmButton = { TextButton(onClick = { onDelete(u.userId); toDelete = null }) { Text(stringResource(R.string.delete), color = AlertRed) } },
            dismissButton = { TextButton(onClick = { toDelete = null }) { Text(stringResource(R.string.cancel)) } },
        )
    }
}
