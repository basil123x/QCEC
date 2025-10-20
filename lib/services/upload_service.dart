import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadService {
  static const String _uploadUrl = 'https://qcec.online/app2026/s3.php';
  
  /// رفع صور الزيارة في الخلفية باستخدام Isolate
  static Future<void> uploadVisitImagesInBackground({
    required int visitId,
    required List<String> imagePaths,
  }) async {
    try {
      // إنشاء Isolate للرفع في الخلفية
      final receivePort = ReceivePort();
      
      final isolate = await Isolate.spawn(
        _uploadIsolateEntry,
        _UploadData(
          visitId: visitId,
          imagePaths: imagePaths,
          sendPort: receivePort.sendPort,
        ),
      );
      
      // الاستماع لنتائج الرفع
      receivePort.listen((message) {
        if (message is _UploadResult) {
          debugPrint('📤 Upload result: ${message.success ? "Success" : "Failed"}');
          debugPrint('📤 Message: ${message.message}');
          
          if (message.success) {
            debugPrint('📤 Uploaded ${message.uploadedCount} images');
            // حفظ حالة الرفع الناجح
            _saveUploadStatus(visitId, true);
          } else {
            debugPrint('📤 Upload failed: ${message.error}');
            _saveUploadStatus(visitId, false);
          }
          
          // إنهاء الـ Isolate
          isolate.kill();
          receivePort.close();
        }
      });
      
    } catch (e) {
      debugPrint('📤 Error starting upload isolate: $e');
    }
  }
  
  /// نقطة دخول الـ Isolate
  static void _uploadIsolateEntry(_UploadData data) async {
    try {
      final dio = Dio();
      final List<String> base64Images = [];
      
      // تحويل الصور إلى base64
      for (int i = 0; i < data.imagePaths.length; i++) {
        try {
          final file = File(data.imagePaths[i]);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final base64String = base64Encode(bytes);
            base64Images.add(base64String);
            
            // إرسال تقدم الرفع
            data.sendPort.send(_UploadProgress(
              current: i + 1,
              total: data.imagePaths.length,
              stage: 'Converting to base64',
            ));
          }
        } catch (e) {
          debugPrint('📤 Error converting image ${i + 1}: $e');
        }
      }
      
      if (base64Images.isEmpty) {
        data.sendPort.send(_UploadResult(
          success: false,
          message: 'لا توجد صور صالحة للرفع',
          error: 'No valid images found',
        ));
        return;
      }
      
      // رفع الصور إلى S3
      final response = await dio.post(
        _uploadUrl,
        data: {
          'action': 'upload_visit_images',
          'visit_id': data.visitId.toString(),
          'images': base64Images,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 10),
        ),
      );
      
      debugPrint('📤 Response received: ${response.statusCode}');
      debugPrint('📤 Response data type: ${response.data.runtimeType}');
      debugPrint('📤 Response data: ${response.data}');
      
      // تحويل الاستجابة إلى Map
      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = jsonDecode(response.data);
      } else {
        responseData = response.data as Map<String, dynamic>;
      }
      
      if (responseData['success'] == true) {
        final uploadedCount = responseData['data']?['total_uploaded'] ?? 0;
        data.sendPort.send(_UploadResult(
          success: true,
          message: 'تم رفع $uploadedCount صورة بنجاح',
          uploadedCount: uploadedCount is int ? uploadedCount : int.tryParse(uploadedCount.toString()) ?? 0,
        ));
      } else {
        data.sendPort.send(_UploadResult(
          success: false,
          message: responseData['message']?.toString() ?? 'فشل في الرفع',
          error: responseData['message']?.toString(),
        ));
      }
      
    } catch (e) {
      data.sendPort.send(_UploadResult(
        success: false,
        message: 'خطأ في الاتصال',
        error: e.toString(),
      ));
    }
  }
  
  /// حفظ حالة الرفع
  static Future<void> _saveUploadStatus(int visitId, bool success) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('upload_status_$visitId', success);
      await prefs.setString('upload_time_$visitId', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('📤 Error saving upload status: $e');
    }
  }
  
  /// التحقق من حالة الرفع
  static Future<bool?> getUploadStatus(int visitId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('upload_status_$visitId');
    } catch (e) {
      debugPrint('📤 Error getting upload status: $e');
      return null;
    }
  }
}

/// بيانات الرفع للـ Isolate
class _UploadData {
  final int visitId;
  final List<String> imagePaths;
  final SendPort sendPort;
  
  _UploadData({
    required this.visitId,
    required this.imagePaths,
    required this.sendPort,
  });
}

/// نتيجة الرفع
class _UploadResult {
  final bool success;
  final String message;
  final String? error;
  final int? uploadedCount;
  
  _UploadResult({
    required this.success,
    required this.message,
    this.error,
    this.uploadedCount,
  });
}

/// تقدم الرفع
class _UploadProgress {
  final int current;
  final int total;
  final String stage;
  
  _UploadProgress({
    required this.current,
    required this.total,
    required this.stage,
  });
}
