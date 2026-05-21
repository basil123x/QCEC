import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:terminate_restart/terminate_restart.dart';
import 'core/constants/app_strings.dart';
import 'presentation/screens/auth_wrapper.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/language_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'l10n/app_localizations.dart';
import 'services/app_lifecycle_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLifecycleService().initialize();
  runApp(const QCECApp());
}

class QCECApp extends StatefulWidget {
  const QCECApp({super.key});

  @override
  State<QCECApp> createState() => _QCECAppState();
}

class _QCECAppState extends State<QCECApp> {
  @override
  void initState() {
    ensureDoubleRestart();
    checkForUpdates();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      checkForUpdates();
    });
    super.initState();
  }

  final updater = ShorebirdUpdater();
  Timer? _timer;

  static const _lastPatchKey = "last_applied_patch";

  Future<void> ensureDoubleRestart() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    final lastPatchNumber = prefs.getInt(_lastPatchKey) ?? 0;
    final currentPatch = await updater.readCurrentPatch();
    if (currentPatch != null && currentPatch.number != lastPatchNumber) {
      await prefs.setInt(_lastPatchKey, currentPatch.number);
      await Future.delayed(const Duration(seconds: 2));
      if (Platform.isIOS) {
        Restart.restartApp();
      } else {
        await TerminateRestart.instance.restartApp(
          options: const TerminateRestartOptions(terminate: true),
        );
      }
    }
  }

  Future<void> checkForUpdates() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    if (loc == null) return;

    final status = await updater.checkForUpdate();
    if (status == UpdateStatus.outdated) {
      try {
        await updater.update();
        final prefs = await SharedPreferences.getInstance();
        final currentPatch = await updater.readCurrentPatch();
        if (currentPatch != null) {
          await prefs.setInt(_lastPatchKey, currentPatch.number - 1);
        }
        if (Platform.isIOS) {
          Restart.restartApp(
            notificationBody: loc.importantNotification,
            notificationTitle: loc.updatePrompt,
          );
        } else {
          await TerminateRestart.instance.restartApp(
            options: const TerminateRestartOptions(terminate: true),
          );
        }
      } on UpdateException catch (error) {
        print("Update failed: $error");
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..loadLanguage(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, child) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            navigatorKey: navigatorKey,
            themeMode: themeProvider.themeMode,
            locale: languageProvider.currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            initialRoute: '/',
            routes: {'/': (context) => const AuthWrapper()},
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
