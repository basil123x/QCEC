import 'dart:io';
import 'package:QCEC/core/utils/dio_helper.dart';
import 'package:QCEC/presentation/screens/upgrade_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

String platform = "";

class UpgradeRepository {
  late final Dio _dio;

  UpgradeRepository() {
    _dio = DioHelper.createDio();
  }

  Future<dynamic> checkUpdate(context, setState) async {
    if (Platform.isIOS) {
      setState(() {
        platform = "IOS";
      });
    } else {
      setState(() {
        platform = "Android";
      });
    }
    try {
      final response = await _dio.post(
        'https://www.qcec-qatar.com/erp2026/app_source/check_update.php',
        data: {'action': 'ForceUpdate', 'platform': platform},
      );
      if (response.data['status'] == 'success') {
        final data = response.data;
        final latestVersion = data['appUpdates_data'][0]['latest_version'];
        final forceUpdate =
            data['appUpdates_data'][0]['force_update'].toString() == "1";
        final message = data['appUpdates_data'][0]['message'];
        final storeUrl = data['appUpdates_data'][0]['store_link'];
        print(latestVersion);
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (forceUpdate && currentVersion != latestVersion) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ForceUpdateScreen(message: message, storeUrl: storeUrl),
            ),
          );
        }
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      print('Error in getVisitsById: $e');
      rethrow;
    }
  }
}
