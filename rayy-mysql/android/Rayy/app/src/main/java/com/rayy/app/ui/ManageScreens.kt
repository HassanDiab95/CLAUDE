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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rayy.app.AdminUser
import com.rayy.app.Crop
import com.rayy.app.DeviceInfo
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
    val error by vm.error.collectAsStateWithLifecycle()
    val info by vm.info.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { vm.loadDevices() }

    var id by remember { mutableStateOf("") }
    var key by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(4.dp))
            Text(stringResource(R.string.devices_hint), style = MaterialTheme.typography.bodySmall)
        }
        if (devices.isEmpty()) item { Text("📡  " + stringResource(R.string.no_devices_yet), Modifier.padding(vertical = 16.dp)) }
        items(devices, key = { it.deviceId }) { d -> DeviceRow(d, crops, onMove = { c -> vm.assignDevice(d.deviceId, c?.cropId) }) }
        item {
            Section(stringResource(R.string.add_device)) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(stringResource(R.string.add_device_hint), style = MaterialTheme.typography.bodySmall)
                    Field(stringResource(R.string.device_id), id, { id = it })
                    Field(stringResource(R.string.device_key), key, { key = it }, keyboard = KeyboardType.Password, password = true)
                    Field(stringResource(R.string.device_name), name, { name = it })
                    if (user?.isAdmin == true) Text(stringResource(R.string.admin_device_hint), style = MaterialTheme.typography.bodySmall)
                    Button(
                        onClick = { vm.addDevice(id, key, name); id = ""; key = ""; name = "" },
                        enabled = id.isNotBlank() && key.length >= 8,
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text(stringResource(R.string.add)) }
                }
            }
        }
        item {
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            info?.let { Text(stringResource(R.string.done) + " " + it, color = MaterialTheme.colorScheme.primary) }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun DeviceRow(d: DeviceInfo, crops: List<Crop>, onMove: (Crop?) -> Unit) {
    var chosen by remember(d) { mutableStateOf<Crop?>(null) }
    Section("📡 ${d.name}  (${d.deviceId})") {
        Text(
            if (d.cropId != null) stringResource(R.string.measures) + " ${d.cropEmoji} ${d.cropName}"
            else stringResource(R.string.not_assigned),
        )
        Text(
            stringResource(R.string.last_seen) + " " +
                (if (d.lastSeen > 0) formatTime(d.lastSeen) else stringResource(R.string.never)) +
                if (d.ownerName.isNotEmpty()) "  ·  👤 ${d.ownerName}" else "",
            style = MaterialTheme.typography.bodySmall,
        )
        Spacer(Modifier.height(8.dp))
        Picker("", crops, chosen, { "${it.typeEmoji} ${it.name}" }, { chosen = it }, placeholder = stringResource(R.string.move_to))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { onMove(chosen) }, enabled = chosen != null, modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.move))
            }
            if (d.cropId != null) OutlinedButton(onClick = { onMove(null) }, modifier = Modifier.weight(1f)) {
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
    val error by vm.error.collectAsStateWithLifecycle()
    val info by vm.info.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { vm.loadUsers() }

    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var role by remember { mutableStateOf("user") }
    var toDelete by remember { mutableStateOf<AdminUser?>(null) }
    val roles = listOf("user", "admin")
    val roleNames = mapOf("user" to stringResource(R.string.role_user), "admin" to stringResource(R.string.role_admin))

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(4.dp))
            Section(stringResource(R.string.new_user)) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Field(stringResource(R.string.full_name), name, { name = it })
                    Field(stringResource(R.string.email), email, { email = it }, keyboard = KeyboardType.Email)
                    Field(stringResource(R.string.password), password, { password = it }, keyboard = KeyboardType.Password, password = true)
                    Picker(stringResource(R.string.role), roles, role, { roleNames.getValue(it) }, { role = it })
                    Button(
                        onClick = { vm.createUser(name, email, password, role); name = ""; email = ""; password = "" },
                        enabled = name.isNotBlank() && email.isNotBlank() && password.length >= 8,
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text(stringResource(R.string.create_account)) }
                }
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            info?.let { Text(stringResource(R.string.done) + " " + it, color = MaterialTheme.colorScheme.primary) }
        }
        items(users, key = { it.userId }) { u ->
            val isMe = u.userId == me.userId
            Section(u.fullName + if (isMe) " " + stringResource(R.string.you) else "") {
                Text(u.email, style = MaterialTheme.typography.bodySmall)
                Text("🌾 ${u.crops}   📡 ${u.devices}", style = MaterialTheme.typography.bodySmall)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (isMe) Text(roleNames.getValue(u.role), fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    else Picker("", roles, u.role, { roleNames.getValue(it) }, { r -> vm.setRole(u.userId, r) }, Modifier.weight(1f))
                    if (!isMe) {
                        Spacer(Modifier.width(8.dp))
                        TextButton(onClick = { toDelete = u }) { Text(stringResource(R.string.delete), color = AlertRed) }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }

    toDelete?.let { u ->
        AlertDialog(
            onDismissRequest = { toDelete = null },
            text = { Text(stringResource(R.string.confirm_delete_user) + "\n" + u.fullName) },
            confirmButton = { TextButton(onClick = { vm.deleteUser(u.userId); toDelete = null }) { Text(stringResource(R.string.delete)) } },
            dismissButton = { TextButton(onClick = { toDelete = null }) { Text(stringResource(R.string.cancel)) } },
        )
    }
}
