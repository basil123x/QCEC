import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:QCEC/core/constants/app_colors.dart';
import 'add_visit_screen.dart';

class CameraWorking extends StatefulWidget {
  final int visitId;
  final int projectId;

  const CameraWorking({
    Key? key,
    required this.visitId,
    required this.projectId,
  }) : super(key: key);

  @override
  State<CameraWorking> createState() => _CameraWorkingState();
}

class _CameraWorkingState extends State<CameraWorking> {
  List<String> allImages = [];
  int photoCounter = 1;

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
              SharedPreferences prefx = await SharedPreferences.getInstance();
              final file = File(capture.captureRequest.path!);

              if (await file.exists() && mounted) {
                debugPrint('📸 Photo captured: ${file.path}');

                setState(() {
                  allImages.add(file.path);
                  photoCounter++;
                  prefx.setStringList(
                    "imagesSaved_${widget.visitId}",
                    allImages,
                  );
                });

                // Show success feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم التقاط الصورة ${allImages.length} ✅',
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            IconButton(
              onPressed: () {
                Navigator.pop(context, allImages);
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
                    'زيارة ${widget.visitId}',
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
            if (allImages.isNotEmpty)
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
                  '${allImages.length}',
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photos counter text
            if (allImages.isNotEmpty) ...[
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
                  'تم التقاط ${allImages.length} صورة',
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
                  onTap: allImages.isNotEmpty ? _showGallery : null,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: allImages.isNotEmpty
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: allImages.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Image.file(
                                  File(allImages.last),
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
                                      '${allImages.length}',
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
                  onTap: allImages.isNotEmpty ? _finishCapture : null,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: allImages.isNotEmpty
                          ? Colors.green
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Iconsax.tick_circle,
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
                    'الصور المُلتقطة (${allImages.length})',
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
                itemCount: allImages.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.file(
                          File(allImages[index]),
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
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'صورة ${index + 1}',
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

  void _finishCapture() async {
    // Save to SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("visit_${widget.visitId}_images", allImages);

    Navigator.pop(context); // Close dialog

    // Navigate to Add Visit Screen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddVisitScreen(
          visitId: widget.visitId,
          projectId: widget.projectId,
          capturedImages: allImages,
        ),
      ),
    );

    // If visit was saved successfully, return to main screen
    if (result == true && mounted) {
      Navigator.pop(context, allImages);
    }
  }
}
