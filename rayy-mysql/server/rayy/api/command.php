<?php
// =====================================================================
//  POST api/command.php?plant=plant01   (header X-Auth-Token)
//  Body: {"play": 1..9}  → the ESP32 plays this melody within 30 s
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('POST');

$user = require_user();
$plantId = plant_id();
require_plant_access($user, $plantId);

$melody = (int)(body()['play'] ?? 0);
if ($melody < 1 || $melody > 9) fail(400, 'play must be 1..9');

db()->prepare('INSERT INTO play_commands (plant_id, user_id, melody_no) VALUES (?, ?, ?)')
    ->execute([$plantId, $user['user_id'], $melody]);

respond(['ok' => true]);
