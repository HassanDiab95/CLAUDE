<?php
// =====================================================================
//  GET api/history.php?plant=plant01&hours=24   (header X-Auth-Token)
//  History points for the chart (one every 5 minutes), oldest first.
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('GET');

$user = require_user();
$plantId = plant_id();
require_plant_access($user, $plantId);
$hours = max(1, min(168, (int)($_GET['hours'] ?? 24)));

$st = db()->prepare('SELECT UNIX_TIMESTAMP(recorded_at) * 1000 AS ts, moisture, temperature, humidity, lux, mood_code
                     FROM readings WHERE plant_id = ? AND recorded_at >= NOW() - INTERVAL ? HOUR
                     ORDER BY recorded_at');
$st->execute([$plantId, $hours]);

$points = array_map(fn($r) => [
    'ts'          => (int)$r['ts'],
    'moisture'    => num($r['moisture']),
    'temperature' => num($r['temperature']),
    'humidity'    => num($r['humidity']),
    'lux'         => num($r['lux']),
    'mood'        => $r['mood_code'],
], $st->fetchAll());

respond(['ok' => true, 'history' => $points]);
