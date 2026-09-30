import 'dart:async';

import 'package:QCEC/l10n/app_localizations.dart';
import 'package:QCEC/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'main_screen.dart';

enum _LoginPhase { phone, otp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  _LoginPhase _phase = _LoginPhase.phone;
  bool _isLoading = false;
  int _countdownSeconds = 180;
  Timer? _countdownTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _startAnimations();
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdownSeconds = 180;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _countdownSeconds = 0;
        });
      } else {
        setState(() {
          _countdownSeconds--;
        });
      }
    });
  }

  String get _otpCode =>
      _otpControllers.map((controller) => controller.text).join();

  void _clearOtpFields() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
    if (_otpFocusNodes.isNotEmpty) {
      _otpFocusNodes.first.requestFocus();
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: GoogleFonts.cairo()),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.lightImpact();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.sendOtp(_phoneController.text.trim());

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      setState(() {
        _phase = _LoginPhase.otp;
      });
      _clearOtpFields();
      _startCountdown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocusNodes.first.requestFocus();
      });
      if (result['message'] != null && result['message'].toString().isNotEmpty) {
        _showMessage(result['message'], isError: false);
      }
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', isError: true);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode;
    if (code.length != 6) {
      _showMessage('يرجى إدخال رمز التحقق المكون من 6 أرقام', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.lightImpact();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.verifyOtp(
      _phoneController.text.trim(),
      code,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      _showMessage(result['message'], isError: false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', isError: true);
    }
  }

  Future<void> _resendOtp() async {
    if (_countdownSeconds > 0 || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.sendOtp(_phoneController.text.trim());

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      _clearOtpFields();
      _startCountdown();
      _showMessage(result['message'] ?? 'تم إرسال رمز جديد', isError: false);
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', isError: true);
    }
  }

  void _goBackToPhone() {
    _countdownTimer?.cancel();
    setState(() {
      _phase = _LoginPhase.phone;
      _countdownSeconds = 180;
    });
    _clearOtpFields();
  }

  String _formatCountdown() {
    final minutes = (_countdownSeconds ~/ 60).toString();
    final seconds = (_countdownSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _onOtpChanged(int index, String value) {
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
      setState(() {});
      return;
    }

    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < digits.length && index + i < 6; i++) {
        _otpControllers[index + i].text = digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, 5);
      _otpFocusNodes[nextIndex].requestFocus();
      setState(() {});
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Scaffold(
            backgroundColor: themeProvider.isDarkMode
                ? AppColors.primaryDark
                : AppColors.pureWhite,
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        Image.asset(
                          "assets/images/${themeProvider.isDarkMode ? "logo-white" : "logo"}.png",
                          width: 100,
                        ),

                        const SizedBox(height: 20),

                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Column(
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!.hello,
                                      style: GoogleFonts.cairo(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: themeProvider.isDarkMode
                                            ? AppColors.pureWhite
                                            : Colors.grey[800],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _phase == _LoginPhase.phone
                                          ? AppLocalizations.of(
                                              context,
                                            )!.helloContent
                                          : 'أدخل رمز التحقق المرسل عبر واتساب',
                                      style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        color: themeProvider.isDarkMode
                                            ? AppColors.pureWhite
                                            : Colors.grey[600],
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 50),

                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: _phase == _LoginPhase.phone
                                    ? _buildPhonePhase(themeProvider)
                                    : _buildOtpPhase(themeProvider),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhonePhase(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context)!.phoneNumber,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: themeProvider.isDarkMode
                ? AppColors.pureWhite
                : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _phoneController,
          hintText: '12345678',
          prefixIcon: Iconsax.call,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.pleaseEnterPhoneNumber;
            }
            if (value.length != 8) {
              return AppLocalizations.of(context)!.phoneNumberMustBe8Digits;
            }
            return null;
          },
        ),
        const SizedBox(height: 32),
        _buildGradientButton(
          label: 'إرسال رمز التحقق',
          onTap: _sendOtp,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildOtpPhase(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isLoading ? null : _goBackToPhone,
            icon: Icon(
              Iconsax.arrow_right_3,
              size: 18,
              color: themeProvider.isDarkMode
                  ? AppColors.pureWhite
                  : Colors.grey[700],
            ),
            label: Text(
              'تعديل رقم الهاتف',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: themeProvider.isDarkMode
                    ? AppColors.pureWhite
                    : Colors.grey[700],
              ),
            ),
          ),
        ),
        Text(
          'رمز التحقق',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: themeProvider.isDarkMode
                ? AppColors.pureWhite
                : Colors.grey[800],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _phoneController.text.trim(),
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: themeProvider.isDarkMode
                ? AppColors.pureWhite.withValues(alpha: 0.8)
                : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildOtpFields(themeProvider),
        const SizedBox(height: 16),
        Text(
          _countdownSeconds > 0
              ? 'يمكنك إعادة الإرسال بعد ${_formatCountdown()}'
              : 'يمكنك الآن طلب رمز جديد',
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: themeProvider.isDarkMode
                ? AppColors.pureWhite.withValues(alpha: 0.8)
                : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: (_countdownSeconds == 0 && !_isLoading) ? _resendOtp : null,
          child: Text(
            'إرسال رمز جديد',
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _countdownSeconds == 0
                  ? const Color(0xFF6B73FF)
                  : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildGradientButton(
          label: AppLocalizations.of(context)!.login,
          onTap: _verifyOtp,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildOtpFields(ThemeProvider themeProvider) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          return SizedBox(
            width: 44,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? AppColors.primaryDark
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: TextFormField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: themeProvider.isDarkMode
                          ? AppColors.secondaryDark
                          : AppColors.pureWhite,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) => _onOtpChanged(index, value),
                    onTap: () {
                      _otpControllers[index].selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _otpControllers[index].text.length,
                      );
                    },
                  ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? AppColors.primaryDark
                : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadiusGeometry.circular(10),
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              validator: validator,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: themeProvider.isDarkMode
                    ? AppColors.secondaryDark
                    : AppColors.pureWhite,
                hintText: hintText,
                hintStyle: GoogleFonts.cairo(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  prefixIcon,
                  color: themeProvider.isDarkMode
                      ? AppColors.pureWhite
                      : Colors.black,
                  size: 22,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B73FF), Color(0xFF9DD5EA)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B73FF).withAlpha(76),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      label,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
