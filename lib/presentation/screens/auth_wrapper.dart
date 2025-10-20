import 'package:QCEC/test.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'splash_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _minSplashElapsed = false;
  Timer? _minTimer;

  @override
  void initState() {
    super.initState();
    _minTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _minSplashElapsed = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Always show splash until both conditions are met:
        // 1) auth loading finished, and 2) minimum splash time elapsed
        final shouldShowSplash = authProvider.isLoading || !_minSplashElapsed;
        if (shouldShowSplash) {
          return const SplashScreen();
        }

        // After splash: route based on auth state
        if (authProvider.isLoggedIn) {
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
