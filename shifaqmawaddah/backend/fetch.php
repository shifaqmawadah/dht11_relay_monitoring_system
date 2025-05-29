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

$result = $conn->query("SELECT * FROM sensor_data ORDER BY timestamp DESC LIMIT 30");

if (!$result) {
    http_response_code(500);
    echo json_encode(["error" => "Database query failed"]);
    exit;
}

$data = [];
while ($row = $result->fetch_assoc()) {
    $data[] = [
        "temperature" => floatval($row["temperature"]),
        "humidity" => floatval($row["humidity"]),
        "relay_status" => intval($row["relay_status"]),
        "timestamp" => $row["timestamp"]
    ];
}

echo json_encode(array_reverse($data));
?>
