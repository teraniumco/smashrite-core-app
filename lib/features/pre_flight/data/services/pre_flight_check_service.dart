import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/core/network/network_service.dart';
import 'package:smashrite/core/services/kiosk_service.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/utils/version_utils.dart';
import 'package:smashrite/features/pre_flight/data/models/pre_flight_models.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';

class PreFlightCheckService {
  // Platform channels
  static const _storageChannel = MethodChannel('com.smashrite.core/storage');
  static const _settingsChannel = MethodChannel('com.smashrite.core/settings');

  // Thresholds
  static const int _minAndroidVersion = 23; // Android 6.0
  static const String _minIOSVersion = '13.0';
  static const double _minStorageMB = 100.0;
  static const int _minBatteryLevel = 40;
  static const int _recommendedBatteryLevel = 70;
  
  /// Run all pre-flight checks
  static Future<PreFlightResult> runAllChecks({
    required Function(CheckType type, CheckStatus status, String message) onProgress,
  }) async {
    debugPrint('🚀 Starting pre-flight checks...');
    
    final checks = <CheckResult>[];
    bool canProceed = true;
    
    // Get all check types sorted by priority
    final checkTypes = List<CheckType>.from(CheckType.values)
      ..sort((a, b) => a.priority.compareTo(b.priority));
      
    // Initialize all checks as pending
    for (var type in checkTypes) {
      checks.add(CheckResult(
        type: type,
        status: CheckStatus.pending,
        message: 'Waiting...',
      ));
    }
    
    // Run checks in priority order
    for (var i = 0; i < checkTypes.length; i++) {
      final type = checkTypes[i];
      
      // Update to checking
      checks[i] = checks[i].copyWith(
        status: CheckStatus.checking,
        message: type.description,
      );
      onProgress(type, CheckStatus.checking, type.description);
      
      // Perform check
      CheckResult result;
      
      try {
        switch (type) {
          case CheckType.deviceSecurity:
            result = await _checkDeviceSecurity();
            break;
          case CheckType.networkConnectivity:
            result = await _checkNetworkConnectivity();
            break;
          case CheckType.permissions:
            result = await _checkPermissions();
            break;
          case CheckType.systemRequirements:
            result = await _checkSystemRequirements();
            break;
          case CheckType.kioskCompatibility:
            result = await _checkKioskCompatibility();
            break;
          case CheckType.previousSession:
            result = await _checkPreviousSession();
            break;
          case CheckType.serverAvailability:
            result = await _checkServerAvailability();
            break;
          case CheckType.storageSpace:
            result = await _checkStorageSpace();
            break;
          case CheckType.batteryLevel:
            result = await _checkBatteryLevel();
            break;
          case CheckType.appVersion:
            result = await _checkAppVersion();
            break;
        }
      } catch (e) {
        debugPrint('❌ Check ${type.name} failed with error: $e');
        result = CheckResult(
          type: type,
          status: CheckStatus.failed,
          message: 'Check failed: $e',
          checkedAt: DateTime.now(),
        );
      }
      
      checks[i] = result;
      onProgress(type, result.status, result.message);
      
      // Determine if we can proceed
      if (result.status == CheckStatus.failed) {
        // Critical failures stop proceeding
        if (_isCriticalCheck(type)) {
          canProceed = false;
        }
      }
      
      // Small delay for better UX
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    debugPrint('✅ Pre-flight checks complete. Can proceed: $canProceed');
    
    return PreFlightResult(
      canProceed: canProceed,
      checks: checks,
      completedAt: DateTime.now(),
    );
  }
  
  /// Check if this is a critical check
  static bool _isCriticalCheck(CheckType type) {
    return type == CheckType.deviceSecurity ||
           type == CheckType.networkConnectivity ||
           type == CheckType.systemRequirements ||
           type == CheckType.storageSpace ||
           type == CheckType.appVersion ||
           type == CheckType.permissions;
  }
  
  // ========== INDIVIDUAL CHECKS ==========
  
  /// Check device security using SecurityService
  static Future<CheckResult> _checkDeviceSecurity() async {
    debugPrint('🔒 Checking device security...');
    
    try {
      // Initialize SecurityService if not already done
      if (!SecurityService.isInitialized) {
        await SecurityService.initialize();
      }
      
      // Give FreeRASP a moment to perform checks
      await Future.delayed(const Duration(seconds: 2));
      
      // Check for active violations
      if (SecurityService.hasActiveViolation) {
        final violation = SecurityService.currentViolation;
        
        return CheckResult(
          type: CheckType.deviceSecurity,
          status: CheckStatus.failed,
          message: violation!.description,
          details: _getSecurityViolationDetails(violation.type),
          checkedAt: DateTime.now(),
        );
      }
      
      // Check device consistency (if authenticated)
      final accessToken = StorageService.get<String>(AppConstants.accessToken);
      if (accessToken != null && accessToken.isNotEmpty) {
        final consistency = await SecurityService.checkDeviceConsistency();
        
        if (!consistency.isValid) {
          return CheckResult(
            type: CheckType.deviceSecurity,
            status: CheckStatus.failed,
            message: 'Device fingerprint mismatch detected',
            details: 'This device may have been tampered with or switched. Contact administrator.',
            checkedAt: DateTime.now(),
          );
        }
      }
      
      return CheckResult(
        type: CheckType.deviceSecurity,
        status: CheckStatus.passed,
        message: 'Device security verified',
        details: 'No security threats detected',
        checkedAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Security check error: $e');
      return CheckResult(
        type: CheckType.deviceSecurity,
        status: CheckStatus.warning,
        message: 'Security check partially completed',
        details: 'Continuing with basic security features',
        checkedAt: DateTime.now(),
      );
    }
  }
  
  static String _getSecurityViolationDetails(ViolationType type) {
    switch (type) {
      case ViolationType.rootDetected:
      case ViolationType.jailbreakDetected:
        return 'Please use an unrooted/unjailbroken device to take exams.';
      case ViolationType.debuggerAttached:
        return 'Close all debugging tools and restart the app.';
      case ViolationType.emulatorDetected:
        return 'Physical devices only. Emulators are not supported.';
      case ViolationType.tamperedApp:
        return 'Reinstall Smashrite from official app store.';
      case ViolationType.deviceMismatch:
        return 'Contact administrator to reset device registration.';
      default:
        return 'Contact support for assistance.';
    }
  }
  
  /// Check network connectivity
  static Future<CheckResult> _checkNetworkConnectivity() async {
    debugPrint('📡 Checking network connectivity...');
    
    try {
      // Check WiFi connection
      final isWiFi = await NetworkService.isConnectedToWiFi();
      if (!isWiFi) {
        return CheckResult(
          type: CheckType.networkConnectivity,
          status: CheckStatus.failed,
          message: 'Not connected to WiFi',
          details: 'Turn on WiFi and connect to the exam network',
          action: CheckAction(
            label: 'Open WiFi Settings',
            onTap: () async {
              try {
                await _settingsChannel.invokeMethod('openWiFiSettings');
              } catch (e) {
                debugPrint('❌ Error opening WiFi settings: $e');
                // Fallback to general settings
                await openAppSettings();
              }
            },
          ),
          checkedAt: DateTime.now(),
        );
      }
      
      // Check for external internet (should be disabled)
      final hasInternet = await NetworkService.hasInternetAccessViaSocket();
      if (hasInternet) {
        return CheckResult(
          type: CheckType.networkConnectivity,
          status: CheckStatus.failed,
          message: 'External internet detected',
          details: 'Exam uses local network only. Disconnect from internet.',
          checkedAt: DateTime.now(),
        );
      }
      
      return CheckResult(
        type: CheckType.networkConnectivity,
        status: CheckStatus.passed,
        message: 'Network configured correctly',
        details: 'WiFi connected, no external internet',
        checkedAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Network check error: $e');
      return CheckResult(
        type: CheckType.networkConnectivity,
        status: CheckStatus.warning,
        message: 'Network check incomplete',
        details: 'Verify network manually before exam',
        checkedAt: DateTime.now(),
      );
    }
  }

  /// Check app permissions
  static Future<CheckResult> _checkPermissions() async {
    debugPrint('🔑 Checking permissions...');
    
    try {
      final missingPermissions = <String>[];
      
      // Camera permission (for QR scanning)
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        missingPermissions.add('Camera (for QR code scanning)');
      }
      
      if (missingPermissions.isNotEmpty) {
        return CheckResult(
          type: CheckType.permissions,
          status: CheckStatus.warning,
          message: '${missingPermissions.length} permission needed',
          details: 'Missing: ${missingPermissions.join(", ")}',
          action: CheckAction(
            label: 'Grant Permissions',
            onTap: () async {
              // Request permissions
              await Permission.camera.request();
            },
          ),
          checkedAt: DateTime.now(),
        );
      }
      
      return CheckResult(
        type: CheckType.permissions,
        status: CheckStatus.passed,
        message: 'All permissions granted',
        checkedAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Permission check error: $e');
      return CheckResult(
        type: CheckType.permissions,
        status: CheckStatus.warning,
        message: 'Permission check incomplete',
        details: 'You may need to grant permissions later',
        checkedAt: DateTime.now(),
      );
    }
  }
  
  /// Check system requirements
  static Future<CheckResult> _checkSystemRequirements() async {
    debugPrint('⚙️ Checking system requirements...');
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final issues = <String>[];
      
      // Check OS version
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        if (sdkInt < _minAndroidVersion) {
          issues.add('Android ${androidInfo.version.release} (requires 6.0+)');
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final version = iosInfo.systemVersion;
        final majorVersion = int.tryParse(version.split('.').first) ?? 0;
        
        if (majorVersion < 13) {
          issues.add('iOS $version (requires 13.0+)');
        }
      }
      
      if (issues.isNotEmpty) {
        return CheckResult(
          type: CheckType.systemRequirements,
          status: CheckStatus.failed,
          message: 'Device does not meet requirements',
          details: issues.join(", "),
          checkedAt: DateTime.now(),
        );
      }
      
      return CheckResult(
        type: CheckType.systemRequirements,
        status: CheckStatus.passed,
        message: 'Device meets all requirements',
        checkedAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ System requirements check error: $e');
      return CheckResult(
        type: CheckType.systemRequirements,
        status: CheckStatus.warning,
        message: 'Could not verify all requirements',
        checkedAt: DateTime.now(),
      );
    }
  }
  
  /// Check kiosk mode compatibility
  static Future<CheckResult> _checkKioskCompatibility() async {
    debugPrint('🖥️ Checking kiosk mode...');
    
    try {
      final isSupported = await KioskService.isSupported();
      
      if (!isSupported) {
        return CheckResult(
          type: CheckType.kioskCompatibility,
          status: CheckStatus.warning,
          message: 'Limited kiosk support',
          details: Platform.isIOS 
              ? 'Enable Guided Access in Settings > Accessibility'
              : 'Some device lockdown features may not work',
          checkedAt: DateTime.now(),
        );
      }
      
      return CheckResult(
        type: CheckType.kioskCompatibility,
        status: CheckStatus.passed,
        message: 'Kiosk mode supported',
        details: Platform.isIOS 
            ? 'Guided Access recommended during exam'
            : 'Full device lockdown available',
        checkedAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Kiosk check error: $e');
      return CheckResult(
        type: CheckType.kioskCompatibility,
        status: CheckStatus.passed,
        message: 'Kiosk mode status unknown',
        checkedAt: DateTime.now(),
      );
    }
  }
  
  /// Check for previous session data
  static Future<CheckResult> _checkPreviousSession() async {
    debugPrint('💾 Checking previous session...');
    
    try {
      // Check Hive boxes for pending data
      bool hasPendingData = false;
      
      // Check if answers box exists and has data
      if (Hive.isBoxOpen('answers')) {
        final answersBox = Hive.box('answers');
        hasPendingData = answersBox.isNotEmpty;
      }
      
      // Check if flags box exists and has data
      if (Hive.isBoxOpen('flags')) {
        final flagsBox = Hive.box('flags');
        hasPendingData = hasPendingData || flagsBox.isNotEmpty;
      }
      
      // Check for violation status
      final hasViolationFlag = StorageService.get<bool>(
        AppConstants.examViolationStatus,
        defaultValue: false,
      );
      
      if (hasPendingData) {
        return CheckResult(
          type: CheckType.previousSession,
          status: CheckStatus.warning,
          message: 'Unsaved data from previous session',
          details: 'Data will be synced when you start your next exam',
          checkedAt: DateTime.now(),
        );
      }
      
      if (hasViolationFlag == true) {
        return CheckResult(
          type: CheckType.previousSession,
          status: CheckStatus.warning,
          message: 'Previous exam was terminated',
          details: 'Violation status will be cleared automatically',
          checkedAt: DateTime.now(),
        );
      }
      
      return CheckResult(
        type: CheckType.previousSession,
        status: CheckStatus.passed,
        message: 'No pending session data',
        checkedAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Previous session check error: $e');
      return CheckResult(
        type: CheckType.previousSession,
        status: CheckStatus.passed,
        message: 'Session check complete',
        checkedAt: DateTime.now(),
      );
    }
  }
  
  /// Check server availability (if connected)
  static Future<CheckResult> _checkServerAvailability() async {
    debugPrint('☁️ Checking server availability...');
    
    try {
      // Check if server is configured
      final hasConnectedToServer = StorageService.get<bool>(
        AppConstants.hasConnectedToServer,
        defaultValue: false,
      );
      
      if (!hasConnectedToServer!) {
        return CheckResult(
          type: CheckType.serverAvailability,
          status: CheckStatus.passed,
          message: 'Server not configured yet',
          details: 'You will connect to exam server later',
          checkedAt: DateTime.now(),
        );
      }
      
      // Server is configured - this is informational only
      // Actual server connection happens later during exam
      return CheckResult(
        type: CheckType.serverAvailability,
        status: CheckStatus.passed,
        message: 'Server connection will be verified as you continue',
        checkedAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Server check error: $e');
      return CheckResult(
        type: CheckType.serverAvailability,
        status: CheckStatus.passed,
        message: 'Server check skipped',
        checkedAt: DateTime.now(),
      );
    }
  }

  /// Check storage space using platform channel
  static Future<CheckResult> _checkStorageSpace() async {
    debugPrint('💿 Checking storage space...');
    
    try {
      // Get free disk space from platform channel
      final freeDiskSpace = await _storageChannel.invokeMethod<double>('getFreeDiskSpace');
      
      if (freeDiskSpace == null) {
        return CheckResult(
          type: CheckType.storageSpace,
          status: CheckStatus.warning,
          message: 'Could not check storage space',
          details: 'Continuing without storage verification',
          checkedAt: DateTime.now(),
        );
      }
      
      debugPrint('💾 Free disk space: ${freeDiskSpace.toStringAsFixed(1)} MB');
      
      if (freeDiskSpace < _minStorageMB) {
        return CheckResult(
          type: CheckType.storageSpace,
          status: CheckStatus.failed,
          message: 'Insufficient storage space',
          details: '${freeDiskSpace.toStringAsFixed(1)} MB available (need ${_minStorageMB.toStringAsFixed(0)} MB)',
          action: CheckAction(
            label: 'Free Up Space',
            onTap: () async {
              try {
                await _settingsChannel.invokeMethod('openStorageSettings');
              } catch (e) {
                debugPrint('❌ Error opening storage settings: $e');
                // Fallback to general settings
                await openAppSettings();
              }
            },
          ),
          checkedAt: DateTime.now(),
        );
      }
      
      return CheckResult(
        type: CheckType.storageSpace,
        status: CheckStatus.passed,
        message: 'Sufficient storage available',
        details: '${freeDiskSpace.toStringAsFixed(1)} MB free',
        checkedAt: DateTime.now(),
      );
      
    } on PlatformException catch (e) {
      debugPrint('❌ Storage check platform error: ${e.message}');
      return CheckResult(
        type: CheckType.storageSpace,
        status: CheckStatus.warning,
        message: 'Storage check unavailable',
        details: 'Proceeding without storage verification',
        checkedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Storage check error: $e');
      return CheckResult(
        type: CheckType.storageSpace,
        status: CheckStatus.warning,
        message: 'Storage check unavailable',
        details: 'Proceeding without storage verification',
        checkedAt: DateTime.now(),
      );
    }
  }
  
  /// Check battery level
  static Future<CheckResult> _checkBatteryLevel() async {
    debugPrint('🔋 Checking battery level...');
    
    try {
      final battery = Battery();
      final batteryLevel = await battery.batteryLevel;
      
      if (batteryLevel < _minBatteryLevel) {
        return CheckResult(
          type: CheckType.batteryLevel,
          status: CheckStatus.failed,
          message: 'Battery too low',
          details: '$batteryLevel% (need at least $_minBatteryLevel%). Please charge your device.',
          // No action button - just instruction
          checkedAt: DateTime.now(),
        );
      }
      
      if (batteryLevel < _recommendedBatteryLevel) {
        return CheckResult(
          type: CheckType.batteryLevel,
          status: CheckStatus.warning,
          message: 'Battery level below recommended',
          details: '$batteryLevel% (recommended: $_recommendedBatteryLevel%+)',
          checkedAt: DateTime.now(),
        );
      }
      
      return CheckResult(
        type: CheckType.batteryLevel,
        status: CheckStatus.passed,
        message: 'Battery level sufficient',
        details: '$batteryLevel%',
        checkedAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Battery check error: $e');
      return CheckResult(
        type: CheckType.batteryLevel,
        status: CheckStatus.passed,
        message: 'Battery check unavailable',
        checkedAt: DateTime.now(),
      );
    }
  }

  /// Check app version against server requirements
  static Future<CheckResult> _checkAppVersion() async {
    debugPrint('📱 Checking app version...');
    
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // Get saved server details
      final connectionService = ServerConnectionService();
      final savedServer = await connectionService.getSavedServer();
      
      // If no server configured yet, skip version check
      if (savedServer == null || savedServer.requiredAppVersion == null) {
        return CheckResult(
          type: CheckType.appVersion,
          status: CheckStatus.passed,
          message: 'App version: v$currentVersion',
          details: 'Version check will be performed when connecting to server',
          checkedAt: DateTime.now(),
        );
      }
      
      final requiredVersion = savedServer.requiredAppVersion!;
      
      // Compare versions
      final needsUpdate = VersionUtils.isUpdateRequired(
        currentVersion,
        requiredVersion,
      );
      
      if (needsUpdate) {
        // Check skip count
        final skipCount = StorageService.get<int>(
          AppConstants.versionSkipCount,
        ) ?? 0;
        
        final skipsRemaining = AppConstants.maxVersionSkips - skipCount;
        
        if (skipsRemaining > 0) {
          return CheckResult(
            type: CheckType.appVersion,
            status: CheckStatus.warning,
            message: 'App update available',
            details: 'Current: v$currentVersion → Required: v$requiredVersion\n'
                    'You can skip $skipsRemaining more time${skipsRemaining != 1 ? 's' : ''}',
            action: CheckAction(
              label: 'Update Now',
              onTap: () async {
                // This will be handled by the navigation in the UI
                // The action just signals that update is needed
              },
            ),
            checkedAt: DateTime.now(),
          );
        } else {
          // No skips remaining - this is a failure
          return CheckResult(
            type: CheckType.appVersion,
            status: CheckStatus.failed,
            message: 'App update required',
            details: 'Current: v$currentVersion → Required: v$requiredVersion\n'
                    'Update from Play Store to continue',
            action: CheckAction(
              label: 'Update from Play Store',
              onTap: () async {
                // This will be handled by the navigation in the UI
              },
            ),
            checkedAt: DateTime.now(),
          );
        }
      }
      
      // Version is up to date
      return CheckResult(
        type: CheckType.appVersion,
        status: CheckStatus.passed,
        message: 'App version up to date',
        details: 'v$currentVersion (meets server requirement: v$requiredVersion)',
        checkedAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ App version check error: $e');
      return CheckResult(
        type: CheckType.appVersion,
        status: CheckStatus.warning,
        message: 'Version check incomplete',
        details: 'Continuing without version verification',
        checkedAt: DateTime.now(),
      );
    }
  }


  /// Force recheck of app version after user interaction
  static Future<CheckResult> recheckAppVersion() async {
    return await _checkAppVersion();
  }
}
