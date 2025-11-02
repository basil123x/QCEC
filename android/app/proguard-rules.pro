-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.firebase.messaging.** { *; }

# 🟢 Dio / Retrofit (لو بتستخدم Dio API)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# 🟢 منع حذف أي كلاس بـ @Keep
-keep @androidx.annotation.Keep class * { *; }