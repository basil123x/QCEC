import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:QCEC/core/Functions/GetImages.dart';
import 'package:QCEC/core/Functions/SendToWhatsapp.dart';
import 'package:QCEC/core/Functions/sendSMS.dart';
import 'package:QCEC/presentation/providers/theme_provider.dart';
import 'package:QCEC/presentation/screens/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart' as intlx;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:QCEC/core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../../services/upload_service.dart';
import '../../services/report_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_photo_editor/flutter_photo_editor.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'additional_camera_screen.dart';
import 'simple_video_player.dart';
import '../../models/draft_visit.dart';
import '../../services/draft_visit_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http_parser/http_parser.dart';

class AddVisitScreen extends StatefulWidget {
  final int visitId;
  final int projectId;
  final List<String> capturedImages;

  const AddVisitScreen({
    Key? key,
    required this.visitId,
    required this.projectId,
    required this.capturedImages,
  }) : super(key: key);

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final PageController _pageController = PageController();
  final Dio dio = Dio();
  final ImagePicker _picker = ImagePicker();
  final DraftVisitService _draftService = DraftVisitService();

  void startBackgroundTasks(Map<String, dynamic> data) async {
    final dir = await getApplicationDocumentsDirectory();
    data['appDir'] = dir.path;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception("User denied permissions to access location.");
      }
    }
    Position cPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    await Dio().post(
      'https://qcec.online/erp2025/app_source/visits.php',
      data: {
        'action': 'update_visitsx',
        'proId': widget.projectId,
        'lat': cPosition.latitude,
        'long': cPosition.longitude,
      },
    );
    Isolate.spawn(runHeavyTasks, data);
    // _images.clear();
  }

  static void runHeavyTasks(Map<String, dynamic> data) async {
    final appDir = data['appDir'];
    print("🚀 Starting upload for visit ${data['visitId']}");

    try {
      final formData = FormData();

      // التحقق من وجود الملفات
      if (data['images'] == null || (data['images'] as List).isEmpty) {
        print("⚠️ No files to upload");
        return;
      }

      // فصل الصور عن الفيديوهات
      List<String> images = [];
      List<String> videos = [];

      for (var filePath in data['images']) {
        final ext = filePath.toString().split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
          images.add(filePath.toString());
        } else if (['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext)) {
          videos.add(filePath.toString());
        }
      }

      print("📊 Total files: ${images.length} images, ${videos.length} videos");

      // إضافة الصور
      for (int i = 0; i < images.length; i++) {
        final file = File(images[i]);
        if (!await file.exists()) {
          print("⚠️ File not found: ${images[i]}");
          continue;
        }

        formData.files.add(
          MapEntry('images[]', await MultipartFile.fromFile(file.path)),
        );
        print("✅ Added image ${i + 1}");
      }

      // إضافة الفيديوهات
      for (int i = 0; i < videos.length; i++) {
        final file = File(videos[i]);
        if (!await file.exists()) {
          print("⚠️ File not found: ${videos[i]}");
          continue;
        }

        final fileSize = await file.length();
        print(
          "✅ Added video ${i + 1} (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)",
        );

        formData.files.add(
          MapEntry('videos[]', await MultipartFile.fromFile(file.path)),
        );
      }

      // التحقق من وجود ملفات للرفع
      if (formData.files.isEmpty) {
        print("⚠️ No valid files to upload");
        return;
      }

      // إضافة رقم الزيارة
      formData.fields.add(MapEntry('visitId', data['visitId'].toString()));

      final dio = Dio();
      print(
        "📤 Starting upload to visits/${data['visitId']}/ (${formData.files.length} files)",
      );

      final response = await dio.post(
        'https://qcec.online/app2026/cloud_multi_media.php',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
          sendTimeout: Duration(minutes: 10),
          receiveTimeout: Duration(minutes: 10),
          validateStatus: (status) => true, // قبول كل الـ status codes
          responseType: ResponseType.plain, // استقبال النص الخام أولاً
        ),
        onSendProgress: (sent, total) {
          if (total != -1) {
            final progress = sent / total;
            final sentMB = (sent / 1024 / 1024).toStringAsFixed(2);
            final totalMB = (total / 1024 / 1024).toStringAsFixed(2);
            print(
              "📤 Uploading: ${(progress * 100).toStringAsFixed(1)}% ($sentMB/$totalMB MB)",
            );
          }
        },
      );

      print("📥 Response Status: ${response.statusCode}");
      print("📥 Raw Response: ${response.data}");

      if (response.statusCode == 200) {
        try {
          // محاولة تحويل الـ response لـ JSON
          final jsonData = jsonDecode(response.data.toString());

          if (jsonData['success'] == true) {
            print("✅ ${jsonData['message']}");
            if (jsonData['uploaded_files'] != null) {
              print("📁 Files uploaded:");
              for (var file in jsonData['uploaded_files']) {
                print("   - ${file['new_name']} (${file['type']})");
              }
            }
          } else {
            print("⚠️ ${jsonData['message']}");
            if (jsonData['failed_files'] != null &&
                jsonData['failed_files'].length > 0) {
              print("❌ Failed files:");
              for (var file in jsonData['failed_files']) {
                print("   - ${file['name']}: ${file['reason']}");
              }
            }
          }
        } catch (e) {
          print("❌ Failed to parse JSON response: $e");
          print("Raw response was: ${response.data}");
        }
      } else {
        print("⚠️ Upload failed with status: ${response.statusCode}");
        print("Response: ${response.data}");
      }
    } catch (e, stackTrace) {
      print("❌ Exception during upload: $e");
      print("Stack trace: $stackTrace");
    }

    try {
      print("📄 Starting PDF generation...");
      final pdf = pw.Document();

      List myImages = await Getimages().getImages(data['visitId'].toString());
      print("Found ${myImages.length} images for PDF");

      for (var url in myImages) {
        if (url.toString().split('/').last.split('.').last == 'jpg') {
          try {
            final response = await Dio().get<List<int>>(
              url,
              options: Options(responseType: ResponseType.bytes),
            );

            if (response.statusCode == 200 && response.data != null) {
              final image = pw.MemoryImage(Uint8List.fromList(response.data!));
              pdf.addPage(
                pw.Page(
                  build: (pw.Context context) {
                    return pw.Center(child: pw.Image(image));
                  },
                ),
              );
            }
          } catch (e) {
            print("⚠️ Failed to add image to PDF: $e");
          }
        }
      }

      final timestamp = intlx.DateFormat(
        'yyyyMMdd_HHmmss',
      ).format(DateTime.now());
      final file = File('$appDir/visit_report_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());
      print("✅ PDF saved: ${file.path}");

      final dio = Dio();
      final pdfFormData = FormData.fromMap({
        'folder': "Whatsapp/${data['visitId']}",
        'pdf': await MultipartFile.fromFile(file.path, filename: '1.pdf'),
      });

      print("📤 Uploading PDF...");
      await dio.post(
        'https://qcec.online/erp2025/aws/cloud_pdf.php',
        data: pdfFormData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );
      print("✅ PDF uploaded successfully");

      // WhatsApp وSMS
      print("📱 Fetching WhatsApp data...");
      final whatsRes = await Dio().post(
        'https://qcec.online/erp2025/app_source/visits.php',
        data: {'action': 'get_whats_visit_data', 'vdId': data['visitId']},
      );

      if (whatsRes.data != null && whatsRes.data['get_visits_whats'] != null) {
        List fullMessage = whatsRes.data['get_visits_whats'];

        String msg =
            """
${data['date']} - ${data['time']} ${intlx.DateFormat('yyyy-MM-dd').format(DateTime.now())}
*العميل*: ${fullMessage[0]['cname']}
*المشروع*: ${fullMessage[0]['projx']}
*المنطقة*: ${fullMessage[0]['place']}
*الرقم المساحي*: ${fullMessage[0]['pin']}
*المقاول*: ${fullMessage[0]['cnname']}
*الاستشاري*: م/${fullMessage[0]['ename']}
*الوصف*: ${fullMessage[0]['a2']}
*التفاصيل*: ${fullMessage[0]['a4']}
""";

        data['msg'] = msg;

        if (data['sendCmob'] != null && data['sendCmob'] != '') {
          await Future.delayed(Duration(seconds: 10));
          await sendSMS().sendSms(data['sendCmob'], data['msg'], 'both');

          await Sendtowhatsapp().sendToWhatsDocs(
            data['sendCmob'],
            data['visitId'],
            data['msg'],
          );
          await Future.delayed(Duration(seconds: 10));
          List videos = await Getimages().getImages(data['visitId'].toString());
          for (var video in videos) {
            if (video.toString().split('/').last.split('.').last == 'mp4') {
              Sendtowhatsapp().sendToWhatsVideo(
                data['sendCmob'],
                video.toString(),
              );
              await Future.delayed(Duration(seconds: 10));
            }
          }
        }

        if (data['sendCNmob'] != null && data['sendCNmob'] != '') {
          await sendSMS().sendSms(data['sendCNmob'], data['msg'], 'both');
          await Sendtowhatsapp().sendToWhatsDocs(
            data['sendCNmob'],
            data['visitId'],
            data['msg'],
          );
          await Future.delayed(Duration(seconds: 10));
          List videos = await Getimages().getImages(data['visitId'].toString());
          for (var video in videos) {
            if (video.toString().split('/').last.split('.').last == 'mp4') {
              Sendtowhatsapp().sendToWhatsVideo(
                data['sendCNmob'],
                video.toString(),
              );
              await Future.delayed(Duration(seconds: 10));
            }
          }
        }
      }

      if (data['images'] != null) {
        data['images'].clear();
      }

      print("✅ All background tasks finished for visit ${data['visitId']}");
    } catch (e, stackTrace) {
      print("❌ Exception in PDF/WhatsApp section: $e");
      print("Stack trace: $stackTrace");
    }
  }

  int _currentImageIndex = 0;
  List<String> _images = [];

  // Visit details
  String _customerName = '';
  String _customerPhone = '';
  String _contractorPhone = '';
  bool _isLoadingDetails = true;

  // Contact options
  bool _contactCustomer = false;
  bool _contactContractor = false;

  // Image editing states
  bool _showEditIcons = false;
  bool _isLongPressed = false;

  @override
  void initState() {
    super.initState();
    _initializeDraftVisit();
    _loadVisitDetails();
  }

  /// تهيئة الزيارة المؤقتة وتحميل البيانات المحفوظة
  void _initializeDraftVisit() async {
    try {
      // بدء الزيارة أو استكمالها
      DraftVisit? draft = await _draftService.startVisit(
        widget.visitId,
        widget.projectId,
      );

      if (draft != null) {
        setState(() {
          // تحميل البيانات المحفوظة
          _descriptionController.text = draft.description;
          _notesController.text = draft.notes;
          _images = draft.images.isNotEmpty
              ? draft.images
              : widget.capturedImages;
          _contactCustomer = draft.contactCustomer;
          _contactContractor = draft.contactContractor;
        });

        debugPrint('📋 Loaded draft visit data: ${draft.toString()}');

        // إضافة listeners للحفظ التلقائي
        _setupAutoSaveListeners();
      }
    } catch (e) {
      debugPrint('❌ Error initializing draft visit: $e');
      // في حالة الخطأ، استخدم الصور المرسلة
      setState(() {
        _images = widget.capturedImages;
      });
    }
  }

  /// إعداد listeners للحفظ التلقائي
  void _setupAutoSaveListeners() {
    // حفظ تلقائي عند تغيير النص
    _descriptionController.addListener(() {
      _saveCurrentState();
    });

    _notesController.addListener(() {
      _saveCurrentState();
    });
  }

  /// حفظ الحالة الحالية
  void _saveCurrentState() async {
    try {
      await _draftService.updateCurrentVisit(
        description: _descriptionController.text,
        notes: _notesController.text,
        images: _images,
        contactCustomer: _contactCustomer,
        contactContractor: _contactContractor,
      );
    } catch (e) {
      debugPrint('❌ Error saving current state: $e');
    }
  }

  void _loadVisitDetails() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final result = await authProvider.getVisitDetails(
        widget.visitId.toString(),
      );

      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _customerName = result['data']['customer_name'] ?? 'غير محدد';
          _customerPhone = result['data']['customer_phone'] ?? '';
          _contractorPhone = result['data']['contractor_phone'] ?? '';
          _isLoadingDetails = false;
        });

        debugPrint('📋 Visit details loaded: Customer: $_customerName');
      } else {
        setState(() {
          _customerName = 'غير محدد';
          _isLoadingDetails = false;
        });
        debugPrint('❌ Failed to load visit details: ${result['message']}');
      }
    } catch (e) {
      setState(() {
        _customerName = 'خطأ في التحميل';
        _isLoadingDetails = false;
      });
      debugPrint('❌ Error loading visit details: $e');
    }
  }

  /// Toggle edit icons visibility
  void _toggleEditIcons() {
    setState(() {
      _showEditIcons = !_showEditIcons;
      _isLongPressed = false;
    });
  }

  /// Handle long press to show delete icons
  void _handleLongPress() {
    setState(() {
      _showEditIcons = true;
      _isLongPressed = true;
    });
  }

  /// Delete image at specific index
  void _deleteImage(int index) {
    if (index == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن حذف الصورة الأولى',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'حذف الصورة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: Text('هل تريد حذف هذه الصورة؟', style: GoogleFonts.cairo()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // حفظ مسار الصورة قبل الحذف
                String imagePath = _images[index];

                setState(() {
                  _images.removeAt(index);
                  if (_currentImageIndex >= _images.length &&
                      _images.isNotEmpty) {
                    _currentImageIndex = _images.length - 1;
                    _pageController.animateToPage(
                      _currentImageIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                  _showEditIcons = false;
                  _isLongPressed = false;
                });

                // حذف من خدمة الحفظ المحلي
                if (imagePath.endsWith('.mp4') || imagePath.endsWith('.mov')) {
                  await _draftService.removeVideo(imagePath);
                } else {
                  await _draftService.removeImage(imagePath);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حذف الصورة وحذفها من التخزين المحلي',
                      style: GoogleFonts.cairo(),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// Edit/Crop image at specific index using flutter_photo_editor
  Future<void> _editImage(int index) async {
    try {
      final result = await FlutterPhotoEditor().editImage(_images[index]);

      if (result == true) {
        // The image was edited successfully, but the path remains the same
        // flutter_photo_editor modifies the original file

        // Save updated images to SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setStringList("imagesSaved_${widget.visitId}", _images);

        // Force UI refresh to show the edited image
        setState(() {
          // Trigger rebuild to reload the image
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تعديل الصورة بنجاح! 🎨',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إلغاء التعديل', style: GoogleFonts.cairo()),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error editing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تعديل الصورة',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Build edit icon for image
  Widget _buildEditIcon(int index) {
    return GestureDetector(
      onTap: () => _editImage(index),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Iconsax.edit, color: Theme.of(context).cardColor, size: 20),
      ),
    );
  }

  /// Build delete icon for image
  Widget _buildDeleteIcon(int index) {
    // Don't show delete icon for first image
    if (index == 0) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: Icon(Iconsax.lock, color: Theme.of(context).cardColor, size: 20),
      );
    }

    return GestureDetector(
      onTap: () => _deleteImage(index),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Iconsax.trash,
          color: Theme.of(context).cardColor,
          size: 20,
        ),
      ),
    );
  }

  /// Check if file is a video
  bool _isVideoFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['mp4', 'mov', 'avi', 'mkv', '3gp'].contains(extension);
  }

  /// Build video player widget with thumbnail
  Widget _buildVideoPlayer(String videoPath) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video thumbnail
          FutureBuilder<String?>(
            future: _generateVideoThumbnail(videoPath),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.file(
                  File(snapshot.data!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                );
              } else {
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black,
                  child: Icon(
                    Iconsax.video_play,
                    color: Theme.of(context).cardColor,
                    size: 64,
                  ),
                );
              }
            },
          ),
          // Play button overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _playVideo(videoPath),
              icon: Icon(
                Iconsax.play,
                color: Theme.of(context).cardColor,
                size: 32,
              ),
            ),
          ),
          // Video indicator
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.video,
                    color: Theme.of(context).cardColor,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'فيديو 15 ث',
                    style: GoogleFonts.cairo(
                      color: Theme.of(context).cardColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Duration indicator
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '0:15',
                style: GoogleFonts.cairo(
                  color: Theme.of(context).cardColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Generate video thumbnail
  Future<String?> _generateVideoThumbnail(String videoPath) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        quality: 75,
      );
      return thumbnail;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Play video in simple fullscreen player
  void _playVideo(String videoPath) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SimpleVideoPlayer(videoPath: videoPath),
      ),
    );
  }

  /// Show camera options bottom sheet
  void _showCameraOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.borderDark
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'اختر نوع الوسائط',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Photo option
            _buildBottomSheetOption(
              icon: Iconsax.camera,
              title: 'التقاط صورة',
              subtitle: 'التقط صورة جديدة بالكاميرا',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _captureImageFromCamera();
              },
            ),

            const SizedBox(height: 16),

            // Video option
            _buildBottomSheetOption(
              icon: Iconsax.video,
              title: 'تسجيل فيديو',
              subtitle: 'سجل فيديو جديد (15 ثانية)',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                _captureVideoFromCamera();
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Show gallery options bottom sheet
  void _showGalleryOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.borderDark
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'اختر من المعرض',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Photos option
            _buildBottomSheetOption(
              icon: Iconsax.gallery,
              title: 'صور من المعرض',
              subtitle: 'اختر صور محفوظة من الجاليري',
              color: AppColors.secondary,
              onTap: () {
                Navigator.pop(context);
                _pickImagesFromGallery();
              },
            ),

            const SizedBox(height: 16),

            // Videos option
            _buildBottomSheetOption(
              icon: Iconsax.video_play,
              title: 'فيديو من المعرض',
              subtitle: 'اختر فيديو محفوظ من الجاليري',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _pickVideoFromGallery();
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Build bottom sheet option
  Widget _buildBottomSheetOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Theme.of(context).cardColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_left_2, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    _pageController.dispose();
    _draftService.dispose();
    super.dispose();
  }

  /// التقاط صورة من الكاميرا باستخدام الشاشة المخصصة
  Future<void> _captureImageFromCamera() async {
    try {
      final result = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(
          builder: (context) => AdditionalCameraScreen(
            visitId: widget.visitId,
            existingImages: _images,
          ),
        ),
      );

      if (result != null && result.isNotEmpty) {
        setState(() {
          _images.addAll(result);
        });

        // حفظ الصور الجديدة في خدمة الحفظ المحلي
        for (String imagePath in result) {
          await _draftService.addImage(imagePath);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إضافة ${result.length} صورة جديدة وحفظها تلقائياً',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في التقاط الصورة', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// تسجيل فيديو من الكاميرا مع حد أقصى 15 ثانية
  Future<void> _captureVideoFromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15), // حد أقصى 15 ثانية
      );

      if (video != null) {
        setState(() {
          _images.add(video.path); // Add video to images list for display
        });

        // حفظ الفيديو في خدمة الحفظ المحلي
        await _draftService.addVideo(video.path);

        // Move to the new video in the slider
        Future.delayed(const Duration(milliseconds: 100), () {
          _pageController.animateToPage(
            _images.length - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تسجيل فيديو ${_images.length} (15 ثانية) 🎥',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.purple,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error capturing video from camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تسجيل الفيديو',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// اختيار فيديو من الجاليري
  Future<void> _pickVideoFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        setState(() {
          _images.add(video.path); // Add video to images list for display
        });

        // حفظ الفيديو في خدمة الحفظ المحلي
        await _draftService.addVideo(video.path);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إضافة الفيديو بنجاح! 🎥',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking video from gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء اختيار الفيديو',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// اختيار صور من الجاليري
  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final directory = Directory(
          '/data/data/com.qcec.compania/app_flutter/visits/${widget.visitId}',
        );
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        for (int i = 0; i < pickedFiles.length; i++) {
          final fileName = '${_images.length + i + 1}.jpg';
          final newPath = '${directory.path}/$fileName';

          // نسخ الملف للمجلد المطلوب
          await File(pickedFiles[i].path).copy(newPath);

          setState(() {
            _images.add(newPath);
          });
        }

        // انتقال للصورة الأخيرة
        Future.delayed(const Duration(milliseconds: 100), () {
          _pageController.animateToPage(
            _images.length - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إضافة ${pickedFiles.length} صورة',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في اختيار الصور', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Hide keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceDark.withOpacity(0.5)
              : Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Theme.of(context).cardColor,
            elevation: 0,
            leading: IconButton(
              onPressed: _deleteVisitAndExit,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Iconsax.close_circle, color: Colors.red, size: 20),
              ),
              tooltip: 'حذف الزيارة والخروج',
            ),
            title: _isLoadingDetails
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'جاري التحميل...',
                        style: GoogleFonts.cairo(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: _showCustomersBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(51),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withAlpha(102),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              _customerName.isNotEmpty
                                  ? _customerName
                                  : 'اختر العميل',
                              style: GoogleFonts.cairo(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Iconsax.arrow_down_1,
                            color: AppColors.primary,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description Field with dropdown
                _buildDescriptionField(),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _notesController,
                  icon: Iconsax.note,
                  maxLines: 3,
                ),

                const SizedBox(height: 24),

                // Images Section
                if (_images.isNotEmpty) ...[
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _toggleEditIcons,
                            onLongPress: _handleLongPress,
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentImageIndex = index;
                                });
                              },
                              itemCount: _images.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    _isVideoFile(_images[index])
                                        ? _buildVideoPlayer(_images[index])
                                        : Image.file(
                                            File(_images[index]),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                    // Edit/Delete icons overlay for each image
                                    if (_showEditIcons &&
                                        index == _currentImageIndex)
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          child: _isLongPressed
                                              ? _buildDeleteIcon(index)
                                              : _buildEditIcon(index),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          // Image counter
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_currentImageIndex + 1} / ${_images.length}',
                                style: GoogleFonts.cairo(
                                  color: Theme.of(context).cardColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Edit mode indicator
                          if (_showEditIcons)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _isLongPressed
                                      ? Colors.red.withOpacity(0.8)
                                      : Colors.blue.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _isLongPressed ? 'وضع الحذف' : 'وضع التعديل',
                                  style: GoogleFonts.cairo(
                                    color: Theme.of(context).cardColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Dots Indicator and Counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _images.length,
                      (index) => GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentImageIndex == index ? 12 : 8,
                          height: _currentImageIndex == index ? 12 : 8,
                          decoration: BoxDecoration(
                            color: _currentImageIndex == index
                                ? AppColors.primary
                                : Theme.of(context).brightness ==
                                      Brightness.dark
                                ? AppColors.textHintDark
                                : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // أزرار إضافة الصور
                  _buildAddImageButtons(),

                  const SizedBox(height: 16),

                  // Contact Checkboxes
                  _buildMessagingOptions(),

                  SizedBox(height: 10),

                  Container(
                    width: double.maxFinite,
                    child: ElevatedButton(
                      onPressed: _saveVisit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        'حفظ الزيارة',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // No images placeholder
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.borderDark
                            : Colors.grey[300]!,
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.gallery_slash,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.textHintDark
                                : Colors.grey[400],
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد صور',
                            style: GoogleFonts.cairo(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.textSecondaryDark
                                  : Colors.grey[500],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء أزرار إضافة الوسائط المبسطة
  Widget _buildAddImageButtons() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Row(
          children: [
            // زر وسائط من الكاميرا
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showCameraOptions,
                icon: Icon(Iconsax.camera, color: Colors.white, size: 24),
                label: Text(
                  'وسائط من الكاميرا',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.isDarkMode
                      ? AppColors.secondaryDark
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // زر وسائط من الجاليري
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showGalleryOptions,
                icon: Icon(Iconsax.gallery, color: Colors.white, size: 24),
                label: Text(
                  'وسائط من الجاليري',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.isDarkMode
                      ? AppColors.secondaryDark
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessagingOptions() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? AppColors.secondaryDark
                : AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  value: _contactCustomer,
                  onChanged: (value) {
                    setState(() {
                      _contactCustomer = value ?? false;
                    });
                    // حفظ تلقائي عند تغيير حالة الاتصال
                    _saveCurrentState();
                  },
                  title: Text('العميل', style: GoogleFonts.cairo(fontSize: 14)),
                  subtitle: _contactCustomer
                      ? Text(
                          _contactCustomer ? _customerPhone : 'غير مفعل',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: _contactCustomer
                                ? AppColors.secondaryDark
                                : Theme.of(context).brightness ==
                                      Brightness.dark
                                ? AppColors.textSecondaryDark
                                : Colors.grey[600],
                          ),
                        )
                      : null,
                  activeColor: AppColors.secondaryDark,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CheckboxListTile(
                  value: _contactContractor,
                  onChanged: (value) {
                    setState(() {
                      _contactContractor = value ?? false;
                    });
                    _saveCurrentState();
                  },
                  title: Text(
                    'المقاول',
                    style: GoogleFonts.cairo(fontSize: 14),
                  ),
                  subtitle: _contactContractor
                      ? Text(
                          _contactContractor ? _contractorPhone : '',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: _contactContractor
                                ? AppColors.secondaryDark
                                : Theme.of(context).brightness ==
                                      Brightness.dark
                                ? AppColors.textSecondaryDark
                                : Colors.grey[600],
                          ),
                        )
                      : null,
                  activeColor: AppColors.secondaryDark,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDescriptionField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackgroundDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withAlpha(50)
                    : Colors.black.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 3,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: isDark ? AppColors.textPrimaryDark : Colors.grey[800],
            ),
            onChanged: (value) => _updateDescription(value),
            decoration: InputDecoration(
              hintText: 'الوصف',
              hintStyle: GoogleFonts.cairo(
                color: isDark ? AppColors.textHintDark : Colors.grey[500],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Iconsax.document_text,
                color: AppColors.primary,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                  size: 24,
                ),
                onPressed: _showDescriptionBottomSheet,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? AppColors.cardBackgroundDark : Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackgroundDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withAlpha(50)
                    : Colors.black.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: isDark ? AppColors.textPrimaryDark : Colors.grey[800],
            ),
            onChanged: (value) => _updateNotes(value),
            decoration: InputDecoration(
              hintText: "الملاحظات",
              hintStyle: GoogleFonts.cairo(
                color: isDark ? AppColors.textHintDark : Colors.grey[500],
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? AppColors.cardBackgroundDark : Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  void _updateDescription(String value) async {
    if (value.trim().isEmpty) return;

    try {
      await dio.post(
        'https://qcec.online/app2026/sql.php',
        data: {
          'action': 'update_visit_description',
          'visit_id': widget.visitId.toString(),
          'description': value.trim(),
        },
      );
    } catch (e) {
      debugPrint('Error updating description: $e');
    }
  }

  void _updateNotes(String value) async {
    if (value.trim().isEmpty) return;

    try {
      await dio.post(
        'https://qcec.online/app2026/sql.php',
        data: {
          'action': 'update_visit_notes',
          'visit_id': widget.visitId.toString(),
          'notes': value.trim(),
        },
      );
    } catch (e) {
      debugPrint('Error updating notes: $e');
    }
  }

  void _showDescriptionBottomSheet() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Fetch vlist data
      final response = await dio.post(
        'https://qcec.online/app2026/sql.php',
        data: {'action': 'get_vlist'},
      );

      if (mounted) Navigator.pop(context);

      if (response.data['success'] == true) {
        final List<String> vlistData = List<String>.from(
          response.data['data'] ?? [],
        );

        if (mounted) {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return Container(
                  color: themeProvider.isDarkMode
                      ? AppColors.primaryDark
                      : AppColors.primary,
                  padding: const EdgeInsets.all(20),
                  height: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختر وصف من القائمة',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textPrimaryDark
                              : Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: vlistData.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(
                                vlistData[index],
                                style: GoogleFonts.cairo(fontSize: 14),
                              ),
                              onTap: () {
                                _descriptionController.text = vlistData[index];
                                _updateDescription(
                                  vlistData[index],
                                ); // تحديث في قاعدة البيانات
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'خطأ في جلب البيانات: ${response.data['message'] ?? 'خطأ غير معروف'}',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الاتصال: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveVisit() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إدخال وصف الزيارة', style: GoogleFonts.cairo()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'جاري حفظ الزيارة ورفع الصور...',
              style: GoogleFonts.cairo(fontSize: 16),
            ),
          ],
        ),
      ),
    );

    try {
      // Save visit data to SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        "visit_${widget.visitId}_description",
        _descriptionController.text,
      );
      await prefs.setString(
        "visit_${widget.visitId}_notes",
        _notesController.text,
      );
      await prefs.setStringList("visit_${widget.visitId}_images", _images);

      // بدء رفع الوسائط (صور وفيديوهات) في الخلفية
      if (_images.isNotEmpty) {
        debugPrint(
          '📤 Starting background upload for ${_images.length} media files',
        );
        // UploadService.uploadVisitMediaInBackground(
        //   visitId: widget.visitId,
        //   mediaPaths: _images,
        // );

        // // بدء إرسال التقارير في الخلفية (بعد رفع الصور)
        // if (_contactCustomer || _contactContractor) {
        //   debugPrint('📊 Starting background report generation');
        //   // تأخير بسيط للسماح برفع الصور أولاً
        //   Future.delayed(const Duration(seconds: 30), () {
        //     ReportService.sendReportsInBackground(
        //       projectId: widget.projectId.toString(),
        //       visitId: widget.visitId,
        //       imagePaths: _images,
        //       sendToCustomer: _contactCustomer,
        //       sendToContractor: _contactContractor,
        //     );
        //   });
        // }

        String date = "26-09-2025";
        DateTime now = DateTime.now();
        String formattedTime = intlx.DateFormat('hh:mm a').format(now);

        var imagesCopy = List<String>.from(_images);

        String visitIdCopy = widget.visitId.toString();

        String _contPhone = "";
        String _custPhone = "";

        _contactContractor ? _contPhone = _contractorPhone : _contPhone = '';
        _contactCustomer ? _custPhone = _customerPhone : _custPhone = '';

        // إعداد البيانات بدون await
        Map<String, dynamic> data = {
          'visitId': visitIdCopy,
          'sendCmob': _custPhone,
          'sendCNmob': _contPhone,
          'desc': _descriptionController.text,
          'notes': _notesController.text,
          'images': imagesCopy,
          'date': date,
          'time': formattedTime,
        };

        startBackgroundTasks(data);
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _images.isNotEmpty
                  ? (_contactCustomer || _contactContractor)
                        ? 'تم حفظ الزيارة وبدء رفع ${_images.length} صورة وإرسال التقارير في الخلفية'
                        : 'تم حفظ الزيارة وبدء رفع ${_images.length} صورة في الخلفية'
                  : 'تم حفظ الزيارة بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // // Get current location and update visitsx table

      // // إنهاء الزيارة وحذف البيانات المؤقتة
      await _draftService.completeVisit(widget.visitId);
      debugPrint('✅ Visit completed and draft data cleaned up');

      // // Return to main screen
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الزيارة: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _deleteVisitAndExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Iconsax.warning_2, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Text(
              'حذف الزيارة',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف هذه الزيارة؟\n\nسيتم حذف جميع الصور والبيانات المرتبطة بها من قاعدة البيانات.',
          style: GoogleFonts.cairo(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'جاري حذف الزيارة...',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              // Delete from database first
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final deleteResult = await authProvider.deleteVisit(
                widget.visitId.toString(),
              );

              // إلغاء الزيارة وحذف جميع البيانات المؤقتة والملفات
              await _draftService.cancelVisit(widget.visitId);
              debugPrint('❌ Visit cancelled and all data cleaned up');

              // Close loading dialog and return to main screen immediately
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MainScreen()),
                );

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      deleteResult['success'] == true
                          ? 'تم حذف الزيارة بنجاح من قاعدة البيانات'
                          : 'تم حذف البيانات المحلية (${deleteResult['message'] ?? 'خطأ في قاعدة البيانات'})',
                      style: GoogleFonts.cairo(),
                    ),
                    backgroundColor: deleteResult['success'] == true
                        ? Colors.green
                        : Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );

                // Return to main screen immediately
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MainScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(
                color: Theme.of(context).cardColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return Container(
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? AppColors.surfaceDark
                        : Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.borderDark
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.people,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'عملاء المهندس',
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textPrimaryDark
                                    : Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Iconsax.close_circle),
                            ),
                          ],
                        ),
                      ),

                      // Customers list
                      Expanded(
                        child: FutureBuilder<Map<String, dynamic>>(
                          future: Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          ).getEngineerCustomers(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'جاري تحميل العملاء...',
                                      style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.textSecondaryDark
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (snapshot.hasError ||
                                !snapshot.hasData ||
                                snapshot.data!['success'] != true) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Iconsax.info_circle,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.textHintDark
                                          : Colors.grey[400],
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'لا توجد عملاء',
                                      style: GoogleFonts.cairo(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.textSecondaryDark
                                            : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'لم يتم العثور على عملاء لهذا المهندس',
                                      style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.textSecondaryDark
                                            : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final customers = snapshot.data!['data'] as List;

                            return ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: customers.length,
                              itemBuilder: (context, index) {
                                final customer = customers[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: themeProvider.isDarkMode
                                        ? AppColors.primaryDark
                                        : AppColors.pureWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.surfaceDark.withOpacity(
                                              0.8,
                                            )
                                          : Colors.grey[200]!,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withAlpha(51),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Iconsax.user,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                    ),
                                    title: Text(
                                      customer['customer_name'] ?? 'غير محدد',
                                      style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.textPrimaryDark
                                            : Colors.grey[800],
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (customer['customer_phone'] !=
                                            null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Iconsax.call,
                                                color: Colors.green,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                customer['customer_phone'],
                                                style: GoogleFonts.cairo(
                                                  fontSize: 14,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? AppColors
                                                            .textSecondaryDark
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (customer['contractor_name'] !=
                                            null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Iconsax.buildings,
                                                color: Colors.orange,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'مقاول: ${customer['contractor_name']}',
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 14,
                                                    color:
                                                        Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? AppColors
                                                              .textSecondaryDark
                                                        : Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    onTap: () async {
                                      // Show loading
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(
                                                  color: AppColors.primary,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'جاري تحديث بيانات الزيارة...',
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );

                                      // Update project ID in database
                                      final authProvider =
                                          Provider.of<AuthProvider>(
                                            context,
                                            listen: false,
                                          );
                                      final updateResult = await authProvider
                                          .updateVisitProject(
                                            widget.visitId.toString(),
                                            customer['project_id'].toString(),
                                          );

                                      Navigator.pop(context); // Close loading
                                      Navigator.pop(
                                        context,
                                      ); // Close bottom sheet

                                      if (updateResult['success'] == true) {
                                        setState(() {
                                          _customerName =
                                              customer['customer_name'] ??
                                              'غير محدد';
                                          _customerPhone =
                                              customer['customer_phone'] ?? '';
                                          _contractorPhone =
                                              customer['contractor_phone'] ??
                                              '';
                                        });

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'تم اختيار العميل وتحديث المشروع: $_customerName',
                                              style: GoogleFonts.cairo(),
                                            ),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'تم اختيار العميل لكن فشل تحديث المشروع: ${updateResult['message'] ?? 'خطأ غير معروف'}',
                                              style: GoogleFonts.cairo(),
                                            ),
                                            backgroundColor: Colors.orange,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Update visit location in visitsx table
}
