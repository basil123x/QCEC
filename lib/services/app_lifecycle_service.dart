import 'package:flutter/widgets.dart';
import 'draft_visit_service.dart';

/// خدمة إدارة دورة حياة التطبيق والحفظ المحلي
class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  final DraftVisitService _draftService = DraftVisitService();
  bool _isInitialized = false;

  /// تهيئة الخدمة
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // تهيئة خدمة الحفظ المحلي
      await _draftService.initialize();
      
      // إضافة observer لدورة حياة التطبيق
      WidgetsBinding.instance.addObserver(this);
      
      // تنظيف البيانات القديمة
      await _draftService.cleanupOldDrafts();
      
      _isInitialized = true;
      debugPrint('🚀 AppLifecycleService initialized successfully');
      
      // طباعة إحصائيات البيانات المحفوظة
      await _printDraftStats();
      
    } catch (e) {
      debugPrint('❌ Error initializing AppLifecycleService: $e');
    }
  }

  /// طباعة إحصائيات الزيارات المؤقتة
  Future<void> _printDraftStats() async {
    try {
      Map<String, dynamic> stats = await _draftService.getDraftStats();
      debugPrint('📊 Draft Stats: $stats');
    } catch (e) {
      debugPrint('❌ Error getting draft stats: $e');
    }
  }

  /// التعامل مع تغييرات دورة حياة التطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed');
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        debugPrint('⏸️ App paused');
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        debugPrint('🔌 App detached');
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
        debugPrint('😴 App inactive');
        break;
      case AppLifecycleState.hidden:
        debugPrint('🫥 App hidden');
        break;
    }
  }

  /// عند استئناف التطبيق
  void _onAppResumed() async {
    try {
      // التحقق من وجود زيارة نشطة
      int? activeVisitId = await _draftService.getActiveVisitId();
      if (activeVisitId != null) {
        debugPrint('🔄 Found active visit: $activeVisitId');
        // يمكن إضافة منطق لإظهار إشعار أو استكمال الزيارة
      }
    } catch (e) {
      debugPrint('❌ Error on app resumed: $e');
    }
  }

  /// عند إيقاف التطبيق مؤقتاً
  void _onAppPaused() async {
    try {
      // حفظ أي بيانات معلقة
      debugPrint('💾 Saving pending data on app pause');
      // خدمة الحفظ التلقائي ستتولى هذا الأمر
    } catch (e) {
      debugPrint('❌ Error on app paused: $e');
    }
  }

  /// عند إغلاق التطبيق
  void _onAppDetached() async {
    try {
      debugPrint('🧹 Cleaning up on app detached');
      await dispose();
    } catch (e) {
      debugPrint('❌ Error on app detached: $e');
    }
  }

  /// الحصول على معلومات الزيارة النشطة
  Future<Map<String, dynamic>?> getActiveVisitInfo() async {
    try {
      int? activeVisitId = await _draftService.getActiveVisitId();
      if (activeVisitId != null) {
        var draft = await _draftService.getDraft(activeVisitId);
        if (draft != null) {
          return {
            'visitId': activeVisitId,
            'hasData': draft.hasData,
            'lastModified': draft.lastModified,
            'status': draft.status,
            'imagesCount': draft.images.length,
            'videosCount': draft.videos.length,
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting active visit info: $e');
      return null;
    }
  }

  /// إظهار تنبيه للمستخدم عن وجود زيارة غير مكتملة
  Future<bool> hasIncompleteVisit() async {
    try {
      var activeInfo = await getActiveVisitInfo();
      return activeInfo != null && activeInfo['hasData'] == true;
    } catch (e) {
      debugPrint('❌ Error checking incomplete visit: $e');
      return false;
    }
  }

  /// استكمال الزيارة المعلقة
  Future<void> resumeIncompleteVisit() async {
    try {
      int? activeVisitId = await _draftService.getActiveVisitId();
      if (activeVisitId != null) {
        debugPrint('🔄 Resuming incomplete visit: $activeVisitId');
        // يمكن إضافة منطق للانتقال لشاشة الزيارة
      }
    } catch (e) {
      debugPrint('❌ Error resuming incomplete visit: $e');
    }
  }

  /// إلغاء الزيارة المعلقة
  Future<void> cancelIncompleteVisit() async {
    try {
      int? activeVisitId = await _draftService.getActiveVisitId();
      if (activeVisitId != null) {
        await _draftService.cancelVisit(activeVisitId);
        debugPrint('❌ Cancelled incomplete visit: $activeVisitId');
      }
    } catch (e) {
      debugPrint('❌ Error cancelling incomplete visit: $e');
    }
  }

  /// تصدير البيانات للنسخ الاحتياطي
  Future<Map<String, String>> exportAllDrafts() async {
    try {
      var drafts = await _draftService.getAllDrafts();
      Map<String, String> exports = {};
      
      for (var draft in drafts) {
        String? exported = await _draftService.exportDraft(draft.visitId);
        if (exported != null) {
          exports['visit_${draft.visitId}'] = exported;
        }
      }
      
      debugPrint('📤 Exported ${exports.length} drafts');
      return exports;
    } catch (e) {
      debugPrint('❌ Error exporting drafts: $e');
      return {};
    }
  }

  /// استيراد البيانات من النسخ الاحتياطي
  Future<int> importDrafts(Map<String, String> imports) async {
    try {
      int imported = 0;
      
      for (String draftJson in imports.values) {
        bool success = await _draftService.importDraft(draftJson);
        if (success) imported++;
      }
      
      debugPrint('📥 Imported $imported drafts');
      return imported;
    } catch (e) {
      debugPrint('❌ Error importing drafts: $e');
      return 0;
    }
  }

  /// الحصول على حجم البيانات المحفوظة
  Future<String> getStorageSize() async {
    try {
      var stats = await _draftService.getDraftStats();
      int totalSize = stats['totalDataSize'] ?? 0;
      
      if (totalSize < 1024) {
        return '${totalSize}B';
      } else if (totalSize < 1024 * 1024) {
        return '${(totalSize / 1024).toStringAsFixed(1)}KB';
      } else {
        return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
      }
    } catch (e) {
      debugPrint('❌ Error getting storage size: $e');
      return '0B';
    }
  }

  /// تنظيف الخدمة
  Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      // إزالة observer
      WidgetsBinding.instance.removeObserver(this);
      
      // تنظيف خدمة الحفظ المحلي
      _draftService.dispose();
      
      _isInitialized = false;
      debugPrint('🧹 AppLifecycleService disposed');
    } catch (e) {
      debugPrint('❌ Error disposing AppLifecycleService: $e');
    }
  }

  /// التحقق من حالة التهيئة
  bool get isInitialized => _isInitialized;

  /// الحصول على خدمة الحفظ المحلي
  DraftVisitService get draftService => _draftService;
}
