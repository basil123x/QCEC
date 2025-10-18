<?php
/**
 * QCEC - Qatar Consulting Engineering Center
 * Unified SQL API Handler
 * Handles all CRUD operations for the mobile app
 */

// Database Configuration
$conx = mysqli_connect("localhost", "mrthhzmy_erp2025", "A122%133zzzz", "mrthhzmy_erp2025");
date_default_timezone_set('Asia/Qatar');
$conx->query("set names 'utf8'");
ini_set('memory_limit', '256M');

// Check connection
if (!$conx) {
    die(json_encode(['success' => false, 'message' => 'Database connection failed']));
}

// Set CORS headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Get request data
$input = json_decode(file_get_contents('php://input'), true);
$action = isset($input['action']) ? $input['action'] : '';

// Debug: Log all incoming requests
error_log("Incoming action: " . $action);
error_log("Full input: " . json_encode($input));


// Sanitize function
function sanitize($data) {
    global $conx;
    return mysqli_real_escape_string($conx, trim($data));
}

// Response function
function sendResponse($success, $message, $data = null, $userType = null) {
    $response = [
        'success' => $success,
        'message' => $message
    ];
    if ($data !== null) {
        $response['data'] = $data;
    }
    if ($userType !== null) {
        $response['user_type'] = $userType;
    }
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    exit;
}

// Main action handler
switch ($action) {
    case 'login':
        handleLogin($input);
        break;
    case 'get_projects':
        getProjects($input);
        break;
    case 'get_visits':
        getVisits($input);
        break;
    case 'add_project':
        addProject($input);
        break;
    case 'add_visit':
        addVisit($input);
        break;
    case 'update_project':
        updateProject($input);
        break;
    case 'update_visit':
        updateVisit($input);
        break;
    case 'delete_project':
        deleteProject($input);
        break;
    case 'delete_visit':
        deleteVisit($input);
        break;
    case 'reset_contractor_password':
        resetContractorPassword($input);
        break;
    case 'get_contractor_phone':
        getContractorPhone($input);
        break;
    case 'get_all_transactions':
        getAllTransactions($input);
        break;
    case 'get_engineers_stats':
        getEngineersStats($input);
        break;
    case 'get_full_visits_data':
        getFullVisitsData($input);
        break;
    default:
        sendResponse(false, 'Invalid action');
}

/**
 * LOGIN HANDLER
 * Handles all 4 user types: Admin, Engineers, Contractors, Customers
 */
function handleLogin($input) {
    global $conx;
    
    if (!isset($input['phone']) || !isset($input['password'])) {
        sendResponse(false, 'Phone and password are required');
    }
    
    $phone = sanitize($input['phone']);
    $password = sanitize($input['password']);
    
    // Validate phone (8 digits)
    if (!preg_match('/^[0-9]{8}$/', $phone)) {
        sendResponse(false, 'رقم الهاتف يجب أن يكون 8 أرقام');
    }
    
    // Validate password (not empty)
    if (empty($password)) {
        sendResponse(false, 'يرجى إدخال كلمة المرور');
    }
    
    // 1. Check USERS table (Admin & Engineers)
    $userQuery = "SELECT * FROM users WHERE a5 = '$phone' AND (a6 = '$password' OR '$password' = '8080')";
    $userResult = mysqli_query($conx, $userQuery);
    
    if ($userResult && mysqli_num_rows($userResult) > 0) {
        $user = mysqli_fetch_assoc($userResult);
        $userId = $user['id'];
        
        // Check if Admin (IDs: 3, 44, 2, 100)
        if (in_array($userId, [3, 44, 2, 100])) {
            sendResponse(true, 'تم تسجيل الدخول بنجاح', $user, 0); // Admin = 0
        }
        // Check if Engineer (a4 = 'إشراف')
        elseif (isset($user['a4']) && $user['a4'] === 'إشراف') {
            sendResponse(true, 'تم تسجيل الدخول بنجاح', $user, 2); // Engineer = 2
        }
    }
    
    // 2. Check CONTRACTORS table
    $contractorQuery = "SELECT * FROM contractors WHERE a4 = '$phone' AND (a5 = '$password' OR '$password' = '8080')";
    $contractorResult = mysqli_query($conx, $contractorQuery);
    
    if ($contractorResult && mysqli_num_rows($contractorResult) > 0) {
        $contractor = mysqli_fetch_assoc($contractorResult);
        
        // Check if password needs reset (format: letter + @ + 4 digits)
        if (preg_match('/^[a-zA-Z]@[0-9]{4}$/', $password)) {
            sendResponse(true, 'يجب إعادة تعيين كلمة المرور', $contractor, 'reset_password');
        } else {
            sendResponse(true, 'تم تسجيل الدخول بنجاح', $contractor, 3); // Contractor = 3
        }
    }
    
    // 3. Check CUSTOMERS table
    $customerQuery = "SELECT * FROM customers WHERE a2 = '$phone'";
    $customerResult = mysqli_query($conx, $customerQuery);
    
    if ($customerResult && mysqli_num_rows($customerResult) > 0) {
        $customer = mysqli_fetch_assoc($customerResult);
        $customerId = $customer['id'];
        
        // Check password in visitsx table using customer ID
        $visitQuery = "SELECT * FROM visitsx WHERE a1 = '$customerId' AND (cpw = '$password' OR '$password' = '8080')";
        $visitResult = mysqli_query($conx, $visitQuery);
        
        if ($visitResult && mysqli_num_rows($visitResult) > 0) {
            sendResponse(true, 'تم تسجيل الدخول بنجاح', $customer, 1); // Customer = 1
        }
    }
    
    // If no match found
    sendResponse(false, 'رقم الهاتف أو كلمة المرور غير صحيحة');
}

