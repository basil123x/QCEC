<?php
// Quick test for get_total API
$url = 'https://qcec.online/app2026/sql.php';
$data = json_encode([
    'action' => 'get_total',
    'uid' => '1',
    'x' => '0'
]);

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_POST, 1);
curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "HTTP Code: $httpCode\n";
echo "Response: $response\n";

$decoded = json_decode($response, true);
if ($decoded) {
    echo "Status: " . ($decoded['status'] ?? 'unknown') . "\n";
    if (isset($decoded['trans_data'])) {
        echo "Data found!\n";
        print_r($decoded['trans_data']);
    }
} else {
    echo "JSON decode failed\n";
}
?>
