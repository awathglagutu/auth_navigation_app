<?php
declare(strict_types=1);
require_once __DIR__ . '/database.php';
handle_preflight();
header('Content-Type: application/json; charset=utf-8');

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST, OPTIONS');
    json_response(405, ['success' => false, 'message' => 'Method not allowed.']);
}

$data = request_data();
$name = trim(is_string($data['name'] ?? null) ? $data['name'] : '');
$email = trim(is_string($data['email'] ?? null) ? $data['email'] : '');
$password = is_string($data['password'] ?? null) ? $data['password'] : '';
if ($name === '' || $email === '' || $password === '') {
    json_response(400, ['success' => false, 'message' => 'Name, email, and password are required.']);
}
if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
    json_response(400, ['success' => false, 'message' => 'Enter a valid email address.']);
}
if (strlen($password) < 6) {
    json_response(400, ['success' => false, 'message' => 'Password must be at least 6 characters.']);
}

try {
    $pdo = database();
    $exists = $pdo->prepare('SELECT id FROM users WHERE email = :email LIMIT 1');
    $exists->execute([':email' => $email]);
    if ($exists->fetch() !== false) {
        json_response(409, ['success' => false, 'message' => 'Email is already registered.']);
    }
    $insert = $pdo->prepare(
        'INSERT INTO users (name, email, password_hash, role, created_at)
         VALUES (:name, :email, :password_hash, :role, :created_at)'
    );
    $insert->execute([
        ':name' => $name,
        ':email' => $email,
        ':password_hash' => password_hash($password, PASSWORD_DEFAULT),
        ':role' => 'Student',
        ':created_at' => gmdate('c'),
    ]);
    json_response(201, ['success' => true, 'message' => 'Registration successful. Please log in.']);
} catch (PDOException $exception) {
    if ($exception->getCode() === '23000' || str_contains($exception->getMessage(), 'UNIQUE constraint failed: users.email')) {
        json_response(409, ['success' => false, 'message' => 'Email is already registered.']);
    }
    json_response(500, ['success' => false, 'message' => 'Unable to register right now.']);
}
