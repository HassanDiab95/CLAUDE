<?php
// =====================================================================
//  ري API: shared helpers (database, JSON, login and permission checks)
// =====================================================================
require_once __DIR__ . '/config.php';

date_default_timezone_set(APP_TIMEZONE);
$pdo = null;     // database connection, opened by db() on first use

// Allow the Android app and other pages to call the API
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, X-Auth-Token, X-Device-Key');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Content-Type: application/json; charset=utf-8');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') exit;

/** One PDO connection per request. All queries use prepared statements (no SQL injection). */
function db(): PDO {
    global $pdo;
    if ($pdo === null) {
        try {
            $pdo = new PDO(
                'mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME . ';charset=utf8mb4',
                DB_USER, DB_PASS,
                [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
            );
            // Use the same time zone as PHP for NOW() and UNIX_TIMESTAMP()
            $pdo->exec("SET time_zone = '" . (new DateTime())->format('P') . "'");
        } catch (PDOException $e) {
            fail(500, 'Database connection failed: start MySQL in XAMPP and import database/rayy.sql');
        }
    }
    return $pdo;
}

function respond(array $data, int $code = 200): void {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function fail(int $code, string $message): void {
    global $pdo;
    if ($pdo !== null && $pdo->inTransaction()) $pdo->rollBack();   // undo a half-done change
    respond(['ok' => false, 'error' => $message], $code);
}

function require_method(string $method): void {
    if ($_SERVER['REQUEST_METHOD'] !== $method) fail(405, "Use $method");
}

/** The JSON body of a POST request as an array */
function body(): array {
    static $data = null;
    if ($data === null) {
        $data = json_decode(file_get_contents('php://input') ?: '{}', true);
        if (!is_array($data)) fail(400, 'Invalid JSON');
    }
    return $data;
}

function header_value(string $name): string {
    $key = 'HTTP_' . strtoupper(str_replace('-', '_', $name));
    return trim($_SERVER[$key] ?? '');
}

/** Numbers from MySQL come back as strings: convert (null stays null). */
function num($v) {
    return $v === null ? null : $v + 0;
}

// ---------------------------------------------------------------------
//  Users and permissions
// ---------------------------------------------------------------------

/** Checks the login token (header X-Auth-Token) and returns the user row. */
function require_user(): array {
    $token = header_value('X-Auth-Token');
    if ($token === '') fail(401, 'Not signed in');
    $st = db()->prepare('SELECT u.user_id, u.email, u.full_name, u.role FROM api_tokens t
                         JOIN users u ON u.user_id = t.user_id
                         WHERE t.token_hash = ? AND t.expires_at > NOW()');
    $st->execute([hash('sha256', $token)]);
    $user = $st->fetch();
    if (!$user) fail(401, 'Session expired, sign in again');
    $user['user_id'] = (int)$user['user_id'];
    return $user;
}

function require_admin(): array {
    $user = require_user();
    if ($user['role'] !== 'admin') fail(403, 'Only an admin can do this');
    return $user;
}

function is_admin(array $user): bool {
    return $user['role'] === 'admin';
}

/** Creates a login session and returns the token for the app. */
function new_token(int $userId): string {
    $token = bin2hex(random_bytes(32));
    db()->prepare('INSERT INTO api_tokens (token_hash, user_id, expires_at) VALUES (?, ?, NOW() + INTERVAL ' . (int)TOKEN_DAYS . ' DAY)')
        ->execute([hash('sha256', $token), $userId]);
    db()->exec('DELETE FROM api_tokens WHERE expires_at < NOW()');      // clean old sessions
    return $token;
}

function user_json(array $u): array {
    return ['user_id' => (int)$u['user_id'], 'email' => $u['email'], 'full_name' => $u['full_name'], 'role' => $u['role']];
}

/** Checks and normalises the fields of a new user. Returns [email, name, password]. */
function validate_new_user(array $d): array {
    $email = strtolower(trim((string)($d['email'] ?? '')));
    $name = trim((string)($d['full_name'] ?? ''));
    $password = (string)($d['password'] ?? '');
    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 120) fail(400, 'Invalid email');
    if ($name === '' || mb_strlen($name) > 100) fail(400, 'Name is required (max 100 characters)');
    if (strlen($password) < 8) fail(400, 'Password must be at least 8 characters');
    $st = db()->prepare('SELECT 1 FROM users WHERE email = ?');
    $st->execute([$email]);
    if ($st->fetch()) fail(409, 'This email is already registered');
    return [$email, $name, $password];
}

// ---------------------------------------------------------------------
//  Crops
// ---------------------------------------------------------------------

/** Crop ID from ?crop=... */
function crop_id(): int {
    $id = (int)($_GET['crop'] ?? 0);
    if ($id <= 0) fail(400, 'Missing crop id (?crop=...)');
    return $id;
}

/** Loads a crop and checks that the user owns it (admins see every crop). */
function require_crop(array $user, int $cropId): array {
    $st = db()->prepare('SELECT * FROM crops WHERE crop_id = ?');
    $st->execute([$cropId]);
    $crop = $st->fetch();
    if (!$crop) fail(404, 'Crop not found');
    if (!is_admin($user) && (int)$crop['owner_id'] !== $user['user_id']) fail(403, 'This crop belongs to another user');
    return $crop;
}

/** Crop thresholds → the JSON names used by the firmware and the apps */
function settings_json(array $c): array {
    return [
        'name'         => $c['name'],
        'location'     => $c['location'],
        'type_code'    => $c['type_code'],
        'moisture_min' => num($c['moisture_min']),
        'moisture_max' => num($c['moisture_max']),
        'temp_min'     => num($c['temp_min']),
        'temp_max'     => num($c['temp_max']),
        'lux_min'      => num($c['lux_min']),
        'quiet_start'  => num($c['quiet_start']),
        'quiet_end'    => num($c['quiet_end']),
        'muted'        => (bool)$c['muted'],
    ];
}

/** Device currently assigned to a crop (or null) */
function crop_device(int $cropId): ?array {
    $st = db()->prepare('SELECT device_id, name, UNIX_TIMESTAMP(last_seen) * 1000 AS last_seen FROM devices WHERE crop_id = ? LIMIT 1');
    $st->execute([$cropId]);
    $d = $st->fetch();
    return $d ? ['device_id' => $d['device_id'], 'name' => $d['name'], 'last_seen' => num($d['last_seen'])] : null;
}

/** Live row → JSON (null when there is no data yet) */
function live_json(?array $row): ?array {
    if (!$row || $row['mood_code'] === null) return null;
    return [
        'moisture'    => num($row['moisture']),
        'temperature' => num($row['temperature']),
        'humidity'    => num($row['humidity']),
        'lux'         => num($row['lux']),
        'mood'        => $row['mood_code'],
        'soil_raw'    => num($row['soil_raw'] ?? null),
        'rssi'        => num($row['rssi']),
        'device_id'   => $row['device_id'],
        'ts'          => (int)$row['ts'],
    ];
}