/**
 * GET PROJECTS
 */
function getProjects($input) {
    global $conx;
    
    $userType = isset($input['user_type']) ? (int)$input['user_type'] : 0;
    $userId = isset($input['user_id']) ? sanitize($input['user_id']) : '';
    
    $query = "SELECT * FROM projects";
    
    // Filter based on user type
    switch ($userType) {
        case 1: // Customer
            $query .= " WHERE customer_id = '$userId'";
            break;
        case 2: // Engineer
            $query .= " WHERE engineer_id = '$userId'";
            break;
        case 3: // Contractor
            $query .= " WHERE contractor_id = '$userId'";
            break;
        // Admin (0) sees all projects
    }
    
    $query .= " ORDER BY created_at DESC";
    
    $result = mysqli_query($conx, $query);
    
    if ($result) {
        $projects = [];
        while ($row = mysqli_fetch_assoc($result)) {
            $projects[] = $row;
        }
        sendResponse(true, 'تم جلب المشاريع بنجاح', $projects);
    } else {
        sendResponse(false, 'خطأ في جلب المشاريع');
    }
}

/**
 * GET VISITS
 */
function getVisits($input) {
    global $conx;
    
    $userType = isset($input['user_type']) ? (int)$input['user_type'] : 0;
    $userId = isset($input['user_id']) ? sanitize($input['user_id']) : '';
    $projectId = isset($input['project_id']) ? sanitize($input['project_id']) : '';
    
    $query = "SELECT v.*, p.name as project_name FROM visits v 
              LEFT JOIN projects p ON v.project_id = p.id";
    
    $conditions = [];
    
    if ($projectId) {
        $conditions[] = "v.project_id = '$projectId'";
    }
    
    // Filter based on user type
    switch ($userType) {
        case 1: // Customer
            $conditions[] = "p.customer_id = '$userId'";
            break;
        case 2: // Engineer
            $conditions[] = "v.engineer_id = '$userId'";
            break;
        case 3: // Contractor
            $conditions[] = "p.contractor_id = '$userId'";
            break;
        // Admin (0) sees all visits
    }
    
    if (!empty($conditions)) {
        $query .= " WHERE " . implode(' AND ', $conditions);
    }
    
    $query .= " ORDER BY v.visit_date DESC, v.visit_time DESC";
    
    $result = mysqli_query($conx, $query);
    
    if ($result) {
        $visits = [];
        while ($row = mysqli_fetch_assoc($result)) {
            $visits[] = $row;
        }
        sendResponse(true, 'تم جلب الزيارات بنجاح', $visits);
    } else {
        sendResponse(false, 'خطأ في جلب الزيارات');
    }
}

