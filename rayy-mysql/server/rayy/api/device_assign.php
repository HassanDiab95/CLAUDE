<?php
// =====================================================================
//  POST api/device_assign.php   {"device_id":"rayy-01","crop_id":2}
//  Moves a device to another crop (crop_id = null → not assigned).
//  From now on its readings, diary and "Play" commands belong to the new crop.
//  The move is saved in the table device_assignments (history).
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('POST');

$user = require_user();
$d = body();
$deviceId = (string)($d['device_id'] ?? '');
$cropId = isset($d['crop_id']) && $d['crop_id'] !== null ? (int)$d['crop_id'] : null;

$st = db()->prepare('SELECT device_id, owner_id, crop_id FROM devices WHERE device_id = ?');
$st->execute([$deviceId]);
$dev = $st->fetch();
if (!$dev) fail(404, 'Device not found');
if (!is_admin($user) && (int)$dev['owner_id'] !== $user['user_id']) fail(403, 'This device belongs to another user');
if ($cropId !== null) require_crop($user, $cropId);     // the user must own the crop too

$pdo = db();
$pdo->beginTransaction();
if ($dev['crop_id'] !== null && (int)$dev['crop_id'] !== $cropId) {
    $pdo->prepare('UPDATE device_assignments SET removed_at = NOW() WHERE device_id = ? AND removed_at IS NULL')
        ->execute([$deviceId]);
    // Pending "Play" commands of the old crop are not played on the new crop
    $pdo->prepare("UPDATE play_commands SET status = 'played', played_at = NOW() WHERE device_id = ? AND status = 'pending'")
        ->execute([$deviceId]);
}
if ($cropId !== null && (int)$dev['crop_id'] !== $cropId) {
    // A crop is measured by one device at a time: free the crop first
    $pdo->prepare('UPDATE device_assignments SET removed_at = NOW() WHERE crop_id = ? AND removed_at IS NULL')->execute([$cropId]);
    $pdo->prepare('UPDATE devices SET crop_id = NULL WHERE crop_id = ?')->execute([$cropId]);
    $pdo->prepare('INSERT INTO device_assignments (device_id, crop_id, assigned_by) VALUES (?, ?, ?)')
        ->execute([$deviceId, $cropId, $user['user_id']]);
}
$pdo->prepare('UPDATE devices SET crop_id = ? WHERE device_id = ?')->execute([$cropId, $deviceId]);
$pdo->commit();

respond(['ok' => true]);
