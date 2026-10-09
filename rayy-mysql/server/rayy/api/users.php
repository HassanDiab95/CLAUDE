<?php
// =====================================================================
//  Admin only: manage the users of ري
//  GET  api/users.php      → all users with their number of crops and devices
//  POST api/users.php      {"action":"create","full_name":"...","email":"...","password":"...","role":"user|admin"}
//                          {"action":"role","user_id":5,"role":"admin"}
//                          {"action":"delete","user_id":5}      (deletes the user's crops too)
// =====================================================================
require_once __DIR__ . '/lib.php';
$admin = require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $d = body();
    $action = (string)($d['action'] ?? '');
    $role = (string)($d['role'] ?? 'user');
    if (!in_array($role, ['user', 'admin'], true)) fail(400, 'role must be user or admin');

    if ($action === 'create') {
        [$email, $name, $password] = validate_new_user($d);
        db()->prepare('INSERT INTO users (email, full_name, password_hash, role) VALUES (?, ?, ?, ?)')
            ->execute([$email, $name, password_hash($password, PASSWORD_BCRYPT), $role]);
        respond(['ok' => true, 'user_id' => (int)db()->lastInsertId()]);
    }

    $userId = (int)($d['user_id'] ?? 0);
    $st = db()->prepare('SELECT user_id FROM users WHERE user_id = ?');
    $st->execute([$userId]);
    if (!$st->fetch()) fail(404, 'User not found');
    if ($userId === $admin['user_id']) fail(400, 'You cannot change or delete your own account here');

    if ($action === 'role') {
        db()->prepare('UPDATE users SET role = ? WHERE user_id = ?')->execute([$role, $userId]);
        respond(['ok' => true]);
    }
    if ($action === 'delete') {
        db()->prepare('DELETE FROM users WHERE user_id = ?')->execute([$userId]);   // crops, sessions: ON DELETE CASCADE
        respond(['ok' => true]);
    }
    fail(400, 'action must be create, role or delete');
}

require_method('GET');
$rows = db()->query('SELECT u.user_id, u.email, u.full_name, u.role, UNIX_TIMESTAMP(u.created_at) * 1000 AS created,
                            (SELECT COUNT(*) FROM crops c WHERE c.owner_id = u.user_id) AS crops,
                            (SELECT COUNT(*) FROM devices d WHERE d.owner_id = u.user_id) AS devices
                     FROM users u ORDER BY u.user_id')->fetchAll();

$users = array_map(fn($r) => user_json($r) + ['created' => num($r['created']), 'crops' => (int)$r['crops'], 'devices' => (int)$r['devices']], $rows);
respond(['ok' => true, 'users' => $users]);
