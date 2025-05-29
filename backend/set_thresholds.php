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
$data = json_decode(file_get_contents('php://input'), true);
$temp = $data['temp_threshold'];
$humidity = $data['humidity_threshold'];

$sql = "INSERT INTO thresholds (temp_threshold, humidity_threshold) VALUES ('$temp', '$humidity')";
$conn->query($sql);
$conn->close();
?>
