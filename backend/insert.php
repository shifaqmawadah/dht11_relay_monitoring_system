<?php
include 'dbconnect.php'; // Ensure $conn is set correctly

header('Content-Type: application/json');

// Enable error reporting for debugging
ini_set('display_errors', 1);
error_reporting(E_ALL);

// Read JSON input
$input = file_get_contents("php://input");
$data = json_decode($input, true);

// Validate input
if (!isset($data['temperature'], $data['humidity'], $data['relay_status'])) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Missing required fields"]);
    exit;
}

// Sanitize and assign
$temp = floatval($data['temperature']);
$hum = floatval($data['humidity']);
$relay = intval($data['relay_status']);

// Prepare and execute SQL (timestamp is generated using NOW())
if ($stmt = $conn->prepare("INSERT INTO sensor_data (temperature, humidity, relay_status, timestamp) VALUES (?, ?, ?, NOW())")) {
    $stmt->bind_param("ddi", $temp, $hum, $relay);
    if ($stmt->execute()) {
        echo json_encode(["status" => "success"]);
    } else {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Execution failed", "error" => $stmt->error]);
    }
    $stmt->close();
} else {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Prepare failed", "error" => $conn->error]);
}

$conn->close();
?>
