# Q.C.E.C - المركز القطري للاستشارات الهندسية

تطبيق Flutter لإدارة المشاريع الهندسية والزيارات التفتيشية

## الوصف

تطبيق متكامل لإدارة المشاريع الهندسية يتيح للمهندسين تسجيل الزيارات التفتيشية وإرسال التقارير للعملاء والمقاولين عبر SMS أو WhatsApp.

## المميزات

### 🏗️ إدارة المشاريع
- عرض قائمة المشاريع مع تفاصيل العملاء والمقاولين
- البحث والتصفية في المشاريع
- عرض إحصائيات الزيارات لكل مشروع

### 📋 تسجيل الزيارات
- إضافة وصف الأعمال المنجزة
- كتابة الملاحظات والتوصيات
- رفع صور الزيارة
- إرسال تقارير فورية للعملاء والمقاولين

### 📱 التواصل
- إرسال رسائل SMS
- إرسال رسائل WhatsApp
- إجراء مكالمات هاتفية مباشرة

### 📊 الإحصائيات
- عدد المشاريع الإجمالي
- عدد الزيارات الإجمالي
- رسوم بيانية تفاعلية

### ⚙️ الإعدادات
- تغيير اللغة
- الوضع الليلي
- إدارة الحساب

## التقنيات المستخدمة

- **Flutter**: إطار العمل الأساسي
- **Provider**: إدارة الحالة
- **SQLite**: قاعدة البيانات المحلية
- **SharedPreferences**: تخزين الإعدادات
- **Image Picker**: التقاط ورفع الصور
- **URL Launcher**: إرسال الرسائل والمكالمات
- **FL Chart**: الرسوم البيانية

## هيكل المشروع

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   └── app_strings.dart
│   └── theme/
│       └── app_theme.dart
├── data/
│   ├── models/
│   │   ├── project.dart
│   │   ├── user.dart
│   │   ├── visit.dart
│   │   └── statistics.dart
│   ├── repositories/
│   └── services/
│       ├── database_service.dart
│       └── messaging_service.dart
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   └── project_provider.dart
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── main_screen.dart
│   │   ├── projects_screen.dart
│   │   ├── visit_details_screen.dart
│   │   ├── profile_screen.dart
│   │   └── settings_screen.dart
│   └── widgets/
│       ├── custom_button.dart
│       ├── custom_text_field.dart
│       └── project_card.dart
└── main.dart
```

## التشغيل

### متطلبات النظام
- Flutter SDK 3.9.2 أو أحدث
- Dart SDK
- Android Studio أو VS Code
- جهاز Android أو iOS للاختبار

### خطوات التشغيل

1. **استنساخ المشروع**
```bash
git clone <repository-url>
cd qcec
```

2. **تحميل التبعيات**
```bash
flutter pub get
```

3. **تشغيل التطبيق**
```bash
flutter run
```

## الاستخدام

### تسجيل الدخول
- أدخل أي اسم مستخدم وكلمة مرور (6 أحرف على الأقل)
- سيتم إنشاء حساب تلقائياً للمرة الأولى

### إضافة زيارة جديدة
1. اختر مشروع من القائمة الرئيسية
2. املأ وصف الأعمال والملاحظات
3. أضف صور الزيارة (اختياري)
4. حدد المستلمين للرسائل
5. احفظ الزيارة

### إرسال الرسائل
- سيتم إرسال الرسائل تلقائياً عند حفظ الزيارة
- يمكن الاتصال بالعملاء مباشرة من قائمة المشاريع

## الأذونات المطلوبة

### Android
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.CALL_PHONE" />
<uses-permission android:name="android.permission.SEND_SMS" />
```

### iOS
```xml
<key>NSCameraUsageDescription</key>
<string>يحتاج التطبيق للوصول للكاميرا لالتقاط صور الزيارات</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>يحتاج التطبيق للوصول لمعرض الصور لاختيار صور الزيارات</string>
```

## المساهمة

نرحب بالمساهمات! يرجى:
1. عمل Fork للمشروع
2. إنشاء branch جديد للميزة
3. إضافة التغييرات مع الاختبارات
4. إرسال Pull Request

## الترخيص

هذا المشروع مرخص تحت رخصة MIT - راجع ملف [LICENSE](LICENSE) للتفاصيل.

## الدعم

للدعم والاستفسارات:
- البريد الإلكتروني: info@qcec.qa
- الهاتف: +974 1234 5678

---

تم تطوير هذا التطبيق بواسطة فريق المركز القطري للاستشارات الهندسية

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


