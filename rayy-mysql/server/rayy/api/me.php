<?php
// GET api/me.php   (header X-Auth-Token) → the signed-in user {user_id,email,full_name,role}
require_once __DIR__ . '/lib.php';
require_method('GET');

respond(['ok' => true, 'user' => user_json(require_user())]);
