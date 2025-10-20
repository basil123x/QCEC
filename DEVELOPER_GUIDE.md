# دليل المطور - ميزة الإحصائيات المتحركة

## نظرة عامة
تم إنشاء قسم إحصائيات متحرك جميل يظهر في الصفحة الرئيسية تحت قسم "الإجراءات السريعة".

## الملفات المضافة/المحدثة

### 1. AuthProvider (محدث)
**الملف:** `lib/presentation/providers/auth_provider.dart`
**التغيير:** إضافة دالة `getTotalStats()`

```dart
Future<Map<String, dynamic>> getTotalStats() async {
  // يرسل طلب للـ API مع action: 'get_total'
  // يحدد نوع المستخدم (x parameter)
  // يعيد الإحصائيات الثلاث
}
```

### 2. AnimatedStatsCard (جديد)
**الملف:** `lib/presentation/widgets/animated_stats_card.dart`
**الوظيفة:** Widget للدائرة المتحركة مع العداد

**المميزات:**
- دائرة تدور وتملأ تدريجياً
- عداد يعد من 0 للرقم المطلوب
- تأثير تكبير أثناء الحركة
- ظلال متحركة
- تنسيق الأرقام الكبيرة (1000 = 1ك، 1000000 = 1م)

### 3. StatsSection (جديد)
**الملف:** `lib/presentation/widgets/stats_section.dart`
**الوظيفة:** يدير عرض الإحصائيات الثلاث

**المميزات:**
- يجلب البيانات من AuthProvider
- يعرض حالة التحميل
- يعرض رسائل الخطأ
- زر إعادة التحديث
- تخطيط متجاوب

### 4. MainScreen (محدث)
**الملف:** `lib/presentation/screens/main_screen.dart`
**التغيير:** إضافة `StatsSection` في الصفحة الرئيسية

## كيفية الاستخدام

### 1. في التطبيق الحالي
الميزة تعمل تلقائياً! فقط:
1. شغل التطبيق
2. اذهب للصفحة الرئيسية
3. ستظهر الإحصائيات تحت الإجراءات السريعة

### 2. للاختبار بدون API
```dart
// شغل الملف التجريبي
flutter run test_stats.dart
```

## متطلبات الـ Backend

### استعلام SQL مطلوب
```php
if ($action == "get_total") {
    $uid = $data['uid'];
    $x = $data['x'];
    $today = date('Y-m-d');
    
    // تحديد الشرط حسب نوع المستخدم
    switch($x){  
        case '1': $d1 = " and a1='$uid'  "; break; 
        case '2': $d1 = "and  a2='$uid' "; break;  
        case '3': $d1 = " and a3='$uid' "; break;
        default: $d1 = ""; // للـ Admin
    }
    
    $query = "SELECT
        COUNT(id) AS v1,                                    -- إجمالي المشاريع
        SUM(a8) AS v2,                                      -- إجمالي الزيارات
        COUNT(CASE WHEN a10 = '$today' THEN 1 END) AS v3    -- زيارات اليوم
    FROM visitsx
    WHERE stx = '1' $d1"; 
    
    $result = $conx->query($query);
    $total_trans = [];
    while ($row = $result->fetch_assoc()) {
        $total_trans[] = $row;
    }

    echo json_encode([
        'status' => 'success',
        'trans_data' => $total_trans,
    ]);
}
```

### الاستجابة المتوقعة
```json
{
  "status": "success",
  "trans_data": [
    {
      "v1": "25",    // إجمالي المشاريع
      "v2": "150",   // إجمالي الزيارات  
      "v3": "5"      // زيارات اليوم
    }
  ]
}
```

## التخصيص

### تغيير الألوان
```dart
// في stats_section.dart
AnimatedStatsCard(
  color: Colors.purple, // غير اللون
  // ...
)
```

### تغيير الأيقونات
```dart
// في stats_section.dart
AnimatedStatsCard(
  icon: Iconsax.building, // غير الأيقونة
  // ...
)
```

### تغيير مدة الحركة
```dart
// في stats_section.dart
AnimatedStatsCard(
  animationDuration: const Duration(milliseconds: 3000), // 3 ثواني
  // ...
)
```

### إضافة إحصائية رابعة
1. أضف القيمة في الاستعلام SQL (مثل v4)
2. في `stats_section.dart`:
```dart
// استخرج القيمة
final newStat = int.tryParse(_statsData['v4']?.toString() ?? '0') ?? 0;

// أضف Card جديدة
AnimatedStatsCard(
  title: 'إحصائية جديدة',
  value: newStat,
  color: Colors.purple,
  icon: Iconsax.chart,
)
```
3. غير التخطيط من Row إلى GridView إذا لزم الأمر

## استكشاف الأخطاء

### المشكلة: لا تظهر الإحصائيات
**الحل:**
1. تأكد من أن الـ Backend يدعم `action: 'get_total'`
2. تحقق من console logs
3. تأكد من أن المستخدم مسجل دخول

### المشكلة: لا تعمل الحركة
**الحل:**
1. تأكد من أن الحزم مثبتة: `flutter pub get`
2. تحقق من أن الـ AnimationController يعمل
3. تأكد من أن الـ widget mounted

### المشكلة: أرقام خاطئة
**الحل:**
1. تحقق من الاستعلام SQL
2. تأكد من أن الحقول v1, v2, v3 موجودة
3. تحقق من نوع البيانات (string vs int)

## الأداء

### تحسينات مطبقة
- ✅ Animation controllers يتم dispose بشكل صحيح
- ✅ تحميل البيانات مرة واحدة فقط
- ✅ حالة loading منفصلة
- ✅ Error handling شامل
- ✅ Memory efficient animations

### نصائح للأداء
- لا تشغل الحركة إذا كان الـ widget غير مرئي
- استخدم `mounted` check قبل setState
- تجنب إعادة بناء الـ widget بدون داعي

## الاختبار

### اختبار يدوي
1. شغل `flutter run test_stats.dart`
2. تأكد من أن الدوائر تدور
3. تأكد من أن الأرقام تعد
4. اضغط "إعادة تشغيل الحركة"

### اختبار في التطبيق
1. سجل دخول بحسابات مختلفة
2. تأكد من أن كل مستخدم يرى إحصائياته
3. اختبر حالة عدم وجود بيانات
4. اختبر حالة خطأ الشبكة
