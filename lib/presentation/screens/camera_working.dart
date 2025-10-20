import 'dart:io';
import 'dart:async';
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
  int videoCounter = 1;

  // Video recording state
  bool isRecording = false;
  int recordingSeconds = 0;
  Timer? recordingTimer;
  final int maxRecordingSeconds = 15;

  // Mode state
  bool isVideoMode = false;
  Key _cameraKey = UniqueKey();

  @override
  void dispose() {
    recordingTimer?.cancel();
    super.dispose();
  }

  // Build capture request for photos
  Future<CaptureRequest> _captureRequestBuilder(List<Sensor> sensors) async {
    final dir = await getApplicationDocumentsDirectory();
    final visitDir = Directory('${dir.path}/visits/${widget.visitId}');

    if (!await visitDir.exists()) {
      await visitDir.create(recursive: true);
    }

    final filePath = '${visitDir.path}/photo_$photoCounter.jpg';
    return SingleCaptureRequest(filePath, sensors.first);
  }

  // Build capture request for videos
  Future<CaptureRequest> _videoCaptureRequestBuilder(
    List<Sensor> sensors,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final visitDir = Directory('${dir.path}/visits/${widget.visitId}');

    if (!await visitDir.exists()) {
      await visitDir.create(recursive: true);
    }

    final filePath = '${visitDir.path}/video_$videoCounter.mp4';
    return SingleCaptureRequest(filePath, sensors.first);
  }

  void _startRecordingTimer(CameraState state) {
    setState(() {
      isRecording = true;
      recordingSeconds = 0;
    });

    recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        recordingSeconds++;
      });

      // Stop recording after 15 seconds
      if (recordingSeconds >= maxRecordingSeconds) {
        _stopRecording(state);
      }
    });
  }

  void _stopRecording(CameraState state) {
    recordingTimer?.cancel();
    state.when(
      onVideoRecordingMode: (videoState) {
        videoState.stopRecording();
      },
    );

    setState(() {
      isRecording = false;
      recordingSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          KeyedSubtree(
            key: _cameraKey,
            child: CameraAwesomeBuilder.awesome(
              saveConfig: SaveConfig.photoAndVideo(
                initialCaptureMode: isVideoMode ? CaptureMode.video : CaptureMode.photo,
                photoPathBuilder: _captureRequestBuilder,
                videoPathBuilder: _videoCaptureRequestBuilder,
              ),
            onMediaCaptureEvent: (MediaCapture capture) async {
              SharedPreferences prefx = await SharedPreferences.getInstance();
              final file = File(capture.captureRequest.path!);

              if (await file.exists() && mounted) {
                final isVideo = capture.captureRequest.path!.contains('video_');

                debugPrint(
                  '📸 ${isVideo ? "Video" : "Photo"} captured: ${file.path}',
                );

                setState(() {
                  allImages.add(file.path);
                  if (isVideo) {
                    videoCounter++;
                  } else {
                    photoCounter++;
                  }
                  prefx.setStringList(
                    "imagesSaved_${widget.visitId}",
                    allImages,
                  );
                });

                // Show success feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isVideo
                          ? 'تم تسجيل الفيديو ${allImages.where((p) => p.contains('video_')).length} ✅'
                          : 'تم التقاط الصورة ${allImages.where((p) => p.contains('photo_')).length} ✅',
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
              return _buildMiddleContent(state);
            },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleContent(CameraState state) {
    return Column(
      children: [
        // Top section with flash, aspect ratio, and location
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flash button
                state.when(
                  onPhotoMode: (photoState) =>
                      AwesomeFlashButton(state: photoState),
                  onVideoMode: (videoState) =>
                      AwesomeFlashButton(state: videoState),
                  onVideoRecordingMode: (_) => SizedBox(width: 40),
                  onPreparingCamera: (_) => SizedBox(width: 40),
                ),

                // Aspect ratio (وسط) - بس في Photo mode
                state.when(
                  onPhotoMode: (photoState) =>
                      AwesomeAspectRatioButton(state: photoState),
                  onVideoMode: (_) => SizedBox(width: 40),
                  onVideoRecordingMode: (_) => SizedBox(width: 40),
                  onPreparingCamera: (_) => SizedBox(width: 40),
                ),

                // Location button (اليمين) - بس في Photo mode
                state.when(
                  onPhotoMode: (photoState) =>
                      AwesomeLocationButton(state: photoState),
                  onVideoMode: (_) => SizedBox(width: 40),
                  onVideoRecordingMode: (_) => SizedBox(width: 40),
                  onPreparingCamera: (_) => SizedBox(width: 40),
                ),
              ],
            ),
          ),
        ),

        Spacer(),

        // Recording indicator in the middle
        if (isRecording) _buildRecordingIndicator(),

        Spacer(),
      ],
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        '${recordingSeconds}:${(recordingSeconds % 60).toString().padLeft(2, '0')}',
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
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
            // Back button (hidden during recording)
            if (!isRecording)
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
              )
            else
              SizedBox(width: 48),

            // Visit info (hidden during recording)
            if (!isRecording)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
              )
            else
              SizedBox(width: 100),

            // Photos counter (hidden during recording)
            if (allImages.isNotEmpty && !isRecording)
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
              Container(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(CameraState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zoom indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '1.0X',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Gallery preview (top right during video mode)
            if (isVideoMode && !isRecording && allImages.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _showGallery,
                  child: Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildMediaPreview(allImages.last),
                    ),
                  ),
                ),
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Left: Flip camera OR Gallery (photo mode)
                if (!isVideoMode)
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
                                  _buildMediaPreview(allImages.last),
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
                  )
                else if (isRecording)
                  // Pause button during recording
                  GestureDetector(
                    onTap: () => _stopRecording(state),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.pause, color: Colors.white, size: 32),
                    ),
                  )
                else
                  // Flip camera button
                  AwesomeCameraSwitchButton(
                    state: state,
                    scale: 1.0,
                    onSwitchTap: (state) {
                      state.switchCameraSensor();
                    },
                  ),

                // Center: Capture button
                state.when(
                  onPhotoMode: (photoState) =>
                      AwesomeCaptureButton(state: state),
                  onVideoMode: (videoState) => GestureDetector(
                    onTap: () {
                      videoState.startRecording();
                      _startRecordingTimer(state);
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  onVideoRecordingMode: (recordingState) => GestureDetector(
                    onTap: () => _stopRecording(state),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                      ),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  onPreparingCamera: (_) => Container(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),

                // Right: Empty space or Finish button
                if (!isVideoMode)
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
                  )
                else
                  SizedBox(width: 60),
              ],
            ),

            const SizedBox(height: 20),

            // Photo/Video mode toggle
            if (!isRecording)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isVideoMode = false;
                        _cameraKey = UniqueKey(); // Rebuild camera
                      });
                    },
                    child: Text(
                      'PHOTO',
                      style: GoogleFonts.cairo(
                        color: !isVideoMode ? Colors.white : Colors.grey,
                        fontSize: 16,
                        fontWeight: !isVideoMode
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isVideoMode = true;
                        _cameraKey = UniqueKey(); // Rebuild camera
                      });
                    },
                    child: Text(
                      'VIDEO',
                      style: GoogleFonts.cairo(
                        color: isVideoMode ? Colors.white : Colors.grey,
                        fontSize: 16,
                        fontWeight: isVideoMode
                            ? FontWeight.bold
                            : FontWeight.normal,
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

  Widget _buildMediaPreview(String path) {
    final isVideo = path.contains('video_');

    if (isVideo) {
      return Stack(
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: Icon(Iconsax.video_play, color: Colors.white, size: 30),
            ),
          ),
        ],
      );
    } else {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
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
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'الملفات المُلتقطة (${allImages.length})',
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
                  final isVideo = allImages[index].contains('video_');

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        _buildMediaPreview(allImages[index]),
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
                            child: Row(
                              children: [
                                Icon(
                                  isVideo ? Iconsax.video : Iconsax.camera,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isVideo
                                      ? 'فيديو ${index + 1}'
                                      : 'صورة ${index + 1}',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("visit_${widget.visitId}_images", allImages);

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddVisitScreen(
          visitId: widget.visitId,
          projectId: widget.projectId,
          capturedImages: allImages,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, allImages);
    }
  }
}
