<?php
// =====================================================================
//  POST api/crop_update.php?crop=1   (header X-Auth-Token)
//  Body: any of {"name","location","type_code","moisture_min","moisture_max",
//                "temp_min","temp_max","lux_min","quiet_start","quiet_end","muted"}
//  Only the fields that are sent are changed. Changing "type_code" also
//  loads the ideal values of the new type (unless thresholds are sent too).
//  The device of the crop gets the new values in its next call (≤ 30 s).
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('POST');

$user = require_user();
$cropId = crop_id();
require_crop($user, $cropId);
$d = body();

$sets = [];
$params = [];

if (array_key_exists('type_code', $d)) {
    $st = db()->prepare('SELECT * FROM crop_types WHERE type_code = ?');
    $st->execute([(string)$d['type_code']]);
    $type = $st->fetch();
    if (!$type) fail(400, 'Unknown crop type');
    $sets[] = 'type_code = ?';
    $params[] = $type['type_code'];
    foreach (['moisture_min', 'moisture_max', 'temp_min', 'temp_max', 'lux_min'] as $f) {
        if (!array_key_exists($f, $d)) { $sets[] = "$f = ?"; $params[] = $type[$f]; }
    }
}

// field => [min, max]
$ranges = [
    'moisture_min' => [0, 100], 'moisture_max' => [0, 100],
    'temp_min' => [-10, 50],    'temp_max' => [-10, 60],
    'lux_min' => [0, 65000],
    'quiet_start' => [0, 23],   'quiet_end' => [0, 23],
];
foreach ($ranges as $field => [$min, $max]) {
    if (!array_key_exists($field, $d)) continue;
    if (!is_numeric($d[$field]) || $d[$field] < $min || $d[$field] > $max) fail(400, "$field must be between $min and $max");
    $sets[] = "$field = ?";
    $params[] = $d[$field] + 0;
}
if (array_key_exists('muted', $d)) {
    $sets[] = 'muted = ?';
    $params[] = $d['muted'] ? 1 : 0;
}
if (array_key_exists('name', $d)) {
    $name = trim((string)$d['name']);
    if ($name === '' || mb_strlen($name) > 60) fail(400, 'Crop name is required (max 60 characters)');
    $sets[] = 'name = ?';
    $params[] = $name;
}
if (array_key_exists('location', $d)) {
    $location = trim((string)$d['location']);
    if (mb_strlen($location) > 100) fail(400, 'Location is too long (max 100 characters)');
    $sets[] = 'location = ?';
    $params[] = $location === '' ? null : $location;
}

if ($sets) {
    $params[] = $cropId;
    db()->prepare('UPDATE crops SET ' . implode(', ', $sets) . ' WHERE crop_id = ?')->execute($params);
}
respond(['ok' => true, 'config' => settings_json(require_crop($user, $cropId))]);
