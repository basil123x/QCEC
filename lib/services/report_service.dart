import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:QCEC/presentation/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportService {
  static const String _smsUrl = 'https://qcec.online/app2026/sms.php';
  static const String _wasenderApiUrl =
      'https://www.wasenderapi.com/api/send-message';
  static const String _wasenderApiKey =
      'c59e7748d6bd6d086bfae052e04027a71f9eb7083594b488d90dea00b02d1260';

  /// إرسال التقارير في الخلفية بعد رفع الصور
  static Future<void> sendReportsInBackground({
    required String projectId,
    required int visitId,
    required List<String> imagePaths,
    required bool sendToCustomer,
    required bool sendToContractor,
  }) async {
    try {
      debugPrint('📊 Starting background report generation for visit $visitId');

      // إنشاء Isolate للمعالجة في الخلفية
      final receivePort = ReceivePort();

      try {
        _updateVisitLocation(projectId);
        debugPrint('📍 Location updated successfully');
      } catch (e) {
        debugPrint('📍 Error updating location: $e');
        // Continue even if location update fails
      }

      final isolate = await Isolate.spawn(
        _reportIsolateEntry,
        _ReportData(
          projectId: projectId,
          visitId: visitId,
          imagePaths: imagePaths,
          sendToCustomer: sendToCustomer,
          sendToContractor: sendToContractor,
          sendPort: receivePort.sendPort,
        ),
      );

      // الاستماع لنتائج المعالجة
      receivePort.listen((message) {
        if (message is _ReportResult) {
          debugPrint(
            '📊 Report result: ${message.success ? "Success" : "Failed"}',
          );
          debugPrint('📊 Message: ${message.message}');

          if (message.success) {
            debugPrint('📊 Reports sent successfully');
            _saveReportStatus(visitId, true);
          } else {
            debugPrint('📊 Report failed: ${message.error}');
            _saveReportStatus(visitId, false);
          }
        }

        // إنهاء الـ isolate
        isolate.kill(priority: Isolate.immediate);
        receivePort.close();
      });
    } catch (e) {
      debugPrint('📊 Error starting report isolate: $e');
    }
  }

  static void _updateVisitLocation(String projectId) async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint(
        '📍 Current location: ${position.latitude}, ${position.longitude}',
      );

      // Update visitsx table with location
      final response = await Dio().post(
        'https://qcec.online/app2026/update_visit_location.php',
        data: {
          'project_id': projectId.toString(),
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      debugPrint('📍 Location update response: ${response.statusCode}');
      debugPrint('📍 Location update data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          debugPrint('📍 Location updated successfully in visitsx table');
        } else {
          debugPrint('📍 Failed to update location: ${data['message']}');
        }
      }
    } catch (e) {
      debugPrint('📍 Error updating visit location: $e');
      throw e;
    }
  }

  /// نقطة دخول الـ Isolate
  static void _reportIsolateEntry(_ReportData data) async {
    try {
      debugPrint('📊 Report isolate started for visit ${data.visitId}');
      final dio = Dio();

      // 1. جلب تفاصيل الزيارة
      debugPrint('📊 Fetching visit details...');
      final visitResponse = await dio.post(
        _smsUrl,
        data: {
          'action': 'get_visit_details',
          'visit_id': data.visitId.toString(),
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      debugPrint('📊 Visit response: ${visitResponse.data}');

      if (visitResponse.data['success'] != true) {
        data.sendPort.send(
          _ReportResult(
            success: false,
            message: 'فشل في جلب تفاصيل الزيارة',
            error: visitResponse.data['message']?.toString() ?? 'Unknown error',
          ),
        );
        return;
      }

      final visitDetails = visitResponse.data['data'];

      // 2. تكوين نص التقرير
      debugPrint('📊 Generating report text...');
      final reportResponse = await dio.post(
        _smsUrl,
        data: {
          'action': 'generate_report',
          'visit_id': data.visitId.toString(),
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('📊 Report response: ${reportResponse.data}');

      if (reportResponse.data['success'] != true) {
        data.sendPort.send(
          _ReportResult(
            success: false,
            message: 'فشل في تكوين التقرير',
            error:
                reportResponse.data['message']?.toString() ?? 'Unknown error',
          ),
        );
        return;
      }

      final reportText = reportResponse.data['data']['report_text'];

      // 3. إنشاء PDF من الصور
      debugPrint('📊 Creating PDF from ${data.imagePaths.length} images...');
      final pdfBytes = await _createPDFFromImages(
        data.imagePaths,
        visitDetails,
      );

      if (pdfBytes == null) {
        data.sendPort.send(
          _ReportResult(
            success: false,
            message: 'فشل في إنشاء ملف PDF',
            error: 'Could not create PDF',
          ),
        );
        return;
      }

      // 4. رفع PDF إلى S3
      debugPrint('📊 Uploading PDF to S3...');
      final pdfUrl = await _uploadPDFToS3(pdfBytes, data.visitId);

      if (pdfUrl == null) {
        data.sendPort.send(
          _ReportResult(
            success: false,
            message: 'فشل في رفع ملف PDF',
            error: 'Could not upload PDF',
          ),
        );
        return;
      }

      // ⭐ 5. الآن بعد ما كل الميديا اترفعت على S3، نجيب الفيديوهات
      debugPrint('📊 🎥 Waiting for all media to be uploaded to S3...');

      // نستنى شوية عشان الميديا تتأكد إنها اترفعت
      await Future.delayed(const Duration(seconds: 3));

      debugPrint('📊 🎥 Fetching uploaded videos from S3...');

      // دالة لجلب جميع الميديا من S3
      Future<List<String>> getMedia(String folderId) async {
        try {
          var result = await Dio().get(
            "https://qcec.online/erp2025/aws/get_cloud.php?folder=$folderId&k=${DateTime.now().microsecondsSinceEpoch}",
          );

          var responseData = result.data;

          // لو البيانات String، نعمل decode
          if (responseData is String) {
            responseData = jsonDecode(responseData);
          }

          // نتأكد إن data['files'] موجودة وقابلة للتحويل لقائمة
          List<String> files = [];
          if (responseData != null && responseData['files'] != null) {
            files = List<String>.from(responseData['files']);
          }

          // الترتيب حسب الرقم في اسم الملف
          files.sort((a, b) {
            int numA = int.tryParse(a.split('/').last.split('.').first) ?? 0;
            int numB = int.tryParse(b.split('/').last.split('.').first) ?? 0;
            return numA.compareTo(numB);
          });

          return files;
        } catch (e) {
          debugPrint("📊 🎥 Error in getMedia: $e");
          return [];
        }
      }

      // جلب جميع الملفات من S3
      final media = await getMedia(data.visitId.toString());
      debugPrint('📊 🎥 All media files from S3: $media');

      // فلترة الفيديوهات فقط (mp4)
      List<String> uploadedVideoUrls = [];
      for (var file in media) {
        if (file.toLowerCase().endsWith('.mp4')) {
          uploadedVideoUrls.add(file);
        }
      }

      debugPrint(
        '📊 🎥 ✅ Found ${uploadedVideoUrls.length} uploaded videos on S3: $uploadedVideoUrls',
      );

      // لو مفيش فيديوهات، نكمل بدون مشاكل
      if (uploadedVideoUrls.isEmpty) {
        debugPrint(
          '📊 🎥 No videos found on S3, continuing with SMS and WhatsApp only...',
        );
      }

      // 6. إرسال الرسائل
      int successCount = 0;
      List<String> errors = [];

      // إرسال للعميل
      if (data.sendToCustomer && visitDetails['customer_phone'] != null) {
        debugPrint(
          '📊 🔥 Sending to customer: ${visitDetails['customer_phone']}',
        );

        // إرسال SMS
        debugPrint('📊 📱 Sending SMS to customer...');
        final smsResult = await _sendSMS(
          dio,
          visitDetails['customer_phone'],
          reportText,
        );
        debugPrint('📊 📱 SMS to customer result: $smsResult');
        if (smsResult) {
          successCount++;
        } else {
          errors.add('فشل إرسال SMS للعميل');
        }

        // تأخير بين الرسائل
        await Future.delayed(const Duration(seconds: 3));

        // إرسال WhatsApp مع PDF
        debugPrint('📊 💬 Sending WhatsApp with PDF to customer...');
        final whatsappResult = await _sendWhatsApp(
          dio,
          visitDetails['customer_phone'],
          reportText,
          pdfUrl,
          'تقرير-زيارة-${data.visitId}.pdf',
        );
        debugPrint('📊 💬 WhatsApp to customer result: $whatsappResult');
        if (whatsappResult) {
          successCount++;
        } else {
          errors.add('فشل إرسال WhatsApp للعميل');
        }

        // تأخير قبل إرسال الفيديوهات
        await Future.delayed(const Duration(seconds: 5));

        // ⭐ إرسال الفيديوهات للعميل (بعد التأكد من رفعها على S3)
        if (uploadedVideoUrls.isNotEmpty) {
          debugPrint(
            '📊 🎥 Sending ${uploadedVideoUrls.length} videos to customer...',
          );

          for (int i = 0; i < uploadedVideoUrls.length; i++) {
            debugPrint(
              '📊 🎥 Sending video ${i + 1}/${uploadedVideoUrls.length}: ${uploadedVideoUrls[i]}',
            );

            final videoResult = await _sendWhatsAppVideoWasender(
              dio,
              visitDetails['customer_phone'],
              uploadedVideoUrls[i],
              'فيديو ${i + 1} من زيارة ${data.visitId}',
            );

            if (videoResult) {
              debugPrint(
                '📊 🎥 ✅ Video ${i + 1} sent to customer successfully',
              );
              successCount++;
            } else {
              debugPrint('📊 🎥 ❌ Failed to send video ${i + 1} to customer');
              errors.add('فشل إرسال الفيديو ${i + 1} للعميل');
            }

            // تأخير بين الفيديوهات
            if (i < uploadedVideoUrls.length - 1) {
              await Future.delayed(const Duration(seconds: 5));
            }
          }

          debugPrint('📊 🎥 Finished sending all videos to customer');
        }
      }

      // إرسال للمقاول
      if (data.sendToContractor && visitDetails['contractor_phone'] != null) {
        debugPrint(
          '📊 🔥 Sending to contractor: ${visitDetails['contractor_phone']}',
        );

        // تأخير إضافي بين العميل والمقاول
        await Future.delayed(const Duration(seconds: 5));

        // إرسال SMS
        debugPrint('📊 📱 Sending SMS to contractor...');
        final smsResult = await _sendSMS(
          dio,
          visitDetails['contractor_phone'],
          reportText,
        );
        debugPrint('📊 📱 SMS to contractor result: $smsResult');
        if (smsResult) {
          successCount++;
        } else {
          errors.add('فشل إرسال SMS للمقاول');
        }

        // تأخير بين الرسائل
        await Future.delayed(const Duration(seconds: 3));

        // إرسال WhatsApp مع PDF
        debugPrint('📊 💬 Sending WhatsApp with PDF to contractor...');
        final whatsappResult = await _sendWhatsApp(
          dio,
          visitDetails['contractor_phone'],
          reportText,
          pdfUrl,
          'تقرير-زيارة-${data.visitId}.pdf',
        );
        debugPrint('📊 💬 WhatsApp to contractor result: $whatsappResult');
        if (whatsappResult) {
          successCount++;
        } else {
          errors.add('فشل إرسال WhatsApp للمقاول');
        }

        // تأخير قبل إرسال الفيديوهات
        await Future.delayed(const Duration(seconds: 5));

        // ⭐ إرسال الفيديوهات للمقاول (بعد التأكد من رفعها على S3)
        if (uploadedVideoUrls.isNotEmpty) {
          debugPrint(
            '📊 🎥 Sending ${uploadedVideoUrls.length} videos to contractor...',
          );

          for (int i = 0; i < uploadedVideoUrls.length; i++) {
            debugPrint(
              '📊 🎥 Sending video ${i + 1}/${uploadedVideoUrls.length}: ${uploadedVideoUrls[i]}',
            );

            final videoResult = await _sendWhatsAppVideoWasender(
              dio,
              visitDetails['contractor_phone'],
              uploadedVideoUrls[i],
              'فيديو ${i + 1} من زيارة ${data.visitId}',
            );

            if (videoResult) {
              debugPrint(
                '📊 🎥 ✅ Video ${i + 1} sent to contractor successfully',
              );
              successCount++;
            } else {
              debugPrint('📊 🎥 ❌ Failed to send video ${i + 1} to contractor');
              errors.add('فشل إرسال الفيديو ${i + 1} للمقاول');
            }

            // تأخير بين الفيديوهات
            if (i < uploadedVideoUrls.length - 1) {
              await Future.delayed(const Duration(seconds: 5));
            }
          }

          debugPrint('📊 🎥 Finished sending all videos to contractor');
        }
      }

      // تحديث عدد الصور وحالة الإرسال في قاعدة البيانات
      await _updateVisitAfterReport(data, successCount);

      // إرسال النتيجة
      if (successCount > 0) {
        data.sendPort.send(
          _ReportResult(
            success: true,
            message: 'تم إرسال $successCount رسالة بنجاح',
            sentCount: successCount,
          ),
        );
      } else {
        data.sendPort.send(
          _ReportResult(
            success: false,
            message: 'فشل في إرسال الرسائل: ${errors.join(', ')}',
            sentCount: 0,
          ),
        );
      }
    } catch (e) {
      debugPrint('📊 Fatal error in report isolate: $e');
      debugPrint('📊 Stack trace: ${StackTrace.current}');
      data.sendPort.send(
        _ReportResult(
          success: false,
          message: 'خطأ في معالجة التقرير',
          error: e.toString(),
        ),
      );
    }
  }

  /// إنشاء PDF من الصور
  static Future<Uint8List?> _createPDFFromImages(
    List<String> imagePaths,
    Map<String, dynamic> visitDetails,
  ) async {
    try {
      debugPrint('📊 Creating PDF with ${imagePaths.length} images');
      debugPrint('📊 Visit details: $visitDetails');

      final pdf = pw.Document();

      // إضافة الصور
      for (int i = 0; i < imagePaths.length; i++) {
        try {
          final imagePath = imagePaths[i];
          final file = File(imagePath);
          if (await file.exists()) {
            final imageBytes = await file.readAsBytes();
            final image = pw.MemoryImage(imageBytes);

            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                build: (pw.Context context) {
                  return pw.Image(image, fit: pw.BoxFit.contain);
                },
              ),
            );
          }
        } catch (e) {
          debugPrint('📊 Error adding image ${i + 1}: $e');
        }
      }

      debugPrint('📊 Saving PDF...');
      return await pdf.save();
    } catch (e) {
      debugPrint('📊 Error creating PDF: $e');
      debugPrint('📊 Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// رفع PDF إلى S3
  static Future<String?> _uploadPDFToS3(Uint8List pdfBytes, int visitId) async {
    try {
      final dio = Dio();

      // إنشاء مسار الملف
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final fileName = 'visit-report-$visitId-$dateStr.pdf';

      // تحويل PDF إلى base64
      final base64PDF = base64Encode(pdfBytes);

      debugPrint(
        '📊 Uploading PDF to S3: whatsapp/$visitId/$dateStr/$fileName',
      );

      final response = await dio.post(
        'https://qcec.online/app2026/s3.php',
        data: {
          'action': 'upload_pdf',
          'visit_id': visitId.toString(),
          'date': dateStr,
          'file_name': fileName,
          'pdf_data': base64PDF,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      debugPrint('📊 S3 PDF upload response: ${response.data}');

      if (response.data['success'] == true) {
        return response.data['data']['url'];
      }

      return null;
    } catch (e) {
      debugPrint('📊 Error uploading PDF to S3: $e');
      return null;
    }
  }

  /// إرسال SMS مباشرة من Flutter
  static Future<bool> _sendSMS(Dio dio, String phone, String message) async {
    try {
      debugPrint('📊 Sending SMS to: $phone');

      // تنظيف رقم الهاتف
      phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (!phone.startsWith('974')) {
        phone = '974$phone';
      }

      debugPrint('📊 Cleaned phone: $phone');

      // إنشاء URL مباشرة زي Postman بالضبط
      final smsUrl =
          'https://messaging.ooredoo.qa/bms/soap/Messenger.asmx/HTTP_SendSms'
          '?customerID=7221'
          '&userName=qcec'
          '&userPassword=Qcec@8080'
          '&originator=QCEC'
          '&smsText=${Uri.encodeComponent(message)}'
          '&recipientPhone=$phone'
          '&messageType=ArabicWithLatinNumbers'
          '&defDate='
          '&blink=false'
          '&flash=false'
          '&Private=false';

      debugPrint('📊 SMS URL: $smsUrl');

      final stopwatch = Stopwatch()..start();

      final response = await dio.get(
        smsUrl,
        options: Options(
          headers: {'User-Agent': 'Mozilla/5.0 (compatible; SMS-Client/1.0)'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          followRedirects: true,
        ),
      );

      stopwatch.stop();
      debugPrint('📊 SMS request took: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('📊 SMS status code: ${response.statusCode}');
      debugPrint('📊 SMS response: ${response.data}');

      // تحليل الـ XML response
      if (response.statusCode == 200) {
        final responseText = response.data.toString();
        if (responseText.contains('<Result>OK</Result>')) {
          debugPrint('📊 ✅ SMS sent successfully!');
          return true;
        } else {
          debugPrint('📊 ❌ SMS failed - XML result not OK');
          return false;
        }
      } else {
        debugPrint('📊 ❌ SMS failed - HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('📊 ❌ SMS error: $e');
      return false;
    }
  }

  /// تحديث الزيارة بعد الإرسال
  static Future<void> _updateVisitAfterReport(
    _ReportData data,
    int successCount,
  ) async {
    try {
      debugPrint('📊 Updating visit ${data.visitId} after report...');

      final dio = Dio();

      // حساب عدد الصور
      final imageCount = data.imagePaths.length;

      // تحديد حالة الإرسال
      int mob1 = 0; // العميل
      int mob2 = 0; // المقاول

      if (data.sendToCustomer && successCount > 0) {
        mob1 = 1;
      }
      if (data.sendToContractor && successCount > 0) {
        mob2 = 1;
      }

      debugPrint('📊 Image count: $imageCount, mob1: $mob1, mob2: $mob2');

      final response = await dio.post(
        'https://qcec.online/app2026/update_visit.php',
        data: {
          'visit_id': data.visitId,
          'image_count': imageCount,
          'mob1': mob1,
          'mob2': mob2,
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );

      debugPrint('📊 Visit update response: ${response.data}');
    } catch (e) {
      debugPrint('📊 Error updating visit: $e');
    }
  }

  /// إرسال WhatsApp
  static Future<bool> _sendWhatsApp(
    Dio dio,
    String phone,
    String message,
    String? documentUrl,
    String? fileName,
  ) async {
    try {
      debugPrint('📊 Sending WhatsApp to: $phone');

      final data = {
        'action': 'send_whatsapp',
        'phone': phone,
        'message': message,
      };

      if (documentUrl != null && fileName != null) {
        data['document_url'] = documentUrl;
        data['file_name'] = fileName;
      }

      final response = await dio.post(
        _smsUrl,
        data: data,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('📊 WhatsApp response: ${response.data}');

      // تحويل الاستجابة إلى Map إذا كانت String
      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = jsonDecode(response.data);
      } else {
        responseData = response.data as Map<String, dynamic>;
      }

      return responseData['success'] == true;
    } catch (e) {
      debugPrint('📊 Error sending WhatsApp: $e');
      return false;
    }
  }

  /// إرسال فيديو عبر WhatsApp باستخدام WasenderAPI مباشرة
  static Future<bool> _sendWhatsAppVideoWasender(
    Dio dio,
    String phoneNumber,
    String videoUrl,
    String text,
  ) async {
    try {
      debugPrint('📊 🎥 Sending video via Wasender to $phoneNumber: $videoUrl');

      // تنظيف رقم الهاتف (يجب أن يكون بالصيغة الدولية مع +)
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (!phoneNumber.startsWith('974')) {
        phoneNumber = '974$phoneNumber';
      }

      // إضافة + في البداية
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+$phoneNumber';
      }

      debugPrint('📊 🎥 Cleaned phone number: $phoneNumber');
      debugPrint('📊 🎥 Video URL: $videoUrl');
      debugPrint('📊 🎥 Message text: $text');

      final response = await dio.post(
        _wasenderApiUrl,
        data: {'to': phoneNumber, 'text': text, 'videoUrl': videoUrl},
        options: Options(
          headers: {
            'Authorization': 'Bearer $_wasenderApiKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      debugPrint('📊 🎥 Wasender API status code: ${response.statusCode}');
      debugPrint('📊 🎥 Wasender API response: ${response.data}');

      // تحقق من نجاح الإرسال
      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is Map) {
          if (responseData['success'] == true ||
              responseData['status'] == 'success' ||
              responseData['status'] == 'sent') {
            debugPrint('📊 🎥 ✅ Video sent successfully via Wasender!');
            return true;
          }
        }

        // لو الـ response code 200 بس مش واضح الـ status
        debugPrint('📊 🎥 ⚠️ Wasender returned 200 but unclear status');
        return true; // نفترض النجاح لأن الـ status code 200
      }

      debugPrint('📊 🎥 ❌ Wasender failed with status: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('📊 🎥 ❌ Error sending video via Wasender: $e');
      if (e is DioException) {
        debugPrint('📊 🎥 ❌ Dio error type: ${e.type}');
        debugPrint('📊 🎥 ❌ Dio error message: ${e.message}');
        debugPrint('📊 🎥 ❌ Dio error response: ${e.response?.data}');
      }
      return false;
    }
  }

  /// حفظ حالة التقرير
  static Future<void> _saveReportStatus(int visitId, bool success) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('report_status_$visitId', success);
      await prefs.setString(
        'report_date_$visitId',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('📊 Error saving report status: $e');
    }
  }
}

/// بيانات التقرير للـ Isolate
class _ReportData {
  final String projectId;
  final int visitId;
  final List<String> imagePaths;
  final bool sendToCustomer;
  final bool sendToContractor;
  final SendPort sendPort;

  _ReportData({
    required this.projectId,
    required this.visitId,
    required this.imagePaths,
    required this.sendToCustomer,
    required this.sendToContractor,
    required this.sendPort,
  });
}

/// نتيجة معالجة التقرير
class _ReportResult {
  final bool success;
  final String message;
  final String? error;
  final int? sentCount;
  final List<String>? errors;

  _ReportResult({
    required this.success,
    required this.message,
    this.error,
    this.sentCount,
    this.errors,
  });
}
