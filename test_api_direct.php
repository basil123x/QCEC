<?php
/**
 * Direct API Test for get_total
 * Test the API endpoint directly
 */

// Test URL
$url = 'https://qcec.online/app2026/sql.php';

// Test data
$testData = [
    'action' => 'get_total',
    'uid' => '1',
    'x' => '0'
];

echo "=== Testing get_total API ===\n";
echo "URL: $url\n";
echo "Data: " . json_encode($testData, JSON_PRETTY_PRINT) . "\n\n";

// Initialize cURL
$ch = curl_init();

// Set cURL options
curl_setopt_array($ch, [
    CURLOPT_URL => $url,
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => json_encode($testData),
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => [
        'Content-Type: application/json',
        'Accept: application/json'
    ],
    CURLOPT_TIMEOUT => 30,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_VERBOSE => true
]);

// Execute request
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);

curl_close($ch);

// Display results
echo "HTTP Code: $httpCode\n";
if ($error) {
    echo "cURL Error: $error\n";
}

echo "Raw Response:\n";
echo $response . "\n\n";

// Try to parse JSON
$decoded = json_decode($response, true);
if ($decoded) {
    echo "Parsed JSON:\n";
    print_r($decoded);
    
    if (isset($decoded['status']) && $decoded['status'] === 'success') {
        echo "\n✅ SUCCESS!\n";
        if (isset($decoded['trans_data']) && !empty($decoded['trans_data'])) {
            $stats = $decoded['trans_data'][0];
            echo "📊 Statistics:\n";
            echo "   - Projects (v1): " . ($stats['v1'] ?? 'N/A') . "\n";
            echo "   - Total Visits (v2): " . ($stats['v2'] ?? 'N/A') . "\n";
            echo "   - Today Visits (v3): " . ($stats['v3'] ?? 'N/A') . "\n";
        }
    } else {
        echo "\n❌ ERROR: " . ($decoded['message'] ?? 'Unknown error') . "\n";
    }
} else {
    echo "❌ Failed to parse JSON response\n";
    echo "JSON Error: " . json_last_error_msg() . "\n";
}

echo "\n=== Test Complete ===\n";
?>
