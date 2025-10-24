import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/draft_visit.dart';

/// خدمة إدارة الزيارات المؤقتة والحفظ المحلي
class DraftVisitService {
  static const String _draftKeyPrefix = 'draft_visit_';
  static const String _activeVisitKey = 'active_visit_id';
  static const String _mediaFolderPrefix = 'visit_media_';
  
  // Singleton pattern
  static final DraftVisitService _instance = DraftVisitService._internal();
  factory DraftVisitService() => _instance;
  DraftVisitService._internal();

  SharedPreferences? _prefs;
  Timer? _autoSaveTimer;
  DraftVisit? _currentDraft;

  /// تهيئة الخدمة
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    debugPrint('🔧 DraftVisitService initialized');
  }

  /// بدء زيارة جديدة أو استكمال موجودة
  Future<DraftVisit?> startVisit(int visitId, int projectId) async {
    await initialize();
    
    // التحقق من وجود زيارة مؤقتة
    DraftVisit? existingDraft = await getDraft(visitId);
    
    if (existingDraft != null) {
      debugPrint('📋 Found existing draft for visit $visitId');
      _currentDraft = existingDraft.copyWith(
        status: 'in_progress',
        lastModified: DateTime.now(),
      );
    } else {
      debugPrint('🆕 Creating new draft for visit $visitId');
      _currentDraft = DraftVisit(
        visitId: visitId,
        projectId: projectId,
        status: 'in_progress',
      );
    }

    // حفظ معرف الزيارة النشطة
    await _prefs!.setInt(_activeVisitKey, visitId);
    
    // بدء الحفظ التلقائي
    _startAutoSave();
    
    // حفظ الحالة الحالية
    await _saveDraft(_currentDraft!);
    
    return _currentDraft;
  }

  /// حفظ تحديث للزيارة الحالية
  Future<void> updateCurrentVisit({
    String? description,
    String? notes,
    List<String>? images,
    List<String>? videos,
    bool? contactCustomer,
    bool? contactContractor,
  }) async {
    if (_currentDraft == null) return;

    _currentDraft = _currentDraft!.copyWith(
      description: description,
      notes: notes,
      images: images,
      videos: videos,
      contactCustomer: contactCustomer,
      contactContractor: contactContractor,
      lastModified: DateTime.now(),
    );

    await _saveDraft(_currentDraft!);
    debugPrint('💾 Draft updated for visit ${_currentDraft!.visitId}');
  }

  /// إضافة صورة للزيارة الحالية
  Future<void> addImage(String imagePath) async {
    if (_currentDraft == null) return;

    List<String> updatedImages = List.from(_currentDraft!.images);
    updatedImages.add(imagePath);

    await updateCurrentVisit(images: updatedImages);
    debugPrint('📸 Added image to visit ${_currentDraft!.visitId}: $imagePath');
  }

  /// إضافة فيديو للزيارة الحالية
  Future<void> addVideo(String videoPath) async {
    if (_currentDraft == null) return;

    List<String> updatedVideos = List.from(_currentDraft!.videos);
    updatedVideos.add(videoPath);

    await updateCurrentVisit(videos: updatedVideos);
    debugPrint('🎥 Added video to visit ${_currentDraft!.visitId}: $videoPath');
  }

  /// حذف صورة من الزيارة الحالية
  Future<void> removeImage(String imagePath) async {
    if (_currentDraft == null) return;

    List<String> updatedImages = List.from(_currentDraft!.images);
    updatedImages.remove(imagePath);

    await updateCurrentVisit(images: updatedImages);
    
    // حذف الملف من النظام
    try {
      File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
        debugPrint('🗑️ Deleted image file: $imagePath');
      }
    } catch (e) {
      debugPrint('❌ Error deleting image file: $e');
    }
  }

  /// حذف فيديو من الزيارة الحالية
  Future<void> removeVideo(String videoPath) async {
    if (_currentDraft == null) return;

    List<String> updatedVideos = List.from(_currentDraft!.videos);
    updatedVideos.remove(videoPath);

    await updateCurrentVisit(videos: updatedVideos);
    
    // حذف الملف من النظام
    try {
      File videoFile = File(videoPath);
      if (await videoFile.exists()) {
        await videoFile.delete();
        debugPrint('🗑️ Deleted video file: $videoPath');
      }
    } catch (e) {
      debugPrint('❌ Error deleting video file: $e');
    }
  }

  /// الحصول على الزيارة المؤقتة
  Future<DraftVisit?> getDraft(int visitId) async {
    await initialize();
    
    String? draftJson = _prefs!.getString('$_draftKeyPrefix$visitId');
    if (draftJson != null) {
      try {
        return DraftVisit.fromJsonString(draftJson);
      } catch (e) {
        debugPrint('❌ Error parsing draft visit: $e');
        return null;
      }
    }
    return null;
  }

  /// الحصول على الزيارة النشطة الحالية
  DraftVisit? get currentDraft => _currentDraft;

  /// الحصول على معرف الزيارة النشطة
  Future<int?> getActiveVisitId() async {
    await initialize();
    return _prefs!.getInt(_activeVisitKey);
  }

  /// إنهاء الزيارة وحذف البيانات المؤقتة
  Future<void> completeVisit(int visitId) async {
    await initialize();
    
    // إيقاف الحفظ التلقائي
    _stopAutoSave();
    
    // حذف البيانات المؤقتة
    await _deleteDraft(visitId);
    
    // حذف معرف الزيارة النشطة
    await _prefs!.remove(_activeVisitKey);
    
    // حذف ملفات الوسائط المؤقتة إذا لزم الأمر
    await _cleanupMediaFiles(visitId);
    
    _currentDraft = null;
    debugPrint('✅ Visit $visitId completed and draft cleaned up');
  }

  /// إلغاء الزيارة وحذف جميع البيانات
  Future<void> cancelVisit(int visitId) async {
    await initialize();
    
    // إيقاف الحفظ التلقائي
    _stopAutoSave();
    
    // حذف جميع البيانات والملفات
    await _deleteDraft(visitId);
    await _cleanupMediaFiles(visitId);
    await _prefs!.remove(_activeVisitKey);
    
    _currentDraft = null;
    debugPrint('❌ Visit $visitId cancelled and all data cleaned up');
  }

  /// الحصول على جميع الزيارات المؤقتة
  Future<List<DraftVisit>> getAllDrafts() async {
    await initialize();
    
    List<DraftVisit> drafts = [];
    Set<String> keys = _prefs!.getKeys();
    
    for (String key in keys) {
      if (key.startsWith(_draftKeyPrefix)) {
        String? draftJson = _prefs!.getString(key);
        if (draftJson != null) {
          try {
            drafts.add(DraftVisit.fromJsonString(draftJson));
          } catch (e) {
            debugPrint('❌ Error parsing draft: $e');
          }
        }
      }
    }
    
    // ترتيب حسب آخر تعديل
    drafts.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    
    return drafts;
  }

  /// حذف جميع الزيارات المؤقتة القديمة (أكثر من 7 أيام)
  Future<void> cleanupOldDrafts() async {
    await initialize();
    
    DateTime cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    List<DraftVisit> allDrafts = await getAllDrafts();
    
    for (DraftVisit draft in allDrafts) {
      if (draft.lastModified.isBefore(cutoffDate)) {
        await _deleteDraft(draft.visitId);
        await _cleanupMediaFiles(draft.visitId);
        debugPrint('🧹 Cleaned up old draft for visit ${draft.visitId}');
      }
    }
  }

  /// حفظ الزيارة المؤقتة
  Future<void> _saveDraft(DraftVisit draft) async {
    await _prefs!.setString(
      '$_draftKeyPrefix${draft.visitId}',
      draft.toJsonString(),
    );
  }

  /// حذف الزيارة المؤقتة
  Future<void> _deleteDraft(int visitId) async {
    await _prefs!.remove('$_draftKeyPrefix$visitId');
  }

  /// بدء الحفظ التلقائي كل 30 ثانية
  void _startAutoSave() {
    _stopAutoSave(); // إيقاف أي timer موجود
    
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentDraft != null) {
        _saveDraft(_currentDraft!);
        debugPrint('🔄 Auto-saved draft for visit ${_currentDraft!.visitId}');
      }
    });
  }

  /// إيقاف الحفظ التلقائي
  void _stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  /// تنظيف ملفات الوسائط
  Future<void> _cleanupMediaFiles(int visitId) async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory mediaDir = Directory('${appDir.path}/$_mediaFolderPrefix$visitId');
      
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
        debugPrint('🗑️ Cleaned up media files for visit $visitId');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up media files: $e');
    }
  }

  /// إنشاء مجلد للوسائط
  Future<Directory> getMediaDirectory(int visitId) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    Directory mediaDir = Directory('${appDir.path}/$_mediaFolderPrefix$visitId');
    
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    
    return mediaDir;
  }

  /// الحصول على إحصائيات الزيارات المؤقتة
  Future<Map<String, dynamic>> getDraftStats() async {
    List<DraftVisit> drafts = await getAllDrafts();
    
    int totalDrafts = drafts.length;
    int totalImages = drafts.fold(0, (sum, draft) => sum + draft.images.length);
    int totalVideos = drafts.fold(0, (sum, draft) => sum + draft.videos.length);
    int totalDataSize = drafts.fold(0, (sum, draft) => sum + draft.dataSize);
    
    return {
      'totalDrafts': totalDrafts,
      'totalImages': totalImages,
      'totalVideos': totalVideos,
      'totalDataSize': totalDataSize,
      'oldestDraft': drafts.isNotEmpty ? drafts.last.lastModified : null,
      'newestDraft': drafts.isNotEmpty ? drafts.first.lastModified : null,
    };
  }

  /// تصدير الزيارة المؤقتة كـ JSON
  Future<String?> exportDraft(int visitId) async {
    DraftVisit? draft = await getDraft(visitId);
    return draft?.toJsonString();
  }

  /// استيراد زيارة مؤقتة من JSON
  Future<bool> importDraft(String jsonString) async {
    try {
      DraftVisit draft = DraftVisit.fromJsonString(jsonString);
      await _saveDraft(draft);
      debugPrint('📥 Imported draft for visit ${draft.visitId}');
      return true;
    } catch (e) {
      debugPrint('❌ Error importing draft: $e');
      return false;
    }
  }

  /// تنظيف الخدمة عند إغلاق التطبيق
  void dispose() {
    _stopAutoSave();
    debugPrint('🔧 DraftVisitService disposed');
  }
}
