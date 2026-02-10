import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppStoreUtils {
  static const String _appStoreId = 'YOUR_APP_ID'; /// Actual Apple App Store ID
  
  /// Get the store name based on platform
  static String get storeName => Platform.isIOS ? 'App Store' : 'Play Store';
  
  /// Get the store URL for updating the app
  static Future<String> getStoreUrl({bool useNativeApp = false}) async {
    if (Platform.isIOS) {
      if (useNativeApp) {
        // Opens directly in App Store app
        return 'itms-apps://apps.apple.com/app/id$_appStoreId';
      } else {
        // Opens in browser first, then redirects to App Store
        return 'https://apps.apple.com/app/id$_appStoreId';
      }
    } else {
      // Android
      final packageInfo = await PackageInfo.fromPlatform();
      if (useNativeApp) {
        // Opens directly in Play Store app
        return 'market://details?id=${packageInfo.packageName}';
      } else {
        // Opens in browser first, then redirects to Play Store
        return 'https://play.google.com/store/apps/details?id=${packageInfo.packageName}';
      }
    }
  }
  
  /// Get platform-specific update button text
  static String get updateButtonText {
    return Platform.isIOS 
        ? 'Update from App Store' 
        : 'Update from Play Store';
  }
  
  /// Get platform-specific icon
  static String get storeIcon {
    return Platform.isIOS ? '🍎' : '🤖';
  }
  
  /// Validate App Store ID (iOS only)
  static bool isAppStoreIdConfigured() {
    return _appStoreId != 'YOUR_APP_ID' && _appStoreId.isNotEmpty;
  }
  
  /// Get help text for user
  static String getUpdateHelpText() {
    if (Platform.isIOS) {
      return 'You will be redirected to the App Store to update Smashrite';
    } else {
      return 'You will be redirected to the Play Store to update Smashrite';
    }
  }
}