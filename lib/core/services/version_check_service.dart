import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smashrite/core/utils/version_utils.dart';

class VersionCheckService {
  /// Check if navigation to version check screen is needed
  static Future<bool> shouldShowVersionCheck(
    String requiredVersion,
  ) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return VersionUtils.isUpdateRequired(
        packageInfo.version,
        requiredVersion,
      );
    } catch (e) {
      debugPrint('Version check error: $e');
      return false;
    }
  }
}