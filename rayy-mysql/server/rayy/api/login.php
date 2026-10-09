<?php
// =====================================================================
//  POST api/login.php   {"email":"team@rayy.app","password":"..."}
//  Answer: {"ok":true,"token":"...","user":{...}}
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

$token = bin2hex(random_bytes(32));
db()->prepare('INSERT INTO api_tokens (token_hash, user_id, expires_at) VALUES (?, ?, NOW() + INTERVAL ' . (int)TOKEN_DAYS . ' DAY)')
    ->execute([hash('sha256', $token), $user['user_id']]);
db()->exec('DELETE FROM api_tokens WHERE expires_at < NOW()');      // clean old sessions

unset($user['password_hash']);
respond(['ok' => true, 'token' => $token, 'user' => $user]);
