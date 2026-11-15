<?php
declare(strict_types=1);
require_once __DIR__ . '/database.php';
handle_preflight();
header('Content-Type: application/json; charset=utf-8');

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST, OPTIONS');
    json_response(405, ['success' => false, 'message' => 'Method not allowed.']);
}
$token = bearer_token();
if ($token !== null) {
    try {
        $delete = database()->prepare('DELETE FROM sessions WHERE token = :token');
        $delete->execute([':token' => $token]);
    } catch (Throwable $exception) {
        json_response(500, ['success' => false, 'message' => 'Unable to log out right now.']);
    }
}
json_response(200, ['success' => true, 'message' => 'Logged out successfully.']);
