import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CleanupService {
  // امسح ملف واحد بعد رفعه مباشرة
  static Future<void> deleteAfterUpload(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // دالة تحسب حجم مجلد
  static Future<double> _getDirSizeMB(Directory dir) async {
    if (!dir.existsSync()) return 0;
    double totalSize = 0;
    try {
      dir.listSync(recursive: true).forEach((file) {
        if (file is File) totalSize += file.lengthSync();
      });
    } catch (_) {}
    return totalSize / (1024 * 1024); // تحويل لـ MB
  }

  static Future<void> scanAllDirectories() async {
    final dirs = {
      'Temp': await getTemporaryDirectory(),
      'AppDoc': await getApplicationDocumentsDirectory(),
      'AppSupport': await getApplicationSupportDirectory(),
      'Cache': await getApplicationCacheDirectory(),
    };

    for (final entry in dirs.entries) {
      final size = await _getDirSizeMB(entry.value);
      print(
        '${entry.key}: ${size.toStringAsFixed(2)} MB → ${entry.value.path}',
      );

      // اطبع الملفات جوا كمان
      if (entry.value.existsSync()) {
        entry.value.listSync(recursive: true).forEach((f) {
          if (f is File) print('   📄 ${f.path} (${f.lengthSync()} bytes)');
        });
      }
    }
  }

  Future<void> deleteVisitFolder(String visitId) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final visitFolder = Directory('${appDocDir.path}/visits/$visitId');

    if (await visitFolder.exists()) {
      await visitFolder.delete(recursive: true);
      print('✅ تم مسح مجلد الزيارة: $visitId');
    }
  }

  // المسح مع تحقق
  static Future<void> clearAll(BuildContext context) async {
    final tempDir = await getTemporaryDirectory();

    // قبل المسح
    final double before = await _getDirSizeMB(tempDir);

    // المسح
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    await DefaultCacheManager().emptyCache();
    imageCache.clear();
    imageCache.clearLiveImages();

    // بعد المسح
    final double after = await _getDirSizeMB(tempDir);

    print('قبل: ${before.toStringAsFixed(2)} MB');
    print('بعد: ${after.toStringAsFixed(2)} MB');
    print('اتمسح: ${(before - after).toStringAsFixed(2)} MB');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم مسح ${(before - after).toStringAsFixed(2)} MB ✓'),
      ),
    );
  }
}
