<?php
declare(strict_types=1);
require_once __DIR__ . '/database.php';

handle_preflight();

try {
    $method = $_SERVER['REQUEST_METHOD'] ?? '';
    if (!in_array($method, ['GET', 'POST'], true)) {
        header('Allow: GET, POST, OPTIONS');
        json_response(405, ['success' => false, 'message' => 'Method not allowed.']);
    }

    // bearer_token() checks HTTP_AUTHORIZATION, REDIRECT_HTTP_AUTHORIZATION,
    // getallheaders(), and falls back to JSON body / query-string token.
    $token = bearer_token();
    if ($token === null) {
        json_response(401, ['success' => false, 'message' => 'Unauthorized or expired session.']);
    }

    $pdo   = database();
    $query = $pdo->prepare(
        'SELECT users.name, users.email, users.role
         FROM sessions
         INNER JOIN users ON users.id = sessions.user_id
         WHERE sessions.token = :token AND sessions.expires_at > :now
         LIMIT 1'
    );
    $query->execute([':token' => $token, ':now' => gmdate('c')]);
    $user = $query->fetch();

    if ($user === false) {
        json_response(401, ['success' => false, 'message' => 'Unauthorized or expired session.']);
    }

    json_response(200, [
        'success' => true,
        'user'    => [
            'name'  => $user['name'],
            'email' => $user['email'],
            'role'  => $user['role'],
        ],
    ]);

} catch (Throwable $e) {
    json_response(500, ['success' => false, 'message' => 'Unable to load profile right now.']);
}