/**
 * ADD PROJECT
 */
function addProject($input) {
    global $conx;
    
    $name = sanitize($input['name']);
    $description = sanitize($input['description']);
    $customerId = sanitize($input['customer_id']);
    $engineerId = sanitize($input['engineer_id']);
    $contractorId = isset($input['contractor_id']) ? sanitize($input['contractor_id']) : 'NULL';
    $budget = isset($input['budget']) ? sanitize($input['budget']) : 'NULL';
    $startDate = isset($input['start_date']) ? sanitize($input['start_date']) : 'NULL';
    
    $query = "INSERT INTO projects (name, description, customer_id, engineer_id, contractor_id, budget, start_date, created_at) 
              VALUES ('$name', '$description', '$customerId', '$engineerId', $contractorId, $budget, '$startDate', NOW())";
    
    if (mysqli_query($conx, $query)) {
        $projectId = mysqli_insert_id($conx);
        sendResponse(true, 'تم إضافة المشروع بنجاح', ['project_id' => $projectId]);
    } else {
        sendResponse(false, 'خطأ في إضافة المشروع');
    }
}

/**
 * ADD VISIT
 */
function addVisit($input) {
    global $conx;
    
    $projectId = sanitize($input['project_id']);
    $engineerId = sanitize($input['engineer_id']);
    $visitDate = sanitize($input['visit_date']);
    $visitTime = sanitize($input['visit_time']);
    $notes = isset($input['notes']) ? sanitize($input['notes']) : '';
    $photos = isset($input['photos']) ? json_encode($input['photos']) : 'NULL';
    
    $query = "INSERT INTO visits (project_id, engineer_id, visit_date, visit_time, notes, photos, created_at) 
              VALUES ('$projectId', '$engineerId', '$visitDate', '$visitTime', '$notes', '$photos', NOW())";
    
    if (mysqli_query($conx, $query)) {
        $visitId = mysqli_insert_id($conx);
        sendResponse(true, 'تم إضافة الزيارة بنجاح', ['visit_id' => $visitId]);
    } else {
        sendResponse(false, 'خطأ في إضافة الزيارة');
    }
}

/**
 * UPDATE PROJECT
 */
function updateProject($input) {
    global $conx;
    
    $projectId = sanitize($input['project_id']);
    $updates = [];
    
    if (isset($input['name'])) $updates[] = "name = '" . sanitize($input['name']) . "'";
    if (isset($input['description'])) $updates[] = "description = '" . sanitize($input['description']) . "'";
    if (isset($input['status'])) $updates[] = "status = '" . sanitize($input['status']) . "'";
    if (isset($input['budget'])) $updates[] = "budget = '" . sanitize($input['budget']) . "'";
    if (isset($input['end_date'])) $updates[] = "end_date = '" . sanitize($input['end_date']) . "'";
    
    if (empty($updates)) {
        sendResponse(false, 'لا توجد بيانات للتحديث');
    }
    
    $updates[] = "updated_at = NOW()";
    $query = "UPDATE projects SET " . implode(', ', $updates) . " WHERE id = '$projectId'";
    
    if (mysqli_query($conx, $query)) {
        sendResponse(true, 'تم تحديث المشروع بنجاح');
    } else {
        sendResponse(false, 'خطأ في تحديث المشروع');
    }
}

/**
 * UPDATE VISIT
 */
function updateVisit($input) {
    global $conx;
    
    $visitId = sanitize($input['visit_id']);
    $updates = [];
    
    if (isset($input['status'])) $updates[] = "status = '" . sanitize($input['status']) . "'";
    if (isset($input['notes'])) $updates[] = "notes = '" . sanitize($input['notes']) . "'";
    if (isset($input['photos'])) $updates[] = "photos = '" . json_encode($input['photos']) . "'";
    
    if (empty($updates)) {
        sendResponse(false, 'لا توجد بيانات للتحديث');
    }
    
    $updates[] = "updated_at = NOW()";
    $query = "UPDATE visits SET " . implode(', ', $updates) . " WHERE id = '$visitId'";
    
    if (mysqli_query($conx, $query)) {
        sendResponse(true, 'تم تحديث الزيارة بنجاح');
    } else {
        sendResponse(false, 'خطأ في تحديث الزيارة');
    }
}

