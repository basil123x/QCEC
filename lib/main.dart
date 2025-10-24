import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'presentation/screens/auth_wrapper.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/language_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'l10n/app_localizations.dart';
import 'services/app_lifecycle_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة نظام الحفظ التلقائي للزيارات
  await AppLifecycleService().initialize();
  
  runApp(const QCECApp());
}

class QCECApp extends StatelessWidget {
  const QCECApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()..loadLanguage()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, child) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: languageProvider.currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            initialRoute: '/',
            routes: {
              '/': (context) => const AuthWrapper(),
            },
            builder: (context, child) {
              return Directionality(
                textDirection: languageProvider.isRTL 
                    ? TextDirection.rtl 
                    : TextDirection.ltr,
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
