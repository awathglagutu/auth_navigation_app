<?php
declare(strict_types=1);

// ── Silence HTML error output so PHP never breaks Flutter's jsonDecode ──────
ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
error_reporting(E_ALL);

// ── CORS helpers ─────────────────────────────────────────────────────────────

function cors_headers(): void
{
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, Accept');
    header('Access-Control-Max-Age: 86400');
}

function json_response(int $status, array $payload): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=UTF-8');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function handle_preflight(): void
{
    cors_headers();
    header('Content-Type: application/json; charset=UTF-8');
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        // Respond HTTP 200 (not 204) so some older HTTP clients don't fail.
        http_response_code(200);
        exit;
    }
}

// ── Input parsing (supports JSON body AND form-encoded POST) ─────────────────

function request_data(): array
{
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    if (stripos($contentType, 'application/json') !== false) {
        $raw  = file_get_contents('php://input');
        $data = json_decode($raw === false ? '' : $raw, true);
        return is_array($data) ? $data : [];
    }
    // Fall back to classic form-encoded POST body.
    return $_POST;
}

// ── Authorization header (survives servers that strip the header) ────────────

function bearer_token(): ?string
{
    // 1. Standard header (most servers)
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';

    // 2. Apache mod_rewrite sometimes renames it
    if ($header === '') {
        $header = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    }

    // 3. getallheaders() – works on some FastCGI / nginx setups
    if ($header === '' && function_exists('getallheaders')) {
        $all = getallheaders();
        // Header names are case-insensitive; check both casings.
        $header = $all['Authorization'] ?? $all['authorization'] ?? '';
    }

    if (preg_match('/^Bearer\s+(.+)$/i', trim($header), $matches) === 1) {
        return trim($matches[1]);
    }

    // 4. Fallback: token in JSON body or query string
    $data  = request_data();
    $token = $data['token'] ?? $_GET['token'] ?? null;
    return is_string($token) && $token !== '' ? $token : null;
}

// ── SQLite driver guard & PDO factory ───────────────────────────────────────

function database(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    // Guard 1: PDO SQLite extension must be loaded.
    if (!extension_loaded('pdo_sqlite')) {
        json_response(500, [
            'success' => false,
            'message' => 'Server configuration error: pdo_sqlite extension is not enabled.',
        ]);
    }

    $dbPath = __DIR__ . DIRECTORY_SEPARATOR . 'database.sqlite';
    $dbDir  = __DIR__;

    // Guard 2: The directory must be writable so SQLite can create/lock the file.
    if (!is_writable($dbDir)) {
        json_response(500, [
            'success' => false,
            'message' => 'Server configuration error: database directory is not writable ('
                . $dbDir . ').',
        ]);
    }

    try {
        $pdo = new PDO('sqlite:' . $dbPath);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        $pdo->exec('PRAGMA foreign_keys = ON');
        $pdo->exec(
            'CREATE TABLE IF NOT EXISTS users (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                name          TEXT    NOT NULL,
                email         TEXT    NOT NULL UNIQUE,
                password_hash TEXT    NOT NULL,
                role          TEXT    NOT NULL,
                created_at    TEXT    NOT NULL
            )'
        );
        $pdo->exec(
            'CREATE TABLE IF NOT EXISTS sessions (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                token      TEXT    NOT NULL UNIQUE,
                created_at TEXT    NOT NULL,
                expires_at TEXT    NOT NULL
            )'
        );

        // Seed a default admin account if none exists.
        $findAdmin = $pdo->prepare('SELECT id FROM users WHERE email = :email LIMIT 1');
        $findAdmin->execute([':email' => 'admin@demo.com']);
        if ($findAdmin->fetch() === false) {
            $seedAdmin = $pdo->prepare(
                'INSERT INTO users (name, email, password_hash, role, created_at)
                 VALUES (:name, :email, :password_hash, :role, :created_at)'
            );
            $seedAdmin->execute([
                ':name'          => 'Administrator',
                ':email'         => 'admin@demo.com',
                ':password_hash' => password_hash('admin123', PASSWORD_DEFAULT),
                ':role'          => 'Admin',
                ':created_at'    => gmdate('c'),
            ]);
        }
    } catch (Throwable $e) {
        json_response(500, [
            'success' => false,
            'message' => 'Database initialisation failed: ' . $e->getMessage(),
        ]);
    }

    return $pdo;
}