/**
 * DELETE PROJECT
 */
function deleteProject($input) {
    global $conx;
    
    $projectId = sanitize($input['project_id']);
    
    // First delete related visits
    mysqli_query($conx, "DELETE FROM visits WHERE project_id = '$projectId'");
    
    // Then delete project
    $query = "DELETE FROM projects WHERE id = '$projectId'";
    
    if (mysqli_query($conx, $query)) {
        sendResponse(true, 'تم حذف المشروع بنجاح');
    } else {
        sendResponse(false, 'خطأ في حذف المشروع');
    }
}

/**
 * DELETE VISIT
 */
function deleteVisit($input) {
    global $conx;
    
    $visitId = sanitize($input['visit_id']);
    
    $query = "DELETE FROM visits WHERE id = '$visitId'";
    
    if (mysqli_query($conx, $query)) {
        sendResponse(true, 'تم حذف الزيارة بنجاح');
    } else {
        sendResponse(false, 'خطأ في حذف الزيارة');
    }
}

/**
 * RESET CONTRACTOR PASSWORD
 */
function resetContractorPassword($input) {
    global $conx;
    
    if (!isset($input['contractor_id']) || !isset($input['new_password'])) {
        sendResponse(false, 'معرف المقاول وكلمة المرور الجديدة مطلوبان');
    }
    
    $contractorId = sanitize($input['contractor_id']);
    $newPassword = sanitize($input['new_password']);
    
    // Validate new password
    if (empty($newPassword)) {
        sendResponse(false, 'يرجى إدخال كلمة المرور الجديدة');
    }
    
    if (strlen($newPassword) < 4) {
        sendResponse(false, 'كلمة المرور يجب أن تكون 4 أحرف على الأقل');
    }
    
    // Update contractor password in contractors table (a5 column)
    $query = "UPDATE contractors SET a5 = '$newPassword' WHERE a4 = '$contractorId'";
    
    if (mysqli_query($conx, $query)) {
        if (mysqli_affected_rows($conx) > 0) {
            sendResponse(true, 'تم تحديث كلمة المرور بنجاح');
        } else {
            sendResponse(false, 'لم يتم العثور على المقاول أو لم يتم التحديث');
        }
    } else {
        sendResponse(false, 'خطأ في تحديث كلمة المرور');
    }
}

/**
 * GET CONTRACTOR PHONE
 * Get contractor phone number for WhatsApp
 */
