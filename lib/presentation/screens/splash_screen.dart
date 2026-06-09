import 'dart:math';
import 'package:QCEC/core/repositories/forceupdate_repository.dart';
import 'package:QCEC/l10n/app_localizations.dart';
import 'package:QCEC/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _backgroundController;

  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
    _navigateToLogin();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpgradeRepository().checkUpdate(context, setState);
    });
  }

  void _initAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    _backgroundController.forward();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _logoController.forward();
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _textController.forward();
    });
  }

  void _navigateToLogin() {
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 1200),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? AppColors.primaryDark
                  : AppColors.primary,
            ),
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _logoController,
                _textController,
                _backgroundController,
              ]),
              builder: (context, child) {
                return Stack(
                  children: [
                    // Background Circles
                    _buildBackgroundCircles(),

                    // Main Content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          Transform.scale(
                            scale: _logoAnimation.value,
                            child: _buildLogo(),
                          ),

                          // Subtitle with Animation
                          AnimatedBuilder(
                            animation: _textController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _textAnimation.value * 30),
                                child: FadeTransition(
                                  opacity: _textAnimation,
                                  child: Text(
                                    AppLocalizations.of(context)!.qcecFullName,
                                    style: GoogleFonts.cairo(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 60),

                          // Custom Loading Indicator
                          Opacity(
                            opacity: _textAnimation.value,
                            child: _buildCustomLoader(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundCircles() {
    return Stack(
      children: [
        // Top Left Circle
        Positioned(
          top: -100,
          left: -100,
          child: Transform.scale(
            scale: _logoAnimation.value,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(25),
              ),
            ),
          ),
        ),

        // Bottom Right Circle
        Positioned(
          bottom: -150,
          right: -150,
          child: Transform.scale(
            scale: _logoAnimation.value * 0.8,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(13),
              ),
            ),
          ),
        ),

        // Center Small Circle
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          right: 50,
          child: Transform.scale(
            scale: _textAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(38),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomLoader() {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          // Outer rotating ring
          RotationTransition(
            turns: _logoController,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withAlpha(102),
                  width: 2,
                ),
              ),
            ),
          ),
          // Inner pulsing circle
          Center(
            child: AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.3 + (_textAnimation.value * 0.4),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(178),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withAlpha(76),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Dots around the circle
          ...List.generate(8, (index) {
            final angle = (index * 45) * (3.14159 / 180);
            return Positioned(
              left:
                  30 +
                  (25 * cos(angle + (_logoController.value * 2 * 3.14159))) -
                  3,
              top:
                  30 +
                  (25 * sin(angle + (_logoController.value * 2 * 3.14159))) -
                  3,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(
                    (255 * (index + 1) / 8).round(),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return SizedBox(
          width: 150,
          height: 150,
          child: Image.asset(
            'assets/images/${themeProvider.isDarkMode ? "logo-white" : "logo"}.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(51),
                ),
                child: Center(
                  child: Text(
                    'QCEC',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
