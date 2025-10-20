<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

// إعدادات S3 - استخدام cURL بدلاً من SDK
$bucket = 'visitsqcecs';
$region = 'ap-south-1';
$accessKey = 'AKIAQWMEFJJ5WO2SJQWS';
$secretKey = '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';

// معالجة الطلبات
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
    case 'upload_visit_images':
        uploadVisitImages($input);
        break;
    case 'upload_pdf':
        uploadPDF($input);
        break;
    case 'delete_visit_images':
        deleteVisitImages($input);
        break;
    default:
        sendResponse(false, 'Invalid action');
}

/**
 * رفع صور الزيارة إلى S3
 */
function uploadVisitImages($input) {
    global $bucket, $region, $accessKey, $secretKey;
    
    try {
        error_log("Upload request received for visit: " . ($input['visit_id'] ?? 'unknown'));
        
        if (!isset($input['visit_id']) || !isset($input['images'])) {
            sendResponse(false, 'معرف الزيارة والصور مطلوبان');
            return;
        }
        
        $visitId = $input['visit_id'];
        $images = $input['images'];
        $uploadedImages = [];
        $errors = [];
        
        error_log("Processing " . count($images) . " images for visit " . $visitId);
        
        foreach ($images as $index => $imageData) {
            try {
                $imageContent = base64_decode($imageData);
                
                if ($imageContent === false) {
                    $errors[] = "فشل في فك تشفير الصورة رقم " . ($index + 1);
                    continue;
                }
                
                $imageNumber = $index + 1;
                $s3Key = "visits/{$visitId}/{$imageNumber}.jpg";
                
                // رفع الصورة باستخدام cURL
                $result = uploadToS3WithCurl($bucket, $s3Key, $imageContent, $region, $accessKey, $secretKey);
                
                if ($result['success']) {
                    $uploadedImages[] = [
                        'number' => $imageNumber,
                        'url' => "https://{$bucket}.s3.{$region}.amazonaws.com/{$s3Key}",
                        's3_key' => $s3Key
                    ];
                    error_log("Successfully uploaded image " . $imageNumber);
                } else {
                    $errors[] = "فشل رفع الصورة رقم " . ($index + 1) . ": " . $result['error'];
                    error_log("Failed to upload image " . $imageNumber . ": " . $result['error']);
                }
                
            } catch (Exception $e) {
                $error_msg = "خطأ في رفع الصورة رقم " . ($index + 1) . ": " . $e->getMessage();
                $errors[] = $error_msg;
                error_log("Exception: " . $error_msg);
            }
        }
        
        if (count($uploadedImages) > 0) {
            sendResponse(true, 'تم رفع ' . count($uploadedImages) . ' صورة بنجاح', [
                'uploaded_images' => $uploadedImages,
                'errors' => $errors,
                'total_uploaded' => count($uploadedImages),
                'total_errors' => count($errors)
            ]);
        } else {
            sendResponse(false, 'فشل في رفع جميع الصور', ['errors' => $errors]);
        }
        
    } catch (Exception $e) {
        error_log("Fatal error in uploadVisitImages: " . $e->getMessage());
        sendResponse(false, 'خطأ خطير في السيرفر: ' . $e->getMessage());
    }
}

/**
 * رفع PDF إلى S3
 */
