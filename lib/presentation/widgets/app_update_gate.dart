import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_update_service.dart';
import '../screens/force_update_screen.dart';

/// Boot + runtime gate:
/// - Completes Shorebird double-restart if a patch was just applied
/// - Blocks on mandatory Play / App Store update
/// - On first open (and periodically while live): downloads Shorebird
///   patches and restarts twice automatically so the latest code appears
class AppUpdateGate extends StatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  final _service = AppUpdateService.instance;

  bool _ready = false;
  bool _applyingPatch = false;
  String _statusMessage = '';
  ForceUpdateInfo? _forceUpdate;

  Timer? _liveCheckTimer;
  bool _liveCheckRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _liveCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready && _forceUpdate == null) {
      _runLiveShorebirdCheck();
    }
  }

  Future<void> _bootstrap() async {
    final loc = AppLocalizations.of(context);

    // 1) Finish double-restart from a previous patch download.
    if (await _service.needsSecondRestart()) {
      if (!mounted) return;
      setState(() {
        _applyingPatch = true;
        _statusMessage =
            loc?.applyingUpdate ?? 'جاري تطبيق التحديث…';
      });
      final restarted = await _service.completePendingSecondRestart();
      if (restarted) return; // process will die
    }

    // 2) Mandatory store update first.
    if (!mounted) return;
    setState(() {
      _statusMessage =
          loc?.checkingForUpdates ?? 'جاري التحقق من التحديثات…';
    });

    final force = await _service.checkForceStoreUpdate();
    if (!mounted) return;
    if (force != null) {
      setState(() {
        _forceUpdate = force;
        _ready = true;
        _applyingPatch = false;
      });
      return;
    }

    // 3) Shorebird patch on first open — download + restart (+ queued 2nd).
    if (!mounted) return;
    setState(() {
      _applyingPatch = true;
      _statusMessage =
          loc?.checkingForUpdates ?? 'جاري التحقق من التحديثات…';
    });

    final hasPatch = await _service.isShorebirdUpdateAvailable();
    if (!mounted) return;

    if (hasPatch) {
      setState(() {
        _statusMessage =
            loc?.downloadingUpdate ?? 'جاري تحميل التحديث…';
      });
      final restarted = await _service.checkAndApplyShorebirdOnLaunch();
      if (restarted) return;
    }

    if (!mounted) return;
    setState(() {
      _ready = true;
      _applyingPatch = false;
    });
    _startLiveChecks();
  }

  void _startLiveChecks() {
    _liveCheckTimer?.cancel();
    // Poll while the user has the app open so a new patch appears immediately.
    _liveCheckTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _runLiveShorebirdCheck(),
    );
  }

  Future<void> _runLiveShorebirdCheck() async {
    if (!_ready || _forceUpdate != null || _liveCheckRunning) return;
    if (_applyingPatch) return;

    _liveCheckRunning = true;
    try {
      final available = await _service.isShorebirdUpdateAvailable();
      if (!available || !mounted) return;

      final loc = AppLocalizations.of(context);
      setState(() {
        _applyingPatch = true;
        _statusMessage =
            loc?.downloadingUpdate ?? 'جاري تحميل التحديث…';
      });

      final restarted = await _service.checkAndApplyShorebirdLive();
      if (restarted) return;

      if (mounted) {
        setState(() => _applyingPatch = false);
      }
    } finally {
      _liveCheckRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_forceUpdate != null) {
      return ForceUpdateScreen(
        message: _forceUpdate!.message,
        storeUrl: _forceUpdate!.storeUrl,
      );
    }

    // Full-screen cover while booting or while a live Shorebird patch
    // is downloading — user sees an immediate refresh, then the app restarts.
    if (!_ready || _applyingPatch) {
      return _UpdatingScaffold(message: _statusMessage);
    }

    return widget.child;
  }
}

class _UpdatingScaffold extends StatelessWidget {
  final String message;

  const _UpdatingScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.primaryDark : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpinKitFadingCircle(
                color: isDark ? Colors.white : AppColors.primary,
                size: 56,
              ),
              const SizedBox(height: 28),
              Text(
                message.isNotEmpty
                    ? message
                    : (loc?.checkingForUpdates ??
                        'جاري التحقق من التحديثات…'),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc?.pleaseWaitUpdate ?? 'يرجى الانتظار لحظات',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
