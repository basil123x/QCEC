<?php
/**
 * Test script for get_total API endpoint
 * This script tests the getTotalStats function
 */

// Test data for different user types
$testCases = [
    [
        'name' => 'Admin User',
        'data' => [
            'action' => 'get_total',
            'uid' => '1',
            'x' => '0'
        ]
    ],
    [
        'name' => 'Customer User',
        'data' => [
            'action' => 'get_total',
            'uid' => '123',
            'x' => '1'
        ]
    ],
    [
        'name' => 'Engineer User',
        'data' => [
            'action' => 'get_total',
            'uid' => '456',
            'x' => '2'
        ]
    ],
    [
        'name' => 'Contractor User',
        'data' => [
            'action' => 'get_total',
            'uid' => '789',
            'x' => '3'
        ]
    ]
];

echo "=== Testing get_total API Endpoint ===\n\n";

foreach ($testCases as $testCase) {
    echo "Testing: " . $testCase['name'] . "\n";
    echo "Request Data: " . json_encode($testCase['data'], JSON_PRETTY_PRINT) . "\n";
    
    // Simulate the API call
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'https://qcec-qatar.com/app2026/sql.php');
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($testCase['data']));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Accept: application/json'
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    echo "HTTP Code: " . $httpCode . "\n";
    echo "Response: " . $response . "\n";
    
    // Try to decode JSON
    $decodedResponse = json_decode($response, true);
    if ($decodedResponse) {
        echo "Parsed Response:\n";
        if (isset($decodedResponse['status']) && $decodedResponse['status'] === 'success') {
            echo "✅ Success!\n";
            if (isset($decodedResponse['trans_data']) && !empty($decodedResponse['trans_data'])) {
                $stats = $decodedResponse['trans_data'][0];
                echo "📊 Statistics:\n";
                echo "   - Total Projects (v1): " . ($stats['v1'] ?? '0') . "\n";
                echo "   - Total Visits (v2): " . ($stats['v2'] ?? '0') . "\n";
                echo "   - Today's Visits (v3): " . ($stats['v3'] ?? '0') . "\n";
            }
        } else {
            echo "❌ Error: " . ($decodedResponse['message'] ?? 'Unknown error') . "\n";
        }
    } else {
        echo "❌ Invalid JSON response\n";
    }
    
    echo "\n" . str_repeat("-", 50) . "\n\n";
}

echo "=== Test Complete ===\n";
?>
