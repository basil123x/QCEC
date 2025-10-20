import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:QCEC/core/constants/app_colors.dart';

class AdditionalCameraScreen extends StatefulWidget {
  final int visitId;
  final List<String> existingImages;

  const AdditionalCameraScreen({
    Key? key,
    required this.visitId,
    required this.existingImages,
  }) : super(key: key);

  @override
  State<AdditionalCameraScreen> createState() => _AdditionalCameraScreenState();
}

class _AdditionalCameraScreenState extends State<AdditionalCameraScreen> {
  List<String> newImages = [];
  int photoCounter = 1;

  @override
  void initState() {
    super.initState();
    // بدء العداد من بعد الصور الموجودة
    photoCounter = widget.existingImages.length + 1;
  }

  // هنا بنبني الـ CaptureRequest ونرجع الـ filePath
  Future<CaptureRequest> _captureRequestBuilder(List<Sensor> sensors) async {
    final dir = await getApplicationDocumentsDirectory();
    final visitDir = Directory('${dir.path}/visits/${widget.visitId}');

    // إنشاء مجلد الزيارة إذا لم يكن موجود
    if (!await visitDir.exists()) {
      await visitDir.create(recursive: true);
    }

    final filePath = '${visitDir.path}/$photoCounter.jpg';
    return SingleCaptureRequest(filePath, sensors.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraAwesomeBuilder.awesome(
            saveConfig: SaveConfig.photo(pathBuilder: _captureRequestBuilder),
            onMediaCaptureEvent: (MediaCapture capture) async {
              final file = File(capture.captureRequest.path!);

              if (await file.exists() && mounted) {
                debugPrint('📸 Additional photo captured: ${file.path}');

                setState(() {
                  newImages.add(file.path);
                  photoCounter++;
                });

                // Show success feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم التقاط الصورة ${widget.existingImages.length + newImages.length} ✅',
                      style: GoogleFonts.cairo(),
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            bottomActionsBuilder: (state) {
              return _buildBottomActions(state);
            },
            topActionsBuilder: (state) {
              return _buildTopActions(state);
            },
            middleContentBuilder: (state) {
              return Container();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopActions(CameraState state) {
    final totalImages = widget.existingImages.length + newImages.length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            IconButton(
              onPressed: () {
                Navigator.pop(context, newImages);
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Iconsax.arrow_right_3,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),

            // Visit info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.camera, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'إضافة صور - زيارة ${widget.visitId}',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Photos counter
            if (totalImages > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '$totalImages',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(width: 40), // Placeholder for symmetry
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(CameraState state) {
    final totalImages = widget.existingImages.length + newImages.length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photos counter text
            if (totalImages > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'إجمالي الصور: $totalImages (${newImages.length} جديدة)',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery preview
                GestureDetector(
                  onTap: newImages.isNotEmpty ? _showGallery : null,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: newImages.isNotEmpty
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: newImages.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Image.file(
                                  File(newImages.last),
                                  fit: BoxFit.cover,
                                  width: 60,
                                  height: 60,
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '+${newImages.length}',
                                      style: GoogleFonts.cairo(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Icon(
                            Iconsax.gallery,
                            color: Colors.white.withOpacity(0.5),
                            size: 24,
                          ),
                  ),
                ),

                // Capture button - خلي CamerAwesome يعمل capture لوحده
                AwesomeCaptureButton(state: state),

                // Finish button
                GestureDetector(
                  onTap: _finishCapture,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: newImages.isNotEmpty
                          ? Colors.green
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      newImages.isNotEmpty ? Iconsax.tick_circle : Iconsax.arrow_right_3,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGallery() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'الصور الجديدة (${newImages.length})',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
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

            // Images grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: newImages.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.file(
                          File(newImages[index]),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'جديدة ${index + 1}',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _finishCapture() {
    Navigator.pop(context, newImages);
  }
}
