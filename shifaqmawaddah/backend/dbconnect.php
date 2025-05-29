<?php
$host = "localhost";       
$db = "humancmt_sm_dht11";
$user = "humancmt_sm";
$pass = "917603Sm#";

$conn = new mysqli($host, $user, $pass, $db);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>
