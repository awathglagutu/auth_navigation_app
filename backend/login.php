<?php
declare(strict_types=1);
require_once __DIR__ . '/database.php';

handle_preflight();

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        header('Allow: POST, OPTIONS');
        json_response(405, ['success' => false, 'message' => 'Method not allowed.']);
    }

    // Accept both JSON body and form-encoded POST.
    $data     = request_data();
    $email    = trim(is_string($data['email']    ?? null) ? $data['email']    : '');
    $password = is_string($data['password'] ?? null) ? $data['password'] : '';

    if ($email === '' || $password === '') {
        json_response(400, ['success' => false, 'message' => 'Email and password are required.']);
    }

    $pdo   = database();
    $query = $pdo->prepare('SELECT id, password_hash FROM users WHERE email = :email LIMIT 1');
    $query->execute([':email' => $email]);
    $user  = $query->fetch();

    if ($user === false || !password_verify($password, $user['password_hash'])) {
        json_response(401, ['success' => false, 'message' => 'Invalid email or password.']);
    }

    $token  = bin2hex(random_bytes(32));
    $now    = time();
    $insert = $pdo->prepare(
        'INSERT INTO sessions (user_id, token, created_at, expires_at)
         VALUES (:user_id, :token, :created_at, :expires_at)'
    );
    $insert->execute([
        ':user_id'    => $user['id'],
        ':token'      => $token,
        ':created_at' => gmdate('c', $now),
        ':expires_at' => gmdate('c', $now + 7 * 24 * 60 * 60),
    ]);
    json_response(200, ['success' => true, 'message' => 'Login successful.', 'token' => $token]);

} catch (Throwable $e) {
    json_response(500, ['success' => false, 'message' => 'Unable to log in right now.']);
}
