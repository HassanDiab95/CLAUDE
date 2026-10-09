<?php
// =====================================================================
//  GET  api/crops.php            → my crops (an admin sees all crops), each with
//                                  its type, its latest values and its device
//  POST api/crops.php            {"name":"Strawberry field","type_code":"strawberry","location":"Greenhouse 1"}
//                                → creates a crop with the ideal values of its type
// =====================================================================
require_once __DIR__ . '/lib.php';
$user = require_user();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $d = body();
    $name = trim((string)($d['name'] ?? ''));
    $location = trim((string)($d['location'] ?? ''));
    $type = (string)($d['type_code'] ?? '');
    if ($name === '' || mb_strlen($name) > 60) fail(400, 'Crop name is required (max 60 characters)');
    if (mb_strlen($location) > 100) fail(400, 'Location is too long (max 100 characters)');

    // The thresholds start from the crop type
    $st = db()->prepare('INSERT INTO crops (owner_id, type_code, name, location, moisture_min, moisture_max, temp_min, temp_max, lux_min)
                         SELECT ?, type_code, ?, ?, moisture_min, moisture_max, temp_min, temp_max, lux_min
                         FROM crop_types WHERE type_code = ?');
    $st->execute([$user['user_id'], $name, $location === '' ? null : $location, $type]);
    if ($st->rowCount() === 0) fail(400, 'Unknown crop type');
    respond(['ok' => true, 'crop_id' => (int)db()->lastInsertId()]);
}

require_method('GET');
$where = is_admin($user) ? '' : 'WHERE c.owner_id = ' . $user['user_id'];
$rows = db()->query("SELECT c.*, t.name_ar AS type_ar, t.name_en AS type_en, t.emoji AS type_emoji,
                            u.full_name AS owner_name,
                            l.device_id AS live_device, l.moisture, l.temperature, l.humidity, l.lux, l.rssi, l.mood_code,
                            UNIX_TIMESTAMP(l.updated_at) * 1000 AS ts,
                            d.device_id AS device_id, d.name AS device_name
                     FROM crops c
                     JOIN crop_types t ON t.type_code = c.type_code
                     JOIN users u ON u.user_id = c.owner_id
                     LEFT JOIN live_status l ON l.crop_id = c.crop_id
                     LEFT JOIN devices d ON d.crop_id = c.crop_id
                     $where
                     ORDER BY c.crop_id")->fetchAll();

$crops = array_map(fn($r) => [
    'crop_id'    => (int)$r['crop_id'],
    'name'       => $r['name'],
    'location'   => $r['location'],
    'type_code'  => $r['type_code'],
    'type_ar'    => $r['type_ar'],
    'type_en'    => $r['type_en'],
    'type_emoji' => $r['type_emoji'],
    'owner_id'   => (int)$r['owner_id'],
    'owner_name' => $r['owner_name'],
    'device'     => $r['device_id'] ? ['device_id' => $r['device_id'], 'name' => $r['device_name']] : null,
    'live'       => live_json($r['mood_code'] ? array_merge($r, ['device_id' => $r['live_device']]) : null),
    'config'     => settings_json($r),
], $rows);

respond(['ok' => true, 'crops' => $crops]);
