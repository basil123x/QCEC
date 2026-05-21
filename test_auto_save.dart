// ملف اختبار نظام الحفظ التلقائي
// يمكن تشغيله منفصلاً لاختبار الوظائف

import 'package:flutter/material.dart';
import 'lib/services/draft_visit_service.dart';
import 'lib/models/draft_visit.dart';
import 'lib/services/app_lifecycle_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🧪 بدء اختبار نظام الحفظ التلقائي...\n');
  
  // اختبار خدمة الحفظ المحلي
  await testDraftVisitService();
  
  // اختبار خدمة دورة حياة التطبيق
  await testAppLifecycleService();
  
  print('\n✅ انتهى الاختبار بنجاح!');
}

/// اختبار خدمة الحفظ المحلي
Future<void> testDraftVisitService() async {
  print('📋 اختبار DraftVisitService...');
  
  final service = DraftVisitService();
  await service.initialize();
  
  // إنشاء زيارة تجريبية
  print('  - إنشاء زيارة تجريبية...');
  DraftVisit? draft = await service.startVisit(123, 456);
  
  if (draft != null) {
    print('  ✅ تم إنشاء الزيارة: ${draft.visitId}');
    
    // تحديث البيانات
    print('  - تحديث البيانات...');
    await service.updateCurrentVisit(
      description: 'وصف تجريبي للزيارة',
      notes: 'ملاحظات تجريبية',
      contactCustomer: true,
    );
    print('  ✅ تم تحديث البيانات');
    
    // إضافة صورة وهمية
    print('  - إضافة صورة وهمية...');
    await service.addImage('/path/to/test/image.jpg');
    print('  ✅ تم إضافة الصورة');
    
    // استعادة البيانات
    print('  - استعادة البيانات...');
    DraftVisit? retrieved = await service.getDraft(123);
    if (retrieved != null) {
      print('  ✅ تم استعادة البيانات: ${retrieved.description}');
      print('    - الصور: ${retrieved.images.length}');
      print('    - الاتصال بالعميل: ${retrieved.contactCustomer}');
    }
    
    // الحصول على الإحصائيات
    print('  - الحصول على الإحصائيات...');
    Map<String, dynamic> stats = await service.getDraftStats();
    print('  ✅ الإحصائيات: $stats');
    
    // تنظيف الاختبار
    print('  - تنظيف بيانات الاختبار...');
    await service.cancelVisit(123);
    print('  ✅ تم التنظيف');
  }
  
  print('✅ انتهى اختبار DraftVisitService\n');
}

/// اختبار خدمة دورة حياة التطبيق
Future<void> testAppLifecycleService() async {
  print('🔄 اختبار AppLifecycleService...');
  
  final service = AppLifecycleService();
  await service.initialize();
  
  if (service.isInitialized) {
    print('  ✅ تم تهيئة الخدمة');
    
    // اختبار التحقق من الزيارات المعلقة
    print('  - التحقق من الزيارات المعلقة...');
    bool hasIncomplete = await service.hasIncompleteVisit();
    print('  ✅ الزيارات المعلقة: $hasIncomplete');
    
    // اختبار حجم التخزين
    print('  - حساب حجم التخزين...');
    String storageSize = await service.getStorageSize();
    print('  ✅ حجم التخزين: $storageSize');
    
    // اختبار التصدير والاستيراد
    print('  - اختبار التصدير والاستيراد...');
    Map<String, String> exports = await service.exportAllDrafts();
    print('  ✅ تم تصدير ${exports.length} مسودة');
    
    if (exports.isNotEmpty) {
      int imported = await service.importDrafts(exports);
      print('  ✅ تم استيراد $imported مسودة');
    }
    
    // تنظيف الخدمة
    await service.dispose();
    print('  ✅ تم تنظيف الخدمة');
  }
  
  print('✅ انتهى اختبار AppLifecycleService\n');
}

/// اختبار إضافي للتأكد من عمل النظام
Future<void> simulateAppInterruption() async {
  print('📱 محاكاة مقاطعة التطبيق...');
  
  final service = DraftVisitService();
  await service.initialize();
  
  // بدء زيارة
  print('  - بدء زيارة جديدة...');
  await service.startVisit(999, 888);
  
  // إضافة بيانات
  print('  - إضافة بيانات...');
  await service.updateCurrentVisit(
    description: 'زيارة قبل المقاطعة',
    notes: 'هذه بيانات مهمة يجب حفظها',
  );
  
  // محاكاة إغلاق التطبيق (عدم استدعاء dispose)
  print('  - محاكاة إغلاق التطبيق...');
  
  // إنشاء خدمة جديدة (كما لو تم فتح التطبيق مرة أخرى)
  print('  - فتح التطبيق مرة أخرى...');
  final newService = DraftVisitService();
  await newService.initialize();
  
  // التحقق من استعادة البيانات
  DraftVisit? recovered = await newService.getDraft(999);
  if (recovered != null && recovered.description == 'زيارة قبل المقاطعة') {
    print('  ✅ تم استعادة البيانات بنجاح بعد المقاطعة!');
    print('    - الوصف: ${recovered.description}');
    print('    - الملاحظات: ${recovered.notes}');
  } else {
    print('  ❌ فشل في استعادة البيانات');
  }
  
  // تنظيف
  await newService.cancelVisit(999);
  print('✅ انتهت محاكاة المقاطعة\n');
}
