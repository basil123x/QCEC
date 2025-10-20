<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Database configuration
$servername = "localhost";
$username = "qcecqc5_qcec";
$password = "Qcec@8080";
$dbname = "qcecqc5_qcec";

try {
    // Create connection
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    // Check connection
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }
    
    // Set charset to UTF-8
    $conn->set_charset("utf8");
    
    // Get POST data
    $visit_id = isset($_POST['visit_id']) ? (int)$_POST['visit_id'] : 0;
    $image_count = isset($_POST['image_count']) ? (int)$_POST['image_count'] : 0;
    $mob1 = isset($_POST['mob1']) ? (int)$_POST['mob1'] : 0;
    $mob2 = isset($_POST['mob2']) ? (int)$_POST['mob2'] : 0;
    
    if ($visit_id <= 0) {
        throw new Exception("Invalid visit ID");
    }
    
    // Update visit record
    $sql = "UPDATE visits_det SET a8 = ?, mob1 = ?, mob2 = ? WHERE id = ?";
    $stmt = $conn->prepare($sql);
    
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param("iiii", $image_count, $mob1, $mob2, $visit_id);
    
    if (!$stmt->execute()) {
        throw new Exception("Execute failed: " . $stmt->error);
    }
    
    $affected_rows = $stmt->affected_rows;
    $stmt->close();
    $conn->close();
    
    // Return success response
    echo json_encode([
        'success' => true,
        'message' => 'تم تحديث الزيارة بنجاح',
        'data' => [
            'visit_id' => $visit_id,
            'image_count' => $image_count,
            'mob1' => $mob1,
            'mob2' => $mob2,
            'affected_rows' => $affected_rows
        ]
    ]);
    
} catch (Exception $e) {
    // Return error response
    echo json_encode([
        'success' => false,
        'message' => 'خطأ في تحديث الزيارة: ' . $e->getMessage()
    ]);
}
?>
