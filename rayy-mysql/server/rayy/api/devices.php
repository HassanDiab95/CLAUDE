<?php
// =====================================================================
//  GET  api/devices.php   → my devices (an admin sees all devices), with the
//                           crop each one measures now and when it was last seen
//  POST api/devices.php   {"device_id":"rayy-01","device_key":"...","name":"Sensor 1"}
//                         → adds a device to my account. The ID and the key are the
//                           DEVICE_ID / DEVICE_KEY written in the ESP32 (config.h).
//                           An admin can also register a NEW device ID this way
//                           (it then waits, without owner, until a user adds it).
// =====================================================================
require_once __DIR__ . '/lib.php';
$user = require_user();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $d = body();
    $id = trim((string)($d['device_id'] ?? ''));
    $key = (string)($d['device_key'] ?? '');
    $name = trim((string)($d['name'] ?? '')) ?: $id;
    if (!preg_match('/^[A-Za-z0-9_-]{1,20}$/', $id)) fail(400, 'Device ID: letters, numbers, - and _ only (max 20)');
    if (strlen($key) < 8) fail(400, 'Device key must be at least 8 characters');
    if (mb_strlen($name) > 50) fail(400, 'Device name is too long (max 50 characters)');

    $st = db()->prepare('SELECT device_key_hash, owner_id FROM devices WHERE device_id = ?');
    $st->execute([$id]);
    $dev = $st->fetch();
    if (!$dev) {
        // A new device ID: only an admin may create it (sets its key). It stays
        // without an owner until a user adds it with the same ID and key.
        if (!is_admin($user)) fail(404, 'Unknown device ID. Ask the admin to register it first');
        db()->prepare('INSERT INTO devices (device_id, name, device_key_hash) VALUES (?, ?, ?)')
            ->execute([$id, $name, hash('sha256', $key)]);
        respond(['ok' => true, 'created' => true]);
    }
    if (!hash_equals($dev['device_key_hash'], hash('sha256', $key))) fail(403, 'Wrong device key');
    if ($dev['owner_id'] !== null && (int)$dev['owner_id'] !== $user['user_id'] && !is_admin($user)) {
        fail(409, 'This device already belongs to another user');
    }
    db()->prepare('UPDATE devices SET owner_id = ?, name = ? WHERE device_id = ?')->execute([$user['user_id'], $name, $id]);
    respond(['ok' => true, 'created' => false]);
}

require_method('GET');
$where = is_admin($user) ? '' : 'WHERE d.owner_id = ' . $user['user_id'];
$rows = db()->query("SELECT d.device_id, d.name, d.crop_id, d.owner_id, UNIX_TIMESTAMP(d.last_seen) * 1000 AS last_seen,
                            c.name AS crop_name, t.emoji AS crop_emoji, u.full_name AS owner_name
                     FROM devices d
                     LEFT JOIN crops c ON c.crop_id = d.crop_id
                     LEFT JOIN crop_types t ON t.type_code = c.type_code
                     LEFT JOIN users u ON u.user_id = d.owner_id
                     $where ORDER BY d.device_id")->fetchAll();

$devices = array_map(fn($r) => [
    'device_id'  => $r['device_id'],
    'name'       => $r['name'],
    'owner_name' => $r['owner_name'],
    'last_seen'  => num($r['last_seen']),
    'crop'       => $r['crop_id'] ? ['crop_id' => (int)$r['crop_id'], 'name' => $r['crop_name'], 'emoji' => $r['crop_emoji']] : null,
], $rows);

respond(['ok' => true, 'devices' => $devices]);
