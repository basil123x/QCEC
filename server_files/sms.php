<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Database connection (without including sql.php to avoid conflicts)
$conx = mysqli_connect("localhost", "mrthhzmy_erp2025", "A122%133zzzz", "mrthhzmy_erp2025");

if (!$conx) {
    die("Connection failed: " . mysqli_connect_error());
}

// Set charset to UTF-8
mysqli_set_charset($conx, "utf8");

// Sanitize function
function sanitize($input) {
    global $conx;
    return mysqli_real_escape_string($conx, trim($input));
}

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

$input = json_decode(file_get_contents('php://input'), true);
$action = $input['action'] ?? '';

switch ($action) {
    case 'get_visit_details':
        getVisitDetails($input);
        break;
    case 'send_sms':
        sendSMS($input);
        break;
    case 'send_whatsapp':
        sendWhatsApp($input);
        break;
    case 'generate_report':
        generateReport($input);
        break;
    default:
        sendResponse(false, 'Invalid action');
}

/**
 * جلب تفاصيل الزيارة والمشروع
 */
function getVisitDetails($input) {
    global $conx;
    
    error_log("getVisitDetails called with input: " . json_encode($input));
    
    if (!isset($input['visit_id'])) {
        sendResponse(false, 'معرف الزيارة مطلوب');
        return;
    }
    
    $visitId = sanitize($input['visit_id']);
    error_log("Sanitized visit ID: " . $visitId);
    
    $query = "SELECT 
                visits_det.id as visit_id,
                visits_det.a2 as description,
                visits_det.a4 as notes,
                visits_det.a5 as visit_date,
                visitsx.id as project_id,
                visitsx.a1 as customer_id,
                visitsx.a3 as contractor_id,
                visitsx.a4 as project_name,
                visitsx.a5 as location,
                visitsx.a6 as survey_number,
                customers.a1 as customer_name,
                customers.a2 as customer_phone,
                contractors.a1 as contractor_name,
                contractors.a3 as contractor_phone,
                'مهندس المشروع' as engineer_name
              FROM visits_det
              LEFT JOIN visitsx ON visits_det.a1 = visitsx.id
              LEFT JOIN customers ON visitsx.a1 = customers.id
              LEFT JOIN contractors ON visitsx.a3 = contractors.id
              WHERE visits_det.id = '$visitId'";
    
    error_log("Executing query: " . $query);
    $result = mysqli_query($conx, $query);
    
    if (!$result) {
        error_log("Database error: " . mysqli_error($conx));
        sendResponse(false, 'خطأ في قاعدة البيانات: ' . mysqli_error($conx));
        return;
    }
    
    if (mysqli_num_rows($result) == 0) {
        error_log("No visit found with ID: " . $visitId);
        sendResponse(false, 'الزيارة غير موجودة');
        return;
    }
    
    $visitData = mysqli_fetch_assoc($result);
    error_log("Visit data retrieved: " . json_encode($visitData));
    
    sendResponse(true, 'تم جلب تفاصيل الزيارة بنجاح', $visitData);
}

/**
 * إرسال رسالة SMS عبر Ooredoo
 */
function sendSMS($input) {
    if (!isset($input['phone']) || !isset($input['message'])) {
        sendResponse(false, 'رقم الهاتف والرسالة مطلوبان');
        return;
    }
    
    $phone = $input['phone'];
    $message = $input['message'];
    
    // إعدادات Ooredoo SMS
    $customerID = '7221';
    $userName = 'qcec';
    $userPassword = 'Qcec@8080';
    $originator = 'QCEC';
    
    // تنظيف رقم الهاتف
    $phone = preg_replace('/[^0-9]/', '', $phone);
    if (substr($phone, 0, 3) !== '974') {
        $phone = '974' . $phone;
    }
    
    // إنشاء URL للإرسال (GET request زي Postman)
    $url = "https://messaging.ooredoo.qa/bms/soap/Messenger.asmx/HTTP_SendSms?" . http_build_query([
        'customerID' => $customerID,
        'userName' => $userName,
        'userPassword' => $userPassword,
        'originator' => $originator,
        'smsText' => $message,
        'recipientPhone' => $phone,
        'messageType' => 'ArabicWithLatinNumbers', // نفس اللي في Postman
        'defDate' => '',
        'blink' => 'false',
        'flash' => 'false',
        'Private' => 'false'
    ]);
    
    error_log("SMS URL: " . $url);
    
    // جرب file_get_contents أول مرة
    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'timeout' => 60,
            'user_agent' => 'Mozilla/5.0 (compatible; SMS-Client/1.0)',
            'ignore_errors' => true
        ],
        'ssl' => [
            'verify_peer' => false,
            'verify_peer_name' => false
        ]
    ]);
    
    $response = @file_get_contents($url, false, $context);
    $httpCode = 200; // افتراض نجح إذا مافيش exception
    $error = '';
    
    if ($response === false) {
        // إذا فشل file_get_contents، جرب cURL
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPGET, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 60);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 20);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (compatible; SMS-Client/1.0)');
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);
    }
    
    error_log("SMS Response Code: $httpCode");
    error_log("SMS Response: " . substr($response, 0, 500));
    
    if ($error) {
        sendResponse(false, 'خطأ في الإرسال: ' . $error);
        return;
    }
    
    if ($httpCode == 200) {
        // تحليل الـ XML response
        if (strpos($response, '<Result>OK</Result>') !== false) {
            // استخراج Transaction ID
            preg_match('/<TransactionID>(.*?)<\/TransactionID>/', $response, $matches);
            $transactionId = isset($matches[1]) ? $matches[1] : 'N/A';
            
            sendResponse(true, 'تم إرسال الرسالة بنجاح', [
                'phone' => $phone,
                'transaction_id' => $transactionId,
                'response' => $response
            ]);
        } else {
            // فشل الإرسال حسب الـ XML
            sendResponse(false, 'فشل في إرسال الرسالة', [
                'phone' => $phone,
                'response' => $response
            ]);
        }
    } else {
        sendResponse(false, 'فشل في الإرسال - كود الخطأ: ' . $httpCode, [
            'phone' => $phone,
            'response' => $response
        ]);
    }
}