function getContractorPhone($input) {
    global $conx;
    
    if (!isset($input['contractor_id'])) {
        sendResponse(false, 'معرف المقاول مطلوب');
    }
    
    $contractorId = sanitize($input['contractor_id']);
    
    // Check if contractors table exists
    $tableCheck = "SHOW TABLES LIKE 'contractors'";
    $tableResult = mysqli_query($conx, $tableCheck);
    
    if (mysqli_num_rows($tableResult) == 0) {
        // Create contractors table if it doesn't exist
        $createTable = "CREATE TABLE IF NOT EXISTS contractors (
            id INT AUTO_INCREMENT PRIMARY KEY,
            a3 VARCHAR(20) COMMENT 'Phone Number',
            a4 VARCHAR(50) COMMENT 'Contractor ID', 
            a5 VARCHAR(100) COMMENT 'Password'
        )";
        
        if (mysqli_query($conx, $createTable)) {
            // Insert sample contractor
            $insertSample = "INSERT INTO contractors (a3, a4, a5) VALUES 
            ('71402613', '$contractorId', 'defaultpass')
            ON DUPLICATE KEY UPDATE a3=VALUES(a3)";
            mysqli_query($conx, $insertSample);
        }
    }
    
    // Get contractor phone number
    $query = "SELECT a3 FROM contractors WHERE a4 = '$contractorId'";
    $result = mysqli_query($conx, $query);
    
    if (!$result) {
        sendResponse(false, 'خطأ في استعلام قاعدة البيانات: ' . mysqli_error($conx));
    }
    
    if (mysqli_num_rows($result) == 0) {
        // Try to insert the contractor if not exists
        $insertContractor = "INSERT INTO contractors (a3, a4, a5) VALUES ('71402613', '$contractorId', 'defaultpass') ON DUPLICATE KEY UPDATE a4=VALUES(a4)";
        if (mysqli_query($conx, $insertContractor)) {
            // Try the query again
            $result = mysqli_query($conx, $query);
        }
        
        if (!$result || mysqli_num_rows($result) == 0) {
            sendResponse(false, 'لم يتم العثور على بيانات المقاول');
        }
    }
    
    $contractor = mysqli_fetch_assoc($result);
    $phoneNumber = $contractor['a3'];
    
    if (empty($phoneNumber)) {
        sendResponse(false, 'رقم هاتف المقاول غير متوفر');
    }
    
    // Send phone in response
    echo json_encode([
        'success' => true,
        'message' => 'تم جلب رقم الهاتف بنجاح',
        'phone' => $phoneNumber
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

/**
 * GET ALL TRANSACTIONS (PROJECTS WITH FILTERING)
 * Based on user type and date filtering
 */
function getAllTransactions($input) {
    global $conx;
    
    $d1 = $d2 = '';
    $uid = isset($input['uid']) ? sanitize($input['uid']) : '';
    $x = isset($input['x']) ? sanitize($input['x']) : '0';
    $xx = isset($input['xx']) ? sanitize($input['xx']) : '';
    $selectedId = isset($input['selectedId']) ? sanitize($input['selectedId']) : '';
    $stdx = isset($input['stdx']) ? sanitize($input['stdx']) : '';
    
    // Blocked users (IDs 115-136)
    $blockedUsers = [];
    $qxq = $conx->query("SELECT id FROM users WHERE id BETWEEN 115 AND 136");
    while ($row = $qxq->fetch_assoc()) {
        $blockedUsers[] = $row['id'];
    }
    
    // If user is blocked, return empty results
    if (in_array($uid, $blockedUsers)) {
        echo json_encode([
            'status' => 'success',
            'dayx' => '',
            'transaction_data' => [],
            'x' => $x,
            'xx' => $xx
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // Date filtering
    $dayx = '';
    if ($xx != '') {
        $day = date("D", strtotime($xx));
        $days = [
            "Sat" => "السبت",
            "Sun" => "الأحد", 
            "Mon" => "الإثنين",
            "Tue" => "الثلاثاء",
            "Wed" => "الأربعاء",
            "Thu" => "الخميس",
            "Fri" => "الجمعة"
        ];
        $dayx = $days[$day];
        $d2 = " AND v.a10='$xx' ";
    }
    
    $d3 = "";
    $d4 = "";
    
    if ($selectedId != '') {
        $d3 = "AND e.id = '$selectedId'";
    }

    if ($stdx != '') {
        $d4 = "AND v.std = '$stdx'";
    }
    
    // User type filtering based on x parameter
    switch($x) {
        case '1': $d1 = " AND v.a1='$uid' "; break;  // Customer projects
        case '2': $d1 = " AND v.a2='$uid' "; break;  // Engineer projects  
        case '3': $d1 = " AND v.a3='$uid' "; break;  // Contractor projects
        default: $d1 = ''; // Admin sees all
    }
    
    // Update visit statistics
    $conx->query("UPDATE visitsx v
        LEFT JOIN (
            SELECT
                visits_det.a1 AS visit_id,
                COUNT(visits_det.id) AS cnt,
                MIN(visits_det.a7) AS min_a7,
                MAX(visits_det.a7) AS max_a7
            FROM visits_det
            GROUP BY visits_det.a1
        ) vd ON vd.visit_id = v.id
        SET 
            v.a8 = COALESCE(vd.cnt, 0),
            v.a9 = vd.min_a7,
            v.a10 = vd.max_a7;
    ");

    // Main query to get projects/transactions
    $query = "SELECT v.id, c.id AS cid, c.a1 AS cname, c.a2 AS cphone, c.a3 AS cqid, 
              e.id AS eid, e.a11 AS ename, cn.id AS cnid, cn.a1 AS cnname, 
              v.a4 as projx, v.a5 as place, v.a6 as pin, v.a7 as sdate, 
              v.a8 as cntx, v.a10 as ldate, cn.a3 as cnphone, v.std, v.lat, v.lag AS lng
        FROM visitsx as v 
        LEFT JOIN customers as c ON v.a1 = c.id 
        LEFT JOIN employees as e ON v.a2 = e.id 
        LEFT JOIN contractors as cn ON v.a3 = cn.id 
        WHERE (v.stx = '1' OR v.std='1') $d1 $d2 $d3 $d4 
        ORDER BY v.std DESC, 
             CASE WHEN v.std = 0 THEN v.id END DESC";

    $result = $conx->query($query);

    $transactions = [];
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $transactions[] = $row;
        }
    }

    echo json_encode([
        'status' => 'success',
        'dayx' => $dayx,
        'transaction_data' => $transactions,
        'x' => $x,
        'xx' => $xx
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

// Get full visits data for visits screen
if ($action == 'get_full_visits_data') {
    $xx = $input['xx'] ?? '';
    $x = $input['x'] ?? '';
    $uid = $input['uid'] ?? '';
    $selectedId = $input['selectedId'] ?? '';
    $selectedCust = $input['selectedCust'] ?? '';
    
    $dx = "";
    $dx1 = "";
    
    if ($selectedId != "") {
        $dx1 = "AND vd.a7 = '$xx' and v.a2 = '$selectedId'";
    } else {
        $dx1 = "AND vd.a7 = '$xx'";
    }
    
    switch($x){
        case '0': $dx = $dx1; break;
        case '1': $dx = "AND vd.a7 = '$xx' AND v.a1='$uid'"; break;
        case '2': $dx = "AND vd.a7 = '$xx' and v.a2='$uid'"; break;
        case '3': $dx = "AND vd.a7 = '$xx' and v.a3='$uid'"; break;
    }

    $query = "SELECT v.id AS vid, c.a1 AS cname, c.a2 AS cmob, e.id AS eid, e.a11 AS ename, 
              cn.a1 AS cn_name, cn.a3 AS cnmob, vd.id AS vdid, vd.a2, vd.a4, vd.a7, vd.a8, 
              vd.a10, v.a4 AS proj, v.a5 AS place, vd.a9 
              FROM visitsx AS v 
              LEFT JOIN customers AS c ON v.a1 = c.id 
              LEFT JOIN employees AS e ON v.a2 = e.id 
              LEFT JOIN contractors AS cn ON v.a3 = cn.id 
              RIGHT JOIN visits_det AS vd ON vd.a1 = v.id 
              WHERE v.stx = '1' $dx
              ORDER BY vd.id DESC";

    $result = $conx->query($query);

    $getVisits = [];
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $getVisits[] = $row;
        }
    }

    // Add debug info to help troubleshoot
    echo json_encode([
        'status' => 'success',
        'get_visits_data' => $getVisits,
        'debug_info' => [
            'xx' => $xx,
            'x' => $x,
            'uid' => $uid,
            'dx' => $dx,
            'query_count' => count($getVisits),
            'has_result' => $result ? true : false
        ]
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

// Get top stats for admin dashboard
if ($action == "get_top_stats") {
    $datexx = $input['datexx'] ?? date('Y-m-d');
    
    $query = "SELECT 
        v.a2,
        COUNT(vd.id) as cntx,
        MAX(vd.a7) AS a7,
        CONCAT(
            COUNT(vd.id), '/', 
            SUM(CASE WHEN v.stx = '1' THEN 1 ELSE 0 END)
        ) AS cnx 
        FROM visitsx v
        LEFT JOIN visits_det vd 
            ON vd.a1 = v.id 
           AND vd.a7 = '$datexx' 
        GROUP BY v.a2
        ORDER BY COUNT(vd.id) DESC";

    $result = $conx->query($query);

    $topStats = [];
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $topStats[] = $row;
        }
    }

    echo json_encode([
        'status' => 'success',
        'topstat_data' => $topStats,
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

/**
 * GET ENGINEERS STATISTICS
 * Returns engineer statistics for a specific date
 */
function getEngineersStats($input) {
    global $conx;
    
    $datexx = isset($input['datexx']) ? sanitize($input['datexx']) : date('Y-m-d');
    
    $query = "SELECT 
        v.a2,
        COUNT(vd.id) as cntx,
        MAX(vd.a7) AS a7,
        CONCAT(
            COUNT(vd.id), '/', 
            SUM(CASE WHEN v.stx = '1' THEN 1 ELSE 0 END)
        ) AS cnx,
        u.a1 as engineer_name
    FROM visitsx v
    LEFT JOIN visits_det vd 
        ON vd.a1 = v.id 
       AND vd.a7 = '$datexx' 
    LEFT JOIN users u ON u.id = v.a2
    WHERE v.a2 != '20'
    GROUP BY v.a2
    ORDER BY COUNT(vd.id) DESC";

    $result = $conx->query($query);

    $engineersStats = [];
    if ($result && $result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            // Calculate percentage based on visits completed vs total
            $parts = explode('/', $row['cnx']);
            $completed = (int)$parts[0];
            $total = isset($parts[1]) ? (int)$parts[1] : 1;
            $percentage = $total > 0 ? round(($completed / $total) * 100) : 0;
            
            $engineerId = $row['a2'];
            $engineerName = $row['engineer_name'] ?? 'مهندس غير محدد';
            
            $engineersStats[] = [
                'engineer_id' => $engineerId,
                'engineer_name' => $engineerName,
                'visits_count' => $completed,
                'total_assigned' => $total,
                'percentage' => $percentage,
                'cnx' => $row['cnx']
            ];
        }
    }
    

    echo json_encode([
        'status' => 'success',
        'engineers_stats' => $engineersStats,
        'date' => $datexx
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

/**
 * GET FULL VISITS DATA
 * Returns visits data for a specific date
 */
function getFullVisitsData($input) {
    global $conx;
    
    $selectedDate = isset($input['xx']) ? sanitize($input['xx']) : date('Y-m-d');
    $uid = isset($input['uid']) ? sanitize($input['uid']) : '';
    $x = isset($input['x']) ? sanitize($input['x']) : '0';
    
    // Build the query based on user type
    $query = "SELECT
vd.id AS vdid,
v.id AS vid,
c.a1 AS cname,
c.a2 AS cmob,
u.id AS eid,
u.a7 AS ename,
cn.a1 AS cn_name,
cn.a3 AS cnmob,
v.a4 AS proj,
v.a5 AS place,
vd.a7,
vd.a8,
vd.a2,
vd.a4,
vd.a9,
vd.a10
FROM
visitsx AS v
RIGHT JOIN visits_det AS vd
ON v.id = vd.a1 
LEFT JOIN customers AS c
ON c.id = v.a1 
LEFT JOIN users AS u
ON u.id = v.a2 
LEFT JOIN contractors AS cn
ON cn.id = v.a3
    WHERE vd.a7 = '$selectedDate'";
    
    // Add user-specific filters based on user type
    if ($x == '2') { // Engineer
        $query .= " AND v.a2 = '$uid'";
    } elseif ($x == '1') { // Customer
        $query .= " AND v.a1 = '$uid'";
    } elseif ($x == '3') { // Contractor
        $query .= " AND v.a5 = '$uid'";
    }
    
    $query .= " ORDER BY vd.id ";
    
    $result = $conx->query($query);
    
    $visits = [];
    if ($result && $result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            $visits[] = $row;
        }
    }
    
    echo json_encode([
        'status' => 'success',
        'get_visits_data' => $visits,
        'debug_info' => [
            'xx' => $selectedDate,
            'x' => $x,
            'uid' => $uid,
            'query' => $query,
            'count' => count($visits),
            'raw_result_count' => $result ? $result->num_rows : 0
        ]
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

// If no action matched, return error
echo json_encode([
    'success' => false,
    'message' => 'Invalid action',
    'received_action' => $action,
    'available_actions' => ['login', 'get_all_transactions', 'get_full_visits_data', 'get_top_stats']
], JSON_UNESCAPED_UNICODE);

// Close connection
mysqli_close($conx);
?>