function uploadPDF($input) {
    global $bucket, $region, $accessKey, $secretKey;
    
    try {
        error_log("PDF upload request received for visit: " . ($input['visit_id'] ?? 'unknown'));
        
        if (!isset($input['visit_id']) || !isset($input['pdf_data']) || !isset($input['date']) || !isset($input['file_name'])) {
            sendResponse(false, 'معرف الزيارة وبيانات PDF والتاريخ واسم الملف مطلوبان');
            return;
        }
        
        $visitId = $input['visit_id'];
        $pdfData = $input['pdf_data'];
        $date = $input['date'];
        $fileName = $input['file_name'];
        
        error_log("Processing PDF upload for visit $visitId on date $date");
        
        // فك تشفير PDF من base64
        $pdfContent = base64_decode($pdfData);
        
        if ($pdfContent === false) {
            sendResponse(false, 'فشل في فك تشفير ملف PDF');
            return;
        }
        
        // تحديد مسار PDF في S3
        $s3Key = "whatsapp/{$visitId}/{$date}/{$fileName}";
        
        // رفع PDF إلى S3 باستخدام cURL
        $result = uploadToS3WithCurl($bucket, $s3Key, $pdfContent, $region, $accessKey, $secretKey, 'application/pdf');
        
        if ($result['success']) {
            $pdfUrl = "https://{$bucket}.s3.{$region}.amazonaws.com/{$s3Key}";
            
            sendResponse(true, 'تم رفع ملف PDF بنجاح', [
                'url' => $pdfUrl,
                's3_key' => $s3Key,
                'file_name' => $fileName,
                'visit_id' => $visitId,
                'date' => $date
            ]);
            
            error_log("Successfully uploaded PDF: " . $pdfUrl);
        } else {
            sendResponse(false, 'فشل رفع ملف PDF: ' . $result['error']);
            error_log("Failed to upload PDF: " . $result['error']);
        }
        
    } catch (Exception $e) {
        $error_msg = "خطأ في رفع ملف PDF: " . $e->getMessage();
        error_log("Exception: " . $error_msg);
        sendResponse(false, $error_msg);
    }
}

/**
 * رفع ملف إلى S3 باستخدام cURL
 */
function uploadToS3WithCurl($bucket, $key, $content, $region, $accessKey, $secretKey, $contentType = 'image/jpeg') {
    $host = "{$bucket}.s3.{$region}.amazonaws.com";
    $url = "https://{$host}/{$key}";
    
    $timestamp = gmdate('Ymd\THis\Z');
    $date = gmdate('Ymd');
    
    $headers = [
        'host' => $host,
        'content-type' => $contentType,
        'x-amz-content-sha256' => hash('sha256', $content),
        'x-amz-date' => $timestamp
    ];
    
    $signature = createAWS4Signature('PUT', $key, $headers, $content, $region, $accessKey, $secretKey, $timestamp);
    $authHeader = "AWS4-HMAC-SHA256 Credential={$accessKey}/{$date}/{$region}/s3/aws4_request, SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date, Signature={$signature}";
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
    curl_setopt($ch, CURLOPT_POSTFIELDS, $content);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Host: {$host}",
        "Content-Type: {$contentType}",
        "x-amz-content-sha256: " . hash('sha256', $content),
        "x-amz-date: {$timestamp}",
        "Authorization: {$authHeader}"
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    if ($error) {
        return ['success' => false, 'error' => "cURL Error: {$error}"];
    }
    
    if ($httpCode >= 200 && $httpCode < 300) {
        return ['success' => true, 'response' => $response];
    } else {
        return ['success' => false, 'error' => "HTTP {$httpCode}: {$response}"];
    }
}

/**
 * إنشاء توقيع AWS4
 */
function createAWS4Signature($method, $uri, $headers, $payload, $region, $accessKey, $secretKey, $timestamp) {
    $date = substr($timestamp, 0, 8);
    
    $canonicalHeaders = '';
    $signedHeaders = '';
    ksort($headers);
    foreach ($headers as $name => $value) {
        $canonicalHeaders .= strtolower($name) . ':' . trim($value) . "\n";
        $signedHeaders .= strtolower($name) . ';';
    }
    $signedHeaders = rtrim($signedHeaders, ';');
    
    $canonicalRequest = $method . "\n" .
                       '/' . $uri . "\n" .
                       "\n" .
                       $canonicalHeaders . "\n" .
                       $signedHeaders . "\n" .
                       hash('sha256', $payload);
    
    $credentialScope = $date . '/' . $region . '/s3/aws4_request';
    $stringToSign = "AWS4-HMAC-SHA256\n" .
                   $timestamp . "\n" .
                   $credentialScope . "\n" .
                   hash('sha256', $canonicalRequest);
    
    $kDate = hash_hmac('sha256', $date, 'AWS4' . $secretKey, true);
    $kRegion = hash_hmac('sha256', $region, $kDate, true);
    $kService = hash_hmac('sha256', 's3', $kRegion, true);
    $kSigning = hash_hmac('sha256', 'aws4_request', $kService, true);
    
    return hash_hmac('sha256', $stringToSign, $kSigning);
}

/**
 * حذف صور الزيارة من S3
 */
function deleteVisitImages($input) {
    sendResponse(false, 'Delete function temporarily disabled');
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
