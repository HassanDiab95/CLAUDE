<?php
// =====================================================================
//  POST api/login.php   {"email":"admin@rayy.app","password":"..."}
//  Answer: {"ok":true,"token":"...","user":{user_id,email,full_name,role}}
//  The apps send the token in the header X-Auth-Token on every request.
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('POST');

$d = body();
$email = strtolower(trim((string)($d['email'] ?? '')));
$password = (string)($d['password'] ?? '');

$st = db()->prepare('SELECT user_id, email, full_name, role, password_hash FROM users WHERE email = ?');
$st->execute([$email]);
$user = $st->fetch();
if (!$user || !password_verify($password, $user['password_hash'])) fail(401, 'Wrong email or password');

respond(['ok' => true, 'token' => new_token((int)$user['user_id']), 'user' => user_json($user)]);
