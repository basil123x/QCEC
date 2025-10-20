import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

/// ملف اختبار لنظام تسجيل الفيديو مع العد التنازلي
/// يمكن استخدامه لاختبار الوظائف قبل تطبيقها في الكاميرا الرئيسية

class VideoRecordingTestScreen extends StatefulWidget {
  const VideoRecordingTestScreen({Key? key}) : super(key: key);

  @override
  State<VideoRecordingTestScreen> createState() => _VideoRecordingTestScreenState();
}

class _VideoRecordingTestScreenState extends State<VideoRecordingTestScreen> {
  bool _isRecordingVideo = false;
  int _recordingSeconds = 0;
  int _maxVideoDuration = 15;
  Timer? _videoTimer;

  @override
  void dispose() {
    _videoTimer?.cancel();
    super.dispose();
  }

  /// بدء تسجيل الفيديو مع العد التنازلي
  void _startVideoRecording() {
    if (_isRecordingVideo) return;
    
    setState(() {
      _isRecordingVideo = true;
      _recordingSeconds = 0;
    });
    
    // بدء العد التنازلي
    _videoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
        });
        
        // إيقاف التسجيل عند الوصول للحد الأقصى
        if (_recordingSeconds >= _maxVideoDuration) {
          _stopVideoRecording();
        }
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'بدء تسجيل الفيديو (15 ثانية) 🎥',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  /// إيقاف تسجيل الفيديو
  void _stopVideoRecording() {
    if (!_isRecordingVideo) return;
    
    _videoTimer?.cancel();
    _videoTimer = null;
    
    setState(() {
      _isRecordingVideo = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم إيقاف تسجيل الفيديو ✅',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  /// بناء واجهة العد التنازلي
  Widget _buildVideoTimer() {
    if (!_isRecordingVideo) return const SizedBox.shrink();
    
    final remainingSeconds = _maxVideoDuration - _recordingSeconds;
    
    return Positioned(
      top: 120,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.red, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // أيقونة التسجيل
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // العد التنازلي
              Text(
                '${remainingSeconds}s',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              // شريط التقدم
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: remainingSeconds / _maxVideoDuration,
                  child: Container(
                    decoration: BoxDecoration(
                      color: remainingSeconds <= 3 ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'اختبار تسجيل الفيديو',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // محاكاة شاشة الكاميرا
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.video,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'شاشة الكاميرا',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اضغط على زر الفيديو لبدء التسجيل',
                    style: GoogleFonts.cairo(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // العد التنازلي
          _buildVideoTimer(),
          
          // أزرار التحكم
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // زر الصورة
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم التقاط صورة 📸', style: GoogleFonts.cairo()),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Icon(
                      Iconsax.camera,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                ),
                
                const SizedBox(width: 40),
                
                // زر الفيديو
                GestureDetector(
                  onTap: () {
                    if (_isRecordingVideo) {
                      _stopVideoRecording();
                    } else {
                      _startVideoRecording();
                    }
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _isRecordingVideo ? Colors.red : Colors.purple,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRecordingVideo ? Colors.red : Colors.purple, 
                        width: 3
                      ),
                    ),
                    child: Icon(
                      _isRecordingVideo ? Iconsax.stop : Iconsax.video,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // معلومات الحالة
          Positioned(
            top: 100,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حالة التسجيل:',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecordingVideo ? 'جاري التسجيل' : 'متوقف',
                    style: GoogleFonts.cairo(
                      color: _isRecordingVideo ? Colors.red : Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الوقت: ${_recordingSeconds}s / ${_maxVideoDuration}s',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
