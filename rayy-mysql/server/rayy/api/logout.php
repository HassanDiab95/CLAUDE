<?php
// POST api/logout.php   (header X-Auth-Token) → deletes the session
require_once __DIR__ . '/lib.php';
require_method('POST');

db()->prepare('DELETE FROM api_tokens WHERE token_hash = ?')->execute([hash('sha256', header_value('X-Auth-Token'))]);
respond(['ok' => true]);
