<?php
// =====================================================================
//  GET api/live.php?plant=plant01   (header X-Auth-Token)
//  The latest values + the settings. The apps call it every 5 seconds.
//  Answer: {"ok":true,"live":{moisture,temperature,humidity,lux,mood,rssi,ts},"config":{...}}
//          "live" is null until the ESP32 sends its first data. "ts" = milliseconds.
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('GET');

$user = require_user();
$plantId = plant_id();
require_plant_access($user, $plantId);

$st = db()->prepare('SELECT moisture, temperature, humidity, lux, mood_code, soil_raw, rssi, ip, uptime_s,
                            UNIX_TIMESTAMP(updated_at) * 1000 AS ts
                     FROM live_status WHERE plant_id = ?');
$st->execute([$plantId]);
$row = $st->fetch();

$live = $row ? [
    'moisture'    => num($row['moisture']),
    'temperature' => num($row['temperature']),
    'humidity'    => num($row['humidity']),
    'lux'         => num($row['lux']),
    'mood'        => $row['mood_code'],
    'soil_raw'    => num($row['soil_raw']),
    'rssi'        => num($row['rssi']),
    'ip'          => $row['ip'],
    'uptime_s'    => num($row['uptime_s']),
    'ts'          => (int)$row['ts'],
] : null;

respond(['ok' => true, 'live' => $live, 'config' => load_settings($plantId)]);
