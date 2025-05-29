<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

include 'dbconnect.php';

$email = $_POST['email'] ?? '';
$password = $_POST['password'] ?? '';

if (!$email || !$password) {
    echo json_encode(['success' => false, 'message' => 'Missing email or password']);
    exit;
}

$stmt = $conn->prepare("SELECT id, password FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($user = $result->fetch_assoc()) {
    if (password_verify($password, $user['password'])) {
        echo json_encode(['success' => true, 'message' => 'Login successful', 'user_id' => $user['id']]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Incorrect password']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'User not found']);
}
?>
