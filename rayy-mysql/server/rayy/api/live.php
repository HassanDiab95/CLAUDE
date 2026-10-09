<?php
// =====================================================================
//  GET api/live.php?crop=1   (header X-Auth-Token)
//  The latest values + the settings + the device of one crop.
//  The apps call it every 5 seconds while the crop page is open.
//  Answer: {"ok":true,"live":{moisture,temperature,humidity,lux,mood,rssi,device_id,ts},
//           "config":{...},"device":{device_id,name,last_seen}|null,"type":{...}}
//          "live" is null until a device sends data for this crop. "ts" = milliseconds.
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('GET');

$user = require_user();
$cropId = crop_id();
$crop = require_crop($user, $cropId);

$st = db()->prepare('SELECT *, UNIX_TIMESTAMP(updated_at) * 1000 AS ts FROM live_status WHERE crop_id = ?');
$st->execute([$cropId]);

$st2 = db()->prepare('SELECT type_code, name_ar, name_en, emoji FROM crop_types WHERE type_code = ?');
$st2->execute([$crop['type_code']]);

respond([
    'ok'     => true,
    'live'   => live_json($st->fetch() ?: null),
    'config' => settings_json($crop),
    'device' => crop_device($cropId),
    'type'   => $st2->fetch(),
]);
