<?php
// =====================================================================
//  GET api/crop_types.php   → the crop library (strawberry, tomato, mint ...)
//  with the ideal moisture / temperature / light of each type.
//  Public: the apps need it in the "add crop" form.
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('GET');

$rows = db()->query('SELECT * FROM crop_types ORDER BY type_code = "other", name_en')->fetchAll();
$types = array_map(fn($t) => [
    'type_code'    => $t['type_code'],
    'name_ar'      => $t['name_ar'],
    'name_en'      => $t['name_en'],
    'emoji'        => $t['emoji'],
    'moisture_min' => num($t['moisture_min']),
    'moisture_max' => num($t['moisture_max']),
    'temp_min'     => num($t['temp_min']),
    'temp_max'     => num($t['temp_max']),
    'lux_min'      => num($t['lux_min']),
], $rows);

respond(['ok' => true, 'types' => $types]);
