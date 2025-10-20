# ميزة الإحصائيات المتحركة - QCEC App

## الوصف
تم إضافة قسم إحصائيات جديد في الصفحة الرئيسية يعرض:
- إجمالي المشاريع
- إجمالي الزيارات  
- زيارات اليوم

## المميزات
✅ **دوائر متحركة جميلة** - تدور وتملأ تدريجياً عند تحميل الصفحة
✅ **عدادات متحركة** - الأرقام تعد من 0 إلى القيمة الفعلية
✅ **تحديث تلقائي** - تعمل في كل مرة تدخل للصفحة الرئيسية
✅ **تصميم متجاوب** - يعمل على جميع أحجام الشاشات
✅ **ألوان مميزة** - كل إحصائية لها لون مختلف

## الملفات المضافة

### 1. AuthProvider - استعلام الإحصائيات
```dart
// تم إضافة دالة getTotalStats() في:
lib/presentation/providers/auth_provider.dart
```

### 2. Widget الدائرة المتحركة
```dart
// ملف جديد:
lib/presentation/widgets/animated_stats_card.dart
```

### 3. قسم الإحصائيات الكامل
```dart
// ملف جديد:
lib/presentation/widgets/stats_section.dart
```

### 4. تحديث الصفحة الرئيسية
```dart
// تم التحديث في:
lib/presentation/screens/main_screen.dart
```

## كيفية العمل

### 1. استعلام البيانات - تم إضافته! ✅
```php
// تم إضافة الاستعلام في ملف sql.php:
case 'get_total':
    getTotalStats($input);
    break;

// الدالة المضافة:
function getTotalStats($input) {
    $d1='';
    $uid = $data['uid'];
    $x = $data['x'];
    $today = date('Y-m-d');
    
    switch($x){  
        case '1': $d1 = " and a1='$uid'  "; break; 
        case '2': $d1 = "and  a2='$uid' "; break;  
        case '3': $d1 = " and a3='$uid' "; break;
    }
    
    $query = "SELECT
    COUNT(id) AS v1,
    SUM(a8) AS v2,
    COUNT(CASE WHEN a10 = '$today' THEN 1 END) AS v3
FROM visitsx
WHERE stx = '1'  $d1"; 
    
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

### 2. الاستجابة المتوقعة
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
// في ملف stats_section.dart
AnimatedStatsCard(
  title: 'إجمالي المشاريع',
  value: totalProjects,
  color: Colors.blue, // غير اللون هنا
  icon: Iconsax.folder_2,
)
```

### تغيير مدة الحركة
```dart
// في ملف animated_stats_card.dart
AnimatedStatsCard(
  animationDuration: const Duration(milliseconds: 2000), // غير المدة هنا
)
```

### إضافة إحصائيات جديدة
1. أضف القيمة في الاستعلام SQL
2. أضف `AnimatedStatsCard` جديدة في `stats_section.dart`
3. حدث التخطيط إذا لزم الأمر

## الاختبار
1. شغل التطبيق
2. اذهب للصفحة الرئيسية
3. ستظهر الإحصائيات تحت قسم "الإجراءات السريعة"
4. ستبدأ الدوائر بالدوران والأرقام بالعد تلقائياً

## ملاحظات مهمة
- يعمل مع جميع أنواع المستخدمين (Admin, Customer, Engineer, Contractor)
- كل مستخدم يرى إحصائياته الخاصة حسب نوع حسابه
- يتم تحديث البيانات في كل مرة تدخل للصفحة الرئيسية
- يمكن الضغط على زر التحديث لإعادة جلب البيانات

## استكشاف الأخطاء
- إذا لم تظهر الإحصائيات: تأكد من أن الـ Backend يدعم استعلام `get_total`
- إذا لم تعمل الحركة: تأكد من أن الحزم مثبتة بشكل صحيح
- إذا ظهرت أخطاء: تحقق من console logs في التطبيق
