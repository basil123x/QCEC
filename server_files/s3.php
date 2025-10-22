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
    case 'upload_visit_media':
        uploadVisitMedia($input);
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
 * رفع وسائط الزيارة (صور وفيديوهات) إلى S3
 */
function uploadVisitMedia($input) {
    global $bucket, $region, $accessKey, $secretKey;
    
    try {
        error_log("Media upload request received for visit: " . ($input['visit_id'] ?? 'unknown'));
        
        if (!isset($input['visit_id']) || !isset($input['media'])) {
            sendResponse(false, 'معرف الزيارة والوسائط مطلوبان');
            return;
        }
        
        $visitId = $input['visit_id'];
        $mediaFiles = $input['media'];
        $uploadedMedia = [];
        $errors = [];
        
        error_log("Processing " . count($mediaFiles) . " media files for visit " . $visitId);
        
        foreach ($mediaFiles as $index => $mediaData) {
            try {
                if (!isset($mediaData['data']) || !isset($mediaData['type'])) {
                    $errors[] = "بيانات الوسائط غير مكتملة للملف رقم " . ($index + 1);
                    continue;
                }
                
                $mediaContent = base64_decode($mediaData['data']);
                $mediaType = $mediaData['type']; // 'image' or 'video'
                $fileName = $mediaData['filename'] ?? null;
                
                if ($mediaContent === false) {
                    $errors[] = "فشل في فك تشفير الوسائط رقم " . ($index + 1);
                    continue;
                }
                
                // تحديد امتداد الملف ونوع المحتوى
                if ($mediaType === 'video') {
                    $extension = 'mp4';
                    $contentType = 'video/mp4';
                    error_log("Processing video file: " . ($fileName ?? "video_" . ($index + 1)));
                } else {
                    $extension = 'jpg';
                    $contentType = 'image/jpeg';
                    
                    // ضغط الصورة
                    $mediaContent = compressImage($mediaContent);
                    error_log("Compressed image file: " . ($fileName ?? "image_" . ($index + 1)));
                }
                
                $mediaNumber = $index + 1;
                $s3Key = "visits/{$visitId}/{$mediaNumber}.{$extension}";
                
                // رفع الوسائط باستخدام cURL
                $result = uploadToS3WithCurl($bucket, $s3Key, $mediaContent, $region, $accessKey, $secretKey, $contentType);
                
                if ($result['success']) {
                    $uploadedMedia[] = [
                        'number' => $mediaNumber,
                        'type' => $mediaType,
                        'url' => "https://{$bucket}.s3.{$region}.amazonaws.com/{$s3Key}",
                        's3_key' => $s3Key,
                        'filename' => $fileName
                    ];
                    error_log("Successfully uploaded {$mediaType} " . $mediaNumber);
                } else {
                    $errors[] = "فشل رفع {$mediaType} رقم " . ($index + 1) . ": " . $result['error'];
                    error_log("Failed to upload {$mediaType} " . $mediaNumber . ": " . $result['error']);
                }
                
            } catch (Exception $e) {
                $error_msg = "خطأ في رفع الوسائط رقم " . ($index + 1) . ": " . $e->getMessage();
                $errors[] = $error_msg;
                error_log("Exception: " . $error_msg);
            }
        }
        
        if (count($uploadedMedia) > 0) {
            sendResponse(true, 'تم رفع ' . count($uploadedMedia) . ' ملف بنجاح', [
                'uploaded_media' => $uploadedMedia,
                'errors' => $errors,
                'total_uploaded' => count($uploadedMedia),
                'total_errors' => count($errors)
            ]);
        } else {
            sendResponse(false, 'فشل في رفع جميع الوسائط', ['errors' => $errors]);
        }
        
    } catch (Exception $e) {
        error_log("Fatal error in uploadVisitMedia: " . $e->getMessage());
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
 * ضغط الصورة
 */
function compressImage($imageData, $quality = 75) {
    try {
        // إنشاء صورة من البيانات
        $image = imagecreatefromstring($imageData);
        
        if ($image === false) {
            error_log("Failed to create image from string");
            return $imageData; // إرجاع الصورة الأصلية في حالة الفشل
        }
        
        // الحصول على أبعاد الصورة
        $width = imagesx($image);
        $height = imagesy($image);
        
        // تحديد الحد الأقصى للأبعاد
        $maxWidth = 1920;
        $maxHeight = 1080;
        
        // حساب الأبعاد الجديدة مع الحفاظ على النسبة
        if ($width > $maxWidth || $height > $maxHeight) {
            $ratio = min($maxWidth / $width, $maxHeight / $height);
            $newWidth = intval($width * $ratio);
            $newHeight = intval($height * $ratio);
            
            // إنشاء صورة جديدة بالأبعاد المحسوبة
            $newImage = imagecreatetruecolor($newWidth, $newHeight);
            
            // نسخ وتغيير حجم الصورة
            imagecopyresampled($newImage, $image, 0, 0, 0, 0, $newWidth, $newHeight, $width, $height);
            
            // تحرير الذاكرة للصورة الأصلية
            imagedestroy($image);
            $image = $newImage;
        }
        
        // بدء التخزين المؤقت للحصول على البيانات المضغوطة
        ob_start();
        imagejpeg($image, null, $quality);
        $compressedData = ob_get_contents();
        ob_end_clean();
        
        // تحرير الذاكرة
        imagedestroy($image);
        
        error_log("Image compressed successfully. Original size: " . strlen($imageData) . " bytes, Compressed size: " . strlen($compressedData) . " bytes");
        
        return $compressedData;
        
    } catch (Exception $e) {
        error_log("Image compression failed: " . $e->getMessage());
        return $imageData; // إرجاع الصورة الأصلية في حالة الفشل
    }
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
