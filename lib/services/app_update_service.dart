import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:terminate_restart/terminate_restart.dart';

import '../core/utils/dio_helper.dart';

/// Result of a store (Play / App Store) force-update check.
class ForceUpdateInfo {
  final String message;
  final String storeUrl;
  final String latestVersion;

  const ForceUpdateInfo({
    required this.message,
    required this.storeUrl,
    required this.latestVersion,
  });
}

/// Central app update manager:
/// 1) Mandatory store update (Play / App Store)
/// 2) Shorebird OTA patch with automatic double-restart
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const _pendingSecondRestartKey = 'shorebird_pending_second_restart';
  static const _forceUpdateEndpoint =
      'https://www.qcec-qatar.com/erp2026/app_source/check_update.php';

  final ShorebirdUpdater _updater = ShorebirdUpdater();
  bool _shorebirdBusy = false;

  /// True when a patch was downloaded and we already restarted once —
  /// a second restart is required for the UI to pick up the new code.
  Future<bool> needsSecondRestart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingSecondRestartKey) ?? false;
  }

  Future<void> _markNeedsSecondRestart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingSecondRestartKey, true);
  }

  Future<void> _clearSecondRestartFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingSecondRestartKey, false);
  }

  /// Completes the second restart after a Shorebird patch was applied.
  /// Returns true if a restart was triggered (caller should stop boot).
  Future<bool> completePendingSecondRestart() async {
    if (!await needsSecondRestart()) return false;
    await _clearSecondRestartFlag();
    // Brief pause so the "Applying update" overlay can paint.
    await Future.delayed(const Duration(milliseconds: 600));
    await restartApp();
    return true;
  }

  /// Checks server for a mandatory store update.
  /// Returns [ForceUpdateInfo] when the installed version is below the
  /// required store version and force_update is enabled.
  Future<ForceUpdateInfo?> checkForceStoreUpdate() async {
    try {
      final platform = Platform.isIOS ? 'IOS' : 'Android';
      final dio = DioHelper.createDio();
      final response = await dio.post(
        _forceUpdateEndpoint,
        data: {'action': 'ForceUpdate', 'platform': platform},
      );

      if (response.data['status'] != 'success') return null;

      final row = response.data['appUpdates_data'][0];
      final latestVersion = row['latest_version'].toString();
      final forceUpdate = row['force_update'].toString() == '1';
      final message = (row['message'] ?? '').toString();
      final storeUrl = (row['store_link'] ?? '').toString();

      if (!forceUpdate) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_compareVersions(currentVersion, latestVersion) < 0) {
        return ForceUpdateInfo(
          message: message,
          storeUrl: storeUrl,
          latestVersion: latestVersion,
        );
      }
    } on DioException catch (e) {
      debugPrint('Force update check failed: $e');
    } catch (e) {
      debugPrint('Force update check failed: $e');
    }
    return null;
  }

  /// On cold start / first open: download Shorebird patch if available and
  /// restart (with a second restart queued). Returns true if restarting.
  Future<bool> checkAndApplyShorebirdOnLaunch() async {
    return _downloadAndRestartIfNeeded();
  }

  /// While the app is open: same as launch, but intended to be called after
  /// showing a full-screen "Updating…" overlay.
  Future<bool> checkAndApplyShorebirdLive() async {
    return _downloadAndRestartIfNeeded();
  }

  Future<bool> _downloadAndRestartIfNeeded() async {
    if (_shorebirdBusy) return false;
    if (!_updater.isAvailable) return false;

    _shorebirdBusy = true;
    try {
      final status = await _updater.checkForUpdate();

      if (status == UpdateStatus.restartRequired) {
        await _markNeedsSecondRestart();
        await restartApp();
        return true;
      }

      if (status != UpdateStatus.outdated) return false;

      await _updater.update();
      // First restart applies the patch; flag ensures a second restart so
      // the new Dart code is actually visible (single restart is not enough).
      await _markNeedsSecondRestart();
      await Future.delayed(const Duration(milliseconds: 300));
      await restartApp();
      return true;
    } on UpdateException catch (e) {
      debugPrint('Shorebird update failed: $e');
      return false;
    } catch (e) {
      debugPrint('Shorebird check failed: $e');
      return false;
    } finally {
      _shorebirdBusy = false;
    }
  }

  /// Whether a Shorebird patch is waiting (download or restart).
  Future<bool> isShorebirdUpdateAvailable() async {
    if (!_updater.isAvailable) return false;
    try {
      final status = await _updater.checkForUpdate();
      return status == UpdateStatus.outdated ||
          status == UpdateStatus.restartRequired;
    } catch (_) {
      return false;
    }
  }

  Future<void> restartApp({
    String? notificationTitle,
    String? notificationBody,
  }) async {
    if (Platform.isIOS) {
      Restart.restartApp(
        notificationTitle: notificationTitle ?? 'Updating…',
        notificationBody: notificationBody ?? 'Applying the latest update',
      );
    } else {
      await TerminateRestart.instance.restartApp(
        options: const TerminateRestartOptions(terminate: true),
      );
    }
  }

  /// Semver-ish compare: returns <0 if [a] < [b], 0 if equal, >0 if [a] > [b].
  static int _compareVersions(String a, String b) {
    final pa = a
        .split(RegExp(r'[.+-]'))
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final pb = b
        .split(RegExp(r'[.+-]'))
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final len = math.max(pa.length, pb.length);
    for (var i = 0; i < len; i++) {
      final av = i < pa.length ? pa[i] : 0;
      final bv = i < pb.length ? pb[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}
