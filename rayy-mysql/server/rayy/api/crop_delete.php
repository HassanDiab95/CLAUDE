<?php
// =====================================================================
//  POST api/crop_delete.php?crop=1   (header X-Auth-Token)
//  Deletes the crop with its history and diary. A device on this crop
//  becomes "not assigned" (it can be moved to another crop).
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('POST');

$user = require_user();
$cropId = crop_id();
require_crop($user, $cropId);

db()->prepare('DELETE FROM crops WHERE crop_id = ?')->execute([$cropId]);   // foreign keys clean the rest
respond(['ok' => true]);