/**
 * إرسال رسالة WhatsApp عبر Wasender API
 */
function sendWhatsApp($input) {
    if (!isset($input['phone']) || !isset($input['message'])) {
        sendResponse(false, 'رقم الهاتف والرسالة مطلوبان');
        return;
    }
    
    $phone = $input['phone'];
    $message = $input['message'];
    $documentUrl = $input['document_url'] ?? null;
    $fileName = $input['file_name'] ?? null;
    
    $apiKey = 'c59e7748d6bd6d086bfae052e04027a71f9eb7083594b488d90dea00b02d1260';
    
    // تنظيف رقم الهاتف
    $phone = preg_replace('/[^0-9]/', '', $phone);
    if (substr($phone, 0, 3) !== '974') {
        $phone = '974' . $phone;
    }
    $phone = '+' . $phone;
    
    // إعداد البيانات
    $data = [
        'to' => $phone,
        'text' => $message
    ];
    
    // إضافة المستند إذا كان موجود
    if ($documentUrl && $fileName) {
        $data['documentUrl'] = $documentUrl;
        $data['fileName'] = $fileName;
    }
    
    // إرسال الطلب
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'https://www.wasenderapi.com/api/send-message');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $apiKey,
        'Content-Type: application/json'
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    if ($error) {
        sendResponse(false, 'خطأ في الإرسال: ' . $error);
        return;
    }
    
    if ($httpCode == 200) {
        sendResponse(true, 'تم إرسال الرسالة بنجاح', [
            'phone' => $phone,
            'response' => json_decode($response, true)
        ]);
    } else {
        sendResponse(false, 'فشل في الإرسال - كود الخطأ: ' . $httpCode);
    }
}

/**
 * تكوين تقرير الزيارة
 */
function generateReport($input) {
    if (!isset($input['visit_id'])) {
        sendResponse(false, 'معرف الزيارة مطلوب');
        return;
    }
    
    // جلب تفاصيل الزيارة
    $visitDetails = getVisitDetailsInternal($input['visit_id']);
    if (!$visitDetails) {
        sendResponse(false, 'لم يتم العثور على تفاصيل الزيارة');
        return;
    }
    
    // تكوين نص التقرير
    $reportText = formatReportMessage($visitDetails);
    
    sendResponse(true, 'تم تكوين التقرير بنجاح', [
        'visit_details' => $visitDetails,
        'report_text' => $reportText
    ]);
}

/**
 * جلب تفاصيل الزيارة داخلياً
 */
function getVisitDetailsInternal($visitId) {
    global $conx;
    
    $visitId = sanitize($visitId);
    
    $query = "SELECT 
                visits_det.id as visit_id,
                visits_det.a2 as description,
                visits_det.a4 as notes,
                visits_det.a5 as visit_date,
                visitsx.id as project_id,
                visitsx.a4 as project_name,
                visitsx.a5 as location,
                visitsx.a6 as survey_number,
                customers.a1 as customer_name,
                customers.a2 as customer_phone,
                contractors.a1 as contractor_name,
                contractors.a3 as contractor_phone,
                'مهندس المشروع' as engineer_name
              FROM visits_det
              LEFT JOIN visitsx ON visits_det.a1 = visitsx.id
              LEFT JOIN customers ON visitsx.a1 = customers.id
              LEFT JOIN contractors ON visitsx.a3 = contractors.id
              WHERE visits_det.id = '$visitId'";
    
    $result = mysqli_query($conx, $query);
    
    if ($result && mysqli_num_rows($result) > 0) {
        return mysqli_fetch_assoc($result);
    }
    
    return null;
}

/**
 * تنسيق رسالة التقرير
 */
function formatReportMessage($visitDetails) {
    $visitDate = date('d-m-Y - h:i A', strtotime($visitDetails['visit_date']));
    $currentDate = date('Y-m-d');
    
    $message = "{$visitDate} {$currentDate}\n";
    $message .= "    العميل: {$visitDetails['customer_name']}\n";
    $message .= "    المشروع: {$visitDetails['project_name']}\n";
    $message .= "    المنطقة: {$visitDetails['location']}\n";
    $message .= "    الرقم المساحي: {$visitDetails['survey_number']}\n";
    $message .= "    المقاول: {$visitDetails['contractor_name']}\n";
    $message .= "    الاستشاري: {$visitDetails['engineer_name']}\n";
    $message .= "    الوصف: {$visitDetails['description']}\n";
    $message .= "    التفاصيل: {$visitDetails['notes']}";
    
    return $message;
}

/**
 * إرسال الاستجابة
 */
function sendResponse($success, $message, $data = null) {
    $response = [
        'success' => $success,
        'message' => $message
    ];
    
    if ($data !== null) {
        $response['data'] = $data;
    }
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    exit;
}
?>
