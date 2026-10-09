<?php
// =====================================================================
//  POST api/settings.php?plant=plant01   (header X-Auth-Token)
//  Body: any of {"name","moisture_min","moisture_max","temp_min","temp_max",
//                "lux_min","quiet_start","quiet_end","muted"}
//  Only the fields that are sent are changed. The ESP32 gets the new
//  settings in its next call (within 30 s).
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('POST');

$user = require_user();
$plantId = plant_id();
require_plant_access($user, $plantId);
$d = body();

// field => [min, max]
$ranges = [
    'moisture_min' => [0, 100], 'moisture_max' => [0, 100],
    'temp_min' => [-10, 50],    'temp_max' => [-10, 60],
    'lux_min' => [0, 50000],
    'quiet_start' => [0, 23],   'quiet_end' => [0, 23],
];
$sets = [];
$params = [];
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

$pdo = db();
$pdo->beginTransaction();
if ($sets) {
    $params[] = $plantId;
    $pdo->prepare('UPDATE plant_settings SET ' . implode(', ', $sets) . ' WHERE plant_id = ?')->execute($params);
}
if (array_key_exists('name', $d)) {
    $name = trim((string)$d['name']);
    if ($name === '' || mb_strlen($name) > 30) fail(400, 'name must be 1 to 30 characters');
    $pdo->prepare('UPDATE plants SET name = ? WHERE plant_id = ?')->execute([$name, $plantId]);
}
$pdo->commit();

respond(['ok' => true, 'config' => load_settings($plantId)]);
