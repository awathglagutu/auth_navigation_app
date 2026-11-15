<?php
declare(strict_types=1);
require_once __DIR__ . '/database.php';

handle_preflight();

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        header('Allow: POST, OPTIONS');
        json_response(405, ['success' => false, 'message' => 'Method not allowed.']);
    }

    // bearer_token() checks HTTP_AUTHORIZATION, REDIRECT_HTTP_AUTHORIZATION,
    // getallheaders(), and falls back to JSON body / query-string token.
    $token = bearer_token();
    if ($token !== null) {
        $delete = database()->prepare('DELETE FROM sessions WHERE token = :token');
        $delete->execute([':token' => $token]);
    }

    json_response(200, ['success' => true, 'message' => 'Logged out successfully.']);

} catch (Throwable $e) {
    json_response(500, ['success' => false, 'message' => 'Unable to log out right now.']);
}
