<?php
// =====================================================================
//  Rayy API: shared helpers (database, JSON, login checks)
// =====================================================================
require_once __DIR__ . '/config.php';

date_default_timezone_set(APP_TIMEZONE);

// Allow the Android app and other pages to call the API
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, X-Auth-Token, X-Device-Key');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Content-Type: application/json; charset=utf-8');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') exit;

/** One PDO connection per request. All queries use prepared statements (no SQL injection). */
function db(): PDO {
    static $pdo = null;
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
    respond(['ok' => false, 'error' => $message], $code);
}

function require_method(string $method): void {
    if ($_SERVER['REQUEST_METHOD'] !== $method) fail(405, "Use $method");
}

/** The JSON body of a POST request as an array */
function body(): array {
    $data = json_decode(file_get_contents('php://input') ?: '{}', true);
    if (!is_array($data)) fail(400, 'Invalid JSON');
    return $data;
}

function header_value(string $name): string {
    $key = 'HTTP_' . strtoupper(str_replace('-', '_', $name));
    return trim($_SERVER[$key] ?? '');
}

/** Plant ID from ?plant=... (default plant01) */
function plant_id(): string {
    $id = $_GET['plant'] ?? 'plant01';
    if (!preg_match('/^[A-Za-z0-9_-]{1,20}$/', $id)) fail(400, 'Invalid plant id');
    return $id;
}

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
    return $user;
}

/** Checks that the signed-in user may see this plant. */
function require_plant_access(array $user, string $plantId): void {
    $st = db()->prepare('SELECT 1 FROM plant_access WHERE user_id = ? AND plant_id = ?');
    $st->execute([$user['user_id'], $plantId]);
    if (!$st->fetch()) fail(403, 'No access to this plant');
}

/** Numbers from MySQL come back as strings: convert (null stays null). */
function num($v) {
    return $v === null ? null : $v + 0;
}

/** Settings row → the same JSON names used by the firmware and the apps */
function settings_json(array $s): array {
    return [
        'name'         => $s['name'],
        'moisture_min' => num($s['moisture_min']),
        'moisture_max' => num($s['moisture_max']),
        'temp_min'     => num($s['temp_min']),
        'temp_max'     => num($s['temp_max']),
        'lux_min'      => num($s['lux_min']),
        'quiet_start'  => num($s['quiet_start']),
        'quiet_end'    => num($s['quiet_end']),
        'muted'        => (bool)$s['muted'],
    ];
}

function load_settings(string $plantId): array {
    $st = db()->prepare('SELECT p.name, s.* FROM plants p JOIN plant_settings s ON s.plant_id = p.plant_id
                         WHERE p.plant_id = ?');
    $st->execute([$plantId]);
    $row = $st->fetch();
    if (!$row) fail(404, 'Unknown plant');
    return settings_json($row);
}
