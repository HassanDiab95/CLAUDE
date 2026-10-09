<?php
// =====================================================================
//  POST api/command.php?crop=1   (header X-Auth-Token)
//  Body: {"play": 1..9}  → the device of this crop plays the melody within 30 s
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('POST');

$user = require_user();
$cropId = crop_id();
require_crop($user, $cropId);

$melody = (int)(body()['play'] ?? 0);
if ($melody < 1 || $melody > 9) fail(400, 'play must be 1..9');
$device = crop_device($cropId);
if (!$device) fail(409, 'No device is assigned to this crop');

db()->prepare('INSERT INTO play_commands (crop_id, device_id, user_id, melody_no) VALUES (?, ?, ?, ?)')
    ->execute([$cropId, $device['device_id'], $user['user_id'], $melody]);

respond(['ok' => true]);
