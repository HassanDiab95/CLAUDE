<?php
// =====================================================================
//  POST api/register.php   {"full_name":"...","email":"...","password":"..."}
//  Anyone can create an account (role "user") from the web or Android app.
//  Answer: {"ok":true,"token":"...","user":{...}}  (signed in directly)
// =====================================================================
require_once __DIR__ . '/lib.php';
require_method('POST');

[$email, $name, $password] = validate_new_user(body());
db()->prepare("INSERT INTO users (email, full_name, password_hash, role) VALUES (?, ?, ?, 'user')")
    ->execute([$email, $name, password_hash($password, PASSWORD_BCRYPT)]);
$userId = (int)db()->lastInsertId();

respond(['ok' => true, 'token' => new_token($userId),
         'user' => ['user_id' => $userId, 'email' => $email, 'full_name' => $name, 'role' => 'user']]);
