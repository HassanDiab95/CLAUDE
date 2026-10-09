<?php
// =====================================================================
//  POST api/device.php?plant=plant01      (called by the ESP32 every 30 s)
//  Header : X-Device-Key: <DEVICE_KEY from config.h>
//  Body   : {"moisture":46,"temperature":27.4,"humidity":38,"lux":5400,
//            "mood":"happy","soil_raw":2190,"rssi":-61,"ip":"192.168.1.23",
//            "uptime_s":86400,
//            "history":true,                                   (every 5 min)
//            "event":{"mood":"thirsty","message":"..."}}       (when the mood changed)
//  Answer : {"ok":true,"config":{...thresholds...},"play":0,"hour":14}
//           "play" = melody number requested from the apps (0 = none)
//  One request does everything: live values, history, diary, settings and
//  the "Play" command, so the ESP32 needs only one HTTP call every 30 s.
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('POST');

$plantId = plant_id();
$key = header_value('X-Device-Key');
$st = db()->prepare('SELECT device_key_hash FROM plants WHERE plant_id = ?');
$st->execute([$plantId]);
$plant = $st->fetch();
if (!$plant || !hash_equals($plant['device_key_hash'], hash('sha256', $key))) fail(401, 'Wrong device key');

$d = body();
$mood = (string)($d['mood'] ?? '');
$st = db()->prepare('SELECT 1 FROM moods WHERE mood_code = ?');
$st->execute([$mood]);
if (!$st->fetch()) fail(400, 'Unknown mood');

// Optional numbers: null when the sensor could not be read
$val = fn(string $k) => isset($d[$k]) && is_numeric($d[$k]) ? $d[$k] + 0 : null;
$moisture = $val('moisture');
$temperature = $val('temperature');
$humidity = $val('humidity');
$lux = $val('lux');

$pdo = db();
$pdo->beginTransaction();

// 1) Live values (one row per plant, overwritten)
$pdo->prepare('INSERT INTO live_status (plant_id, moisture, temperature, humidity, lux, mood_code, soil_raw, rssi, ip, uptime_s, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
               ON DUPLICATE KEY UPDATE moisture = VALUES(moisture), temperature = VALUES(temperature),
                 humidity = VALUES(humidity), lux = VALUES(lux), mood_code = VALUES(mood_code),
                 soil_raw = VALUES(soil_raw), rssi = VALUES(rssi), ip = VALUES(ip),
                 uptime_s = VALUES(uptime_s), updated_at = NOW()')
    ->execute([$plantId, $moisture, $temperature, $humidity, $lux, $mood,
               $val('soil_raw'), $val('rssi'), substr((string)($d['ip'] ?? ''), 0, 45), $val('uptime_s')]);

// 2) History point (the ESP32 sets "history": true every 5 minutes)
if (!empty($d['history'])) {
    $pdo->prepare('INSERT INTO readings (plant_id, moisture, temperature, humidity, lux, mood_code) VALUES (?, ?, ?, ?, ?, ?)')
        ->execute([$plantId, $moisture, $temperature, $humidity, $lux, $mood]);
}

// 3) Diary event (the mood changed)
if (!empty($d['event']['mood'])) {
    $pdo->prepare('INSERT INTO mood_events (plant_id, mood_code, message)
                   SELECT ?, mood_code, ? FROM moods WHERE mood_code = ?')
        ->execute([$plantId, mb_substr((string)($d['event']['message'] ?? ''), 0, 200), (string)$d['event']['mood']]);
}

// 4) Oldest pending "Play" command → returned to the ESP32 and marked as played
$st = $pdo->prepare("SELECT command_id, melody_no FROM play_commands
                     WHERE plant_id = ? AND status = 'pending' ORDER BY command_id LIMIT 1 FOR UPDATE");
$st->execute([$plantId]);
$cmd = $st->fetch();
if ($cmd) {
    $pdo->prepare("UPDATE play_commands SET status = 'played', played_at = NOW() WHERE command_id = ?")
        ->execute([$cmd['command_id']]);
}
$pdo->commit();

respond([
    'ok'     => true,
    'config' => load_settings($plantId),
    'play'   => $cmd ? (int)$cmd['melody_no'] : 0,
    'hour'   => (int)date('G'),          // server clock, used when the ESP32 has no internet time
]);
