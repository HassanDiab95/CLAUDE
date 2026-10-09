<?php
// =====================================================================
//  POST api/device.php?device=rayy-01      (called by the ESP32 every 30 s)
//  Header : X-Device-Key: <DEVICE_KEY from config.h>
//  Body   : {"moisture":46,"temperature":27.4,"humidity":38,"lux":5400,
//            "mood":"happy","soil_raw":2190,"rssi":-61,"ip":"192.168.1.23",
//            "uptime_s":86400,
//            "history":true,                                   (every 5 min)
//            "event":{"mood":"thirsty","message":"..."}}       (when the mood changed)
//  Answer : {"ok":true,"crop":{"crop_id":1,"name":"..."},"config":{...thresholds...},
//            "play":0,"hour":14}
//  The values are saved for the crop the device is assigned to NOW. When the
//  device is moved to another crop, the answer brings the new crop's
//  thresholds, so the mood logic follows the new crop automatically.
//  If the device is not assigned to any crop: "crop":null, nothing is saved.
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('POST');

$deviceId = (string)($_GET['device'] ?? '');
$st = db()->prepare('SELECT device_id, device_key_hash, crop_id FROM devices WHERE device_id = ?');
$st->execute([$deviceId]);
$dev = $st->fetch();
if (!$dev || !hash_equals($dev['device_key_hash'], hash('sha256', header_value('X-Device-Key')))) {
    fail(401, 'Unknown device or wrong device key');
}

$pdo = db();
$pdo->prepare('UPDATE devices SET last_seen = NOW() WHERE device_id = ?')->execute([$deviceId]);
$hour = (int)date('G');                     // server clock, used when the ESP32 has no internet time

if ($dev['crop_id'] === null) {
    respond(['ok' => true, 'crop' => null, 'config' => null, 'play' => 0, 'hour' => $hour]);
}
$cropId = (int)$dev['crop_id'];

$d = body();
$mood = (string)($d['mood'] ?? '');
$st = $pdo->prepare('SELECT 1 FROM moods WHERE mood_code = ?');
$st->execute([$mood]);
if (!$st->fetch()) fail(400, 'Unknown mood');

// Optional numbers: null when the sensor could not be read
$val = fn(string $k) => isset($d[$k]) && is_numeric($d[$k]) ? $d[$k] + 0 : null;
$moisture = $val('moisture');
$temperature = $val('temperature');
$humidity = $val('humidity');
$lux = $val('lux');

$pdo->beginTransaction();

// 1) Live values of the crop (one row per crop, overwritten)
$pdo->prepare('INSERT INTO live_status (crop_id, device_id, moisture, temperature, humidity, lux, mood_code, soil_raw, rssi, ip, uptime_s, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
               ON DUPLICATE KEY UPDATE device_id = VALUES(device_id), moisture = VALUES(moisture),
                 temperature = VALUES(temperature), humidity = VALUES(humidity), lux = VALUES(lux),
                 mood_code = VALUES(mood_code), soil_raw = VALUES(soil_raw), rssi = VALUES(rssi),
                 ip = VALUES(ip), uptime_s = VALUES(uptime_s), updated_at = NOW()')
    ->execute([$cropId, $deviceId, $moisture, $temperature, $humidity, $lux, $mood,
               $val('soil_raw'), $val('rssi'), substr((string)($d['ip'] ?? ''), 0, 45), $val('uptime_s')]);

// 2) History point (the ESP32 sets "history": true every 5 minutes)
if (!empty($d['history'])) {
    $pdo->prepare('INSERT INTO readings (crop_id, device_id, moisture, temperature, humidity, lux, mood_code) VALUES (?, ?, ?, ?, ?, ?, ?)')
        ->execute([$cropId, $deviceId, $moisture, $temperature, $humidity, $lux, $mood]);
}

// 3) Diary event (the mood changed)
if (!empty($d['event']['mood'])) {
    $pdo->prepare('INSERT INTO mood_events (crop_id, device_id, mood_code, message)
                   SELECT ?, ?, mood_code, ? FROM moods WHERE mood_code = ?')
        ->execute([$cropId, $deviceId, mb_substr((string)($d['event']['message'] ?? ''), 0, 200), (string)$d['event']['mood']]);
}

// 4) Oldest pending "Play" command → returned to the ESP32 and marked as played
$st = $pdo->prepare("SELECT command_id, melody_no FROM play_commands
                     WHERE device_id = ? AND crop_id = ? AND status = 'pending' ORDER BY command_id LIMIT 1 FOR UPDATE");
$st->execute([$deviceId, $cropId]);
$cmd = $st->fetch();
if ($cmd) {
    $pdo->prepare("UPDATE play_commands SET status = 'played', played_at = NOW() WHERE command_id = ?")
        ->execute([$cmd['command_id']]);
}
$pdo->commit();

$st = $pdo->prepare('SELECT * FROM crops WHERE crop_id = ?');
$st->execute([$cropId]);
$crop = $st->fetch();

respond([
    'ok'     => true,
    'crop'   => ['crop_id' => $cropId, 'name' => $crop['name']],
    'config' => settings_json($crop),
    'play'   => $cmd ? (int)$cmd['melody_no'] : 0,
    'hour'   => $hour,
]);
