<?php
// =====================================================================
//  GET api/events.php?plant=plant01&limit=30   (header X-Auth-Token)
//  The plant diary: latest mood changes, newest first.
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('GET');

$user = require_user();
$plantId = plant_id();
require_plant_access($user, $plantId);
$limit = max(1, min(200, (int)($_GET['limit'] ?? 30)));

$st = db()->prepare('SELECT UNIX_TIMESTAMP(occurred_at) * 1000 AS ts, mood_code, message
                     FROM mood_events WHERE plant_id = ? ORDER BY event_id DESC LIMIT ' . $limit);
$st->execute([$plantId]);

$events = array_map(fn($r) => ['ts' => (int)$r['ts'], 'mood' => $r['mood_code'], 'message' => $r['message']],
                    $st->fetchAll());

respond(['ok' => true, 'events' => $events]);
