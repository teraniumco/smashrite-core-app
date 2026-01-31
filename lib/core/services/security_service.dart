import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freerasp/freerasp.dart';
import 'package:package_info_plus/package_info_plus.dart' as package_info;
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';

class SecurityService {
  static const platform = MethodChannel('com.smashrite/violations');

  // Existing callbacks for screenshot/recording/app switching
  static Function(int count, DateTime timestamp)? onScreenshotDetected;
  static Function(bool isRecording)? onScreenRecordingChanged;
  static Function()? onAppSwitched;
  static Function()? onAppResumed;

  // New callbacks for device security violations
  static Function(SecurityViolation violation)? onSecurityViolation;
  static Function()? onDeviceBindingViolation;

  // State management
  static bool _isInitialized = false;
  static Timer? _recordingMonitor;
  static Timer? _periodicSecurityCheck;
  static DateTime? _lastAppSwitchTime;
  static bool _isInBackground = false;

  static String? _currentQuestionId;

  // Enhanced device security state
  static bool _isDeviceRegistered = false;
  static bool _hasActiveViolation = false;
  static SecurityViolation? _currentViolation;
  static DeviceIdentity? _deviceIdentity; // Enhanced from DeviceInfo
  static String? _installationId; // Persistent UUID
  static HardwareProfile? _hardwareProfile;
  static String? _compositeFingerprint; // Multi-layer hash

  // Secure storage
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final ServerConnectionService _serverService =
      ServerConnectionService();
  static ExamServer? _currentServer;

  // Dio client with lazy initialization
  static Dio? _dio;

  static Dio get _apiClient {
    if (_dio == null) {
      _dio = Dio(
        BaseOptions(
          baseUrl: 'https://api.smashrite.com',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      _dio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final authToken = StorageService.get(AppConstants.accessToken);

            if (authToken != null && authToken.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $authToken';
              debugPrint('🔑 Auth token added to security request');
            }

            return handler.next(options);
          },
          onResponse: (response, handler) {
            return handler.next(response);
          },
          onError: (DioException error, handler) {
            debugPrint('❌ Security API error: ${error.message}');
            return handler.next(error);
          },
        ),
      );

      if (kDebugMode) {
        _dio!.interceptors.add(
          LogInterceptor(
            requestBody: true,
            responseBody: true,
            logPrint: (obj) => debugPrint('🔒 Security API: $obj'),
          ),
        );
      }
    }

    return _dio!;
  }

  // Enhanced getters
  static bool get isInitialized => _isInitialized;
  static bool get isDeviceRegistered => _isDeviceRegistered;
  static bool get hasActiveViolation => _hasActiveViolation;
  static SecurityViolation? get currentViolation => _currentViolation;
  static DeviceIdentity? get deviceIdentity => _deviceIdentity;
  static String? get installationId => _installationId;
  static String? get compositeFingerprint => _compositeFingerprint;
  static HardwareProfile? get hardwareProfile => _hardwareProfile;

  /// Configure server connection
  static Future<void> configureServer(ExamServer server) async {
    await _configureServerConnection(server: server);
    debugPrint('✅ Server reconfigured: ${server.url}');
  }

  /// Set current question index for violation tracking
  static void setCurrentQuestionId(String? questionId) {
    _currentQuestionId = questionId;
    debugPrint('📍 Current question index updated: $questionId');
  }

  /// Initialize security monitoring with enhanced fingerprinting
  static Future<void> initialize({ExamServer? server}) async {
    if (_isInitialized) {
      if (server != null) {
        await configureServer(server);
      }
      return;
    }

    debugPrint('🔒 Initializing enhanced security service...');

    try {
      // 0. Configure server connection
      await _configureServerConnection(server: server);

      // 1. Get or create installation ID (Layer 1)
      await _initializeInstallationId();
      debugPrint('✅ Installation ID: ${_installationId?.substring(0, 8)}...');

      // 2. Collect hardware profile (Layer 2)
      await _collectHardwareProfile();
      debugPrint('✅ Hardware profile collected');

      // 3. Generate composite fingerprint (Layer 3)
      await _generateCompositeFingerprint();
      debugPrint(
        '✅ Composite fingerprint: ${_compositeFingerprint?.substring(0, 16)}...',
      );

      // Check authentication status
      final accessToken = StorageService.get<String>(AppConstants.accessToken);
      final isAuthenticated = accessToken != null && accessToken.isNotEmpty;

      if (isAuthenticated) {
        // 4. Check device registration & consistency (Layer 4)
        await _checkDeviceRegistration();
        debugPrint('✅ Device registration status: $_isDeviceRegistered');

        // 5. Perform consistency check
        final consistency = await checkDeviceConsistency();
        if (!consistency.isValid) {
          debugPrint('⚠️ Device consistency issues detected:');
          for (var violation in consistency.violations) {
            debugPrint('   - ${violation.type}: ${violation.description}');
          }
        }
      } else {
        debugPrint(
          '[!! WARNING !!] User not authenticated, skipping device checks',
        );
      }

      // 6. Initialize FreeRASP
      await _initializeFreeRASP();
      debugPrint('✅ FreeRASP initialized');

      // 7. Setup existing screenshot/recording detection
      await _setupNativeSecurityMonitoring();

      _isInitialized = true;
      debugPrint('✅ Enhanced security service fully initialized');
    } catch (e) {
      debugPrint('❌ Security initialization failed: $e');
      rethrow;
    }
  }

  static Future<void> _configureServerConnection({ExamServer? server}) async {
    try {
      debugPrint('🔍 Configuring server connection...');
      debugPrint('   - Provided server: ${server?.url ?? "null"}');

      ExamServer? targetServer = server;

      if (targetServer == null) {
        debugPrint('   - No server provided, checking storage...');
        targetServer = await _serverService.getSavedServer();
        debugPrint('   - Loaded from storage: ${targetServer?.url ?? "null"}');
      }

      targetServer ??= await _serverService.getSavedServer();

      _currentServer = targetServer;

      if (targetServer != null) {
        _dio = Dio(
          BaseOptions(
            baseUrl: targetServer.url,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

        _dio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final authToken = StorageService.get(AppConstants.accessToken);

              if (authToken != null && authToken.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $authToken';
              }

              return handler.next(options);
            },
            onResponse: (response, handler) {
              return handler.next(response);
            },
            onError: (DioException error, handler) {
              debugPrint('❌ Security API error: ${error.message}');
              return handler.next(error);
            },
          ),
        );

        if (kDebugMode) {
          _dio!.interceptors.add(
            LogInterceptor(
              requestBody: true,
              responseBody: true,
              logPrint: (obj) => debugPrint('🔒 Security API: $obj'),
            ),
          );
        }

        debugPrint(
          '✅ Security service configured with server: ${targetServer.url}',
        );
      } else {
        debugPrint('[!! WARNING !!] No server provided, using default URL');
      }
    } catch (error) {
      debugPrint('[!! WARNING !!] Error configuring server connection: $error');
    }
  }

  /// LAYER 1: Initialize or retrieve installation ID (UUID)
  static Future<void> _initializeInstallationId() async {
    // Try to get existing installation ID
    String? storedId = await _secureStorage.read(key: 'installation_id');

    if (storedId == null || storedId.isEmpty) {
      // Generate new UUID
      const uuid = Uuid();
      storedId = uuid.v4();

      // Store persistently
      await _secureStorage.write(key: 'installation_id', value: storedId);
      debugPrint('🆕 New installation ID created');
    } else {
      debugPrint('♻️ Existing installation ID loaded');
    }

    _installationId = storedId;
  }

  /// LAYER 2: Collect comprehensive hardware profile (focused on stable identifiers)
  static Future<void> _collectHardwareProfile() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final packageInfo = await package_info.PackageInfo.fromPlatform();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;

      _hardwareProfile = HardwareProfile(
        // Core identifiers (these don't change)
        deviceId: androidInfo.id,
        brand: androidInfo.brand,
        manufacturer: androidInfo.manufacturer,
        model: androidInfo.model,
        hardware: androidInfo.hardware,
        product: androidInfo.product,
        device: androidInfo.device,

        // System info
        osVersion: 'Android ${androidInfo.version.release}',
        sdkInt: androidInfo.version.sdkInt,
        
        // Display metrics (use 0 as placeholder - not critical for fingerprinting)
        screenWidth: 0,
        screenHeight: 0,
        screenDensity: 0,

        // Additional Android-specific (stable identifiers)
        supportedAbis: androidInfo.supportedAbis,
        board: androidInfo.board,
        bootloader: androidInfo.bootloader,
        fingerprint: androidInfo.fingerprint,
        host: androidInfo.host,

        // App info
        appVersion: packageInfo.version,
        appBuildNumber: packageInfo.buildNumber,
      );
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;

      _hardwareProfile = HardwareProfile(
        // Core identifiers
        deviceId: iosInfo.identifierForVendor ?? '',
        brand: 'Apple',
        manufacturer: 'Apple',
        model: iosInfo.model,
        hardware: iosInfo.utsname.machine,
        product: iosInfo.model,
        device: iosInfo.name,

        // System info
        osVersion: 'iOS ${iosInfo.systemVersion}',
        
        // Display metrics (not available on iOS easily)
        screenWidth: 0,
        screenHeight: 0,
        screenDensity: 0,

        // App info
        appVersion: packageInfo.version,
        appBuildNumber: packageInfo.buildNumber,
      );
    }

    // Store hardware profile
    await _secureStorage.write(
      key: 'hardware_profile',
      value: jsonEncode(_hardwareProfile!.toJson()),
    );

    // Create device identity
    _deviceIdentity = DeviceIdentity(
      installationId: _installationId!,
      deviceName: _hardwareProfile!.device,
      deviceModel: _hardwareProfile!.model,
      osVersion: _hardwareProfile!.osVersion,
      appVersion: _hardwareProfile!.appVersion,
      registeredAt: DateTime.now(),
    );
  }
    
  
  /// LAYER 3: Generate composite fingerprint from multiple signals
  static Future<void> _generateCompositeFingerprint() async {
    // Combine installation ID + hardware profile + contextual data
    final fingerprintData = {
      'installation_id': _installationId,
      'hardware': {
        'brand': _hardwareProfile!.brand,
        'manufacturer': _hardwareProfile!.manufacturer,
        'model': _hardwareProfile!.model,
        'hardware': _hardwareProfile!.hardware,
        'product': _hardwareProfile!.product,
        'device': _hardwareProfile!.device,
        if (Platform.isAndroid) ...{
          'board': _hardwareProfile!.board,
          'bootloader': _hardwareProfile!.bootloader,
          'fingerprint': _hardwareProfile!.fingerprint,
          'supported_abis': _hardwareProfile!.supportedAbis,
        },
      },
      'display': {
        'width': _hardwareProfile!.screenWidth,
        'height': _hardwareProfile!.screenHeight,
        'density': _hardwareProfile!.screenDensity,
      },
      'system': {
        'os_version': _hardwareProfile!.osVersion,
        if (Platform.isAndroid) 'sdk_int': _hardwareProfile!.sdkInt,
      },
      'context': {
        'timezone_offset': DateTime.now().timeZoneOffset.inHours,
        'locale': Platform.localeName,
      },
    };

    final jsonString = json.encode(fingerprintData);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);

    _compositeFingerprint = digest.toString();

    // Store composite fingerprint
    await _secureStorage.write(
      key: 'composite_fingerprint',
      value: _compositeFingerprint,
    );
  }

  /// LAYER 4: Check device consistency (detect hardware changes, device swaps)
  static Future<DeviceConsistencyReport> checkDeviceConsistency() async {
    try {
      // Load stored fingerprints
      final storedInstallationId = await _secureStorage.read(
        key: 'installation_id',
      );
      final storedFingerprint = await _secureStorage.read(
        key: 'composite_fingerprint',
      );
      final storedHwProfileJson = await _secureStorage.read(
        key: 'hardware_profile',
      );

      final violations = <SecurityViolation>[];

      // Check 1: Installation ID consistency
      final installIdMatch = storedInstallationId == _installationId;
      if (!installIdMatch) {
        violations.add(SecurityViolation(
          type: ViolationType.deviceMismatch,
          severity: ViolationSeverity.critical,
          description: 'Installation ID mismatch - app may have been reinstalled on different device',
          detectedAt: DateTime.now(),
          metadata: {
            'expected': storedInstallationId,
            'actual': _installationId,
          },
        ));
      }

      // Check 2: Composite fingerprint consistency
      final fingerprintMatch = storedFingerprint == _compositeFingerprint;
      if (!fingerprintMatch) {
        violations.add(SecurityViolation(
          type: ViolationType.deviceMismatch,
          severity: ViolationSeverity.high,
          description: 'Device fingerprint mismatch detected',
          detectedAt: DateTime.now(),
          metadata: {
            'expected_hash': storedFingerprint?.substring(0, 16),
            'actual_hash': _compositeFingerprint?.substring(0, 16),
          },
        ));
      }

      // Check 3: Critical hardware fields (should never change)
      if (storedHwProfileJson != null) {
        final storedProfile = HardwareProfile.fromJson(
          jsonDecode(storedHwProfileJson),
        );

        final criticalFieldsChanged = <String>[];

        if (storedProfile.manufacturer != _hardwareProfile!.manufacturer) {
          criticalFieldsChanged.add('manufacturer');
        }
        if (storedProfile.model != _hardwareProfile!.model) {
          criticalFieldsChanged.add('model');
        }
        if (storedProfile.brand != _hardwareProfile!.brand) {
          criticalFieldsChanged.add('brand');
        }

        if (criticalFieldsChanged.isNotEmpty) {
          violations.add(SecurityViolation(
            type: ViolationType.suspiciousBehavior,
            severity: ViolationSeverity.critical,
            description: 'Critical hardware fields changed: ${criticalFieldsChanged.join(", ")}',
            detectedAt: DateTime.now(),
            metadata: {
              'changed_fields': criticalFieldsChanged,
            },
          ));
        }
      }

      final isValid = violations.isEmpty;

      return DeviceConsistencyReport(
        isValid: isValid,
        installationIdMatch: installIdMatch,
        fingerprintMatch: fingerprintMatch,
        violations: violations,
        checkedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Device consistency check failed: $e');
      return DeviceConsistencyReport(
        isValid: false,
        installationIdMatch: false,
        fingerprintMatch: false,
        violations: [
          SecurityViolation(
            type: ViolationType.suspiciousBehavior,
            severity: ViolationSeverity.medium,
            description: 'Consistency check failed: $e',
            detectedAt: DateTime.now(),
          ),
        ],
        checkedAt: DateTime.now(),
      );
    }
  }

  /// Check if device is registered on backend
  static Future<void> _checkDeviceRegistration() async {
    try {
      final studentId = await _secureStorage.read(key: 'student_id');

      if (_compositeFingerprint == null || studentId == null) {
        _isDeviceRegistered = false;
        return;
      }

      // Verify with backend using composite fingerprint
      final response = await _apiClient.post(
        '/security/verify-device',
        data: {
          'student_id': int.parse(studentId),
          'installation_id': _installationId,
          'device_hash': _compositeFingerprint,
          'hardware_profile': _hardwareProfile!.toJson(),
        },
      );

      _isDeviceRegistered = response.data['is_registered'] == true;

      if (_isDeviceRegistered) {
        await _secureStorage.write(
          key: 'registered_device_id',
          value: response.data['device_id'].toString(),
        );
      }
    } catch (e) {
      debugPrint('Device registration check failed: $e');
      _isDeviceRegistered = false;
    }
  }

  // Force immediate FreeRASP checks
  static Future<void> performImmediateSecurityCheck() async {
    debugPrint('🔍 Performing immediate security check...');

    try {
      await Future.delayed(const Duration(seconds: 2));

      debugPrint('✅ Security check wait complete');

      debugPrint('📊 Security State:');
      debugPrint('   - Has active violation: $_hasActiveViolation');
      debugPrint('   - Current violation: ${_currentViolation?.type}');
      debugPrint('   - Device registered: $_isDeviceRegistered');

      // Perform consistency check
      final consistency = await checkDeviceConsistency();
      debugPrint('   - Device consistency: ${consistency.isValid}');
    } catch (e) {
      debugPrint('❌ Immediate security check failed: $e');
    }
  }

  /// Initialize FreeRASP for advanced threat detection
  static Future<void> _initializeFreeRASP() async {
    try {
      final config = TalsecConfig(
        androidConfig: AndroidConfig(
          packageName: 'com.smashrite.core',
          signingCertHashes: [
            '0gJLOReCKvmh/rfIf6gHVGGnMIC2T4jKmRh83zugZDM=',
            'AVfu9jdGjC74M8zw2ubXZ4K8X2m0JcBz+h2u0+UII5U=',
          ],
        ),
        iosConfig: IOSConfig(
          bundleIds: ['com.smashrite.core'],
          teamId: 'YOUR_TEAM_ID',
        ),
        watcherMail: '',
        isProd: kReleaseMode,
      );

      final callback = ThreatCallback(
        onAppIntegrity: () => _handleThreat('appIntegrity'),
        onObfuscationIssues: () => _handleThreat('obfuscationIssues'),
        onDebug: () => _handleThreat('debug'),
        onDeviceBinding: () => _handleThreat('deviceBinding'),
        onDeviceID: () => _handleThreat('deviceID'),
        onHooks: () => _handleThreat('hooks'),
        onPasscode: () => _handleThreat('passcode'),
        onPrivilegedAccess: () => _handleThreat('privilegedAccess'),
        onSecureHardwareNotAvailable:
            () => _handleThreat('secureHardwareNotAvailable'),
        onSimulator: () => _handleThreat('simulator'),
        // onUnofficialStore: () => _handleThreat('unofficialStore'),
      );

      Talsec.instance.attachListener(callback);

      await Talsec.instance
          .start(config)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint(
                '[!! WARNING !!] FreeRASP start timed out, continuing anyway',
              );
            },
          );

      debugPrint('✅ FreeRASP started successfully');
    } on TimeoutException catch (e) {
      debugPrint('⏱️ FreeRASP initialization timed out: $e');
      debugPrint('[!! WARNING !!] Continuing with basic security features');
    } catch (e) {
      debugPrint('[!! WARNING !!] FreeRASP initialization failed: $e');
      debugPrint('[!! WARNING !!] Continuing with basic security features');
    }
  }

  /// Handle FreeRASP threat detection
  static Future<void> _handleThreat(String threatType) async {
    debugPrint('[!! WARNING !!] SECURITY THREAT DETECTED: $threatType');

    final violation = SecurityViolation(
      type: _mapThreatToViolationType(threatType),
      severity: _getThreatSeverity(threatType),
      description: _getThreatDescription(threatType),
      detectedAt: DateTime.now(),
      metadata: {
        'threat_type': threatType,
        'composite_fingerprint': _compositeFingerprint,
        'installation_id': _installationId,
        'device_model': _hardwareProfile?.model,
        'os_version': _hardwareProfile?.osVersion,
        'question_index': _currentQuestionId,
      },
    );

    await _reportSecurityViolation(violation);

    _hasActiveViolation = true;
    _currentViolation = violation;

    onSecurityViolation?.call(violation);

    if (threatType == 'deviceBinding' || threatType == 'deviceID') {
      onDeviceBindingViolation?.call();
    }
  }

  static ViolationType _mapThreatToViolationType(String threat) {
    switch (threat) {
      case 'privilegedAccess':
        return ViolationType.rootDetected;
      case 'debug':
        return ViolationType.debuggerAttached;
      case 'simulator':
        return ViolationType.emulatorDetected;
      case 'appIntegrity':
      case 'unofficialStore':
        return ViolationType.tamperedApp;
      case 'deviceBinding':
      case 'deviceID':
        return ViolationType.deviceMismatch;
      case 'hooks':
        return ViolationType.suspiciousBehavior;
      default:
        return ViolationType.suspiciousBehavior;
    }
  }

  static ViolationSeverity _getThreatSeverity(String threat) {
    switch (threat) {
      case 'privilegedAccess':
      case 'appIntegrity':
      case 'simulator':
      case 'debug':
      case 'hooks':
      case 'deviceBinding':
      case 'unofficialStore':
        return ViolationSeverity.critical;
      case 'passcode':
        return ViolationSeverity.medium;
      default:
        return ViolationSeverity.low;
    }
  }

  static String _getThreatDescription(String threat) {
    switch (threat) {
      case 'privilegedAccess':
        return 'Root/Jailbreak access detected on this device. Smashrite cannot run on rooted/jailbroken devices for security reasons.';
      case 'debug':
        return 'Debugger detected. Please close all debugging tools and restart the app.';
      case 'simulator':
        return 'Emulator/Simulator detected. Smashrite must run on physical devices only.';
      case 'appIntegrity':
        return 'App tampering detected. Please reinstall the official Smashrite app from Google Play Store or App Store.';
      case 'deviceBinding':
      case 'deviceID':
        return 'Device mismatch detected. This device is not registered for your account.';
      case 'hooks':
        return 'Suspicious app behavior detected. Please ensure no third-party tools are running.';
      case 'unofficialStore':
        return 'App not installed from official store. Please download from Google Play Store or App Store.';
      case 'passcode':
        return 'Device passcode is disabled. Please enable device passcode for security.';
      default:
        return 'Security violation detected. Please contact support for assistance.';
    }
  }

  /// Setup existing native security monitoring
  static Future<void> _setupNativeSecurityMonitoring() async {
    platform.setMethodCallHandler(_handleMethodCall);

    try {
      final result = await platform.invokeMethod('enableScreenSecurity');
      if (result == true) {
        debugPrint('✅ Screen security enabled');
      } else {
        debugPrint('[!! WARNING !!] Screen security not supported');
      }
    } catch (e) {
      debugPrint('❌ Error enabling screen security: $e');
    }

    if (Platform.isIOS) {
      _startScreenRecordingMonitor();
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('📱 Native callback: ${call.method}');

    switch (call.method) {
      case 'onScreenshotDetected':
        final count = call.arguments['count'] as int;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          ((call.arguments['timestamp'] as double) * 1000).toInt(),
        );
        debugPrint('📸 Screenshot detected! Count: $count');
        onScreenshotDetected?.call(count, timestamp);
        await _reportScreenshotViolation(count, timestamp);
        break;

      case 'onScreenRecordingChanged':
        final isRecording = call.arguments['isRecording'] as bool;
        debugPrint(
          '🎥 Screen recording ${isRecording ? "STARTED" : "STOPPED"}',
        );
        onScreenRecordingChanged?.call(isRecording);
        if (isRecording) {
          await _reportScreenRecordingViolation();
        }
        break;
    }
  }

  static void _startScreenRecordingMonitor() {
    debugPrint('🔍 Starting iOS screen recording monitor...');

    _recordingMonitor?.cancel();
    _recordingMonitor = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      try {
        final isRecording = await platform.invokeMethod('checkScreenRecording');
        if (isRecording == true) {
          onScreenRecordingChanged?.call(true);
          await _reportScreenRecordingViolation();
        }
      } catch (e) {
        // Silently ignore
      }
    });
  }

  static void _startPeriodicSecurityChecks() {
    _periodicSecurityCheck?.cancel();

    _periodicSecurityCheck = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      await _performPeriodicCheck();
    });
  }

  static Future<void> _performPeriodicCheck() async {
    try {
      final studentId = await _secureStorage.read(key: 'student_id');
      final examSessionId = await _secureStorage.read(
        key: 'current_exam_attempt_id',
      );
      final deviceId = await _secureStorage.read(key: 'registered_device_id');

      if (studentId == null || deviceId == null) return;

      // Perform consistency check
      final consistency = await checkDeviceConsistency();
      final integrityCheckPassed = !_hasActiveViolation;

      await _apiClient.post(
        '/security/log-check',
        data: {
          'student_id': int.parse(studentId),
          'exam_attempt_id':
              examSessionId != null ? int.parse(examSessionId) : null,
          'device_id': int.parse(deviceId),
          'installation_id': _installationId,
          'root_check_passed': !_hasActiveViolation,
          'integrity_check_passed': integrityCheckPassed,
          'device_consistency_valid': consistency.isValid,
          'composite_fingerprint': _compositeFingerprint,
          'checked_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Periodic check failed: $e');
    }
  }

  /// Report violation to backend
  static Future<void> reportViolation({
    required ViolationType type,
    required ViolationSeverity severity,
    required String description,
    Map<String, dynamic>? metadata,
    String? questionIndex,
  }) async {
    try {
      final studentId = await _secureStorage.read(key: 'student_id');
      final examSessionId = await _secureStorage.read(
        key: 'current_exam_attempt_id',
      );
      final deviceId = await _secureStorage.read(key: 'registered_device_id');

      final violationData = {
        'student_id': studentId != null ? int.parse(studentId) : null,
        'exam_attempt_id':
            examSessionId != null ? int.parse(examSessionId) : null,
        'device_id': deviceId != null ? int.parse(deviceId) : null,
        'installation_id': _installationId,
        'violation_type': type.name,
        'severity': severity.name,
        'description': description,
        'metadata': {
          ...?metadata,
          'composite_fingerprint': _compositeFingerprint,
          'device_model': _hardwareProfile?.model,
          'os_version': _hardwareProfile?.osVersion,
          if (questionIndex != null) 'question_index': questionIndex,
        },
        'detected_at': DateTime.now().toIso8601String(),
      };

      await _apiClient.post('/security/report-violation', data: violationData);
      debugPrint('✅ Violation reported: ${type.name} (${severity.name})');
    } catch (e) {
      debugPrint('❌ Failed to report violation: $e');
    }
  }

  static Future<void> _reportSecurityViolation(
    SecurityViolation violation,
  ) async {
    await reportViolation(
      type: violation.type,
      severity: violation.severity,
      description: violation.description,
      metadata: violation.metadata,
    );
  }

  static Future<void> _reportScreenshotViolation(
    int count,
    DateTime timestamp,
  ) async {
    final violation = SecurityViolation(
      type: ViolationType.screenshot,
      severity: ViolationSeverity.high,
      description: 'Screenshot attempt detected during exam',
      detectedAt: timestamp,
      metadata: {
        'screenshot_count': count,
        'composite_fingerprint': _compositeFingerprint,
        'question_index': _currentQuestionId,
      },
    );

    await _reportSecurityViolation(violation);
  }

  static Future<void> _reportScreenRecordingViolation() async {
    final violation = SecurityViolation(
      type: ViolationType.screenRecording,
      severity: ViolationSeverity.critical,
      description: 'Screen recording detected during exam',
      detectedAt: DateTime.now(),
      metadata: {'composite_fingerprint': _compositeFingerprint, 
        'question_index': _currentQuestionId,
      },
    );

    await _reportSecurityViolation(violation);
  }

  static void handleAppLifecycleChange(AppLifecycleState state) {
    debugPrint('🔄 App lifecycle: $state');

    switch (state) {
      case AppLifecycleState.paused:
        if (!_isInBackground) {
          final now = DateTime.now();

          if (_lastAppSwitchTime == null ||
              now.difference(_lastAppSwitchTime!).inSeconds >= 2) {
            _isInBackground = true;
            _lastAppSwitchTime = now;
            debugPrint('[!! WARNING !!] APP SWITCHED - User left exam!');
            onAppSwitched?.call();
          }
        }
        break;

      case AppLifecycleState.resumed:
        _isInBackground = false;
        debugPrint('✅ App resumed');
        onAppResumed?.call();
        break;

      case AppLifecycleState.inactive:
        debugPrint('⏸️ App inactive (transitioning)');
        break;

      case AppLifecycleState.detached:
        debugPrint('[!! WARNING !!] App detached');
        break;

      case AppLifecycleState.hidden:
        debugPrint('[!! WARNING !!] App hidden');
        break;
    }
  }


  /// Enhanced device registration with multi-layer fingerprinting
  static Future<Map<String, dynamic>> registerDevice({
    required int studentId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/security/register-device',
        data: {
          'student_id': studentId,
          'installation_id': _installationId!,
          'composite_fingerprint': _compositeFingerprint!,
          'hardware_profile': _hardwareProfile!.toJson(),
          'device_identity': _deviceIdentity!.toJson(),
        },
      );

      if (response.data['success'] == true) {
        await _secureStorage.write(
          key: 'student_id',
          value: studentId.toString(),
        );
        await _secureStorage.write(
          key: 'registered_device_id',
          value: response.data['device_id'].toString(),
        );

        _isDeviceRegistered = true;
        debugPrint('✅ Device registered successfully');
      }

      return response.data;
    } catch (e) {
      debugPrint('❌ Device registration failed: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getStudentDevices(
    int studentId,
  ) async {
    try {
      final response = await _apiClient.get(
        '/security/student-devices/$studentId',
      );
      return List<Map<String, dynamic>>.from(response.data['devices']);
    } catch (e) {
      rethrow;
    }
  }

  static void clearViolation() {
    _hasActiveViolation = false;
    _currentViolation = null;
    debugPrint('✅ Security violation cleared');
  }

  static Future<void> disable() async {
    debugPrint('🔓 Disabling security service...');

    try {
      await platform.invokeMethod('disableScreenSecurity');
    } catch (e) {
      debugPrint('Error disabling screen security: $e');
    }

    _recordingMonitor?.cancel();
    _periodicSecurityCheck?.cancel();
    _isInitialized = false;
  }

  static Future<bool> isScreenRecording() async {
    if (!Platform.isIOS) return false;

    try {
      final result = await platform.invokeMethod('checkScreenRecording');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> setCurrentExamAttempt(int examAttemptId) async {
    await _secureStorage.write(
      key: 'current_exam_attempt_id',
      value: examAttemptId.toString(),
    );
  }

  static Future<void> clearExamAttempt() async {
    await _secureStorage.delete(key: 'current_exam_attempt_id');
  }
}

// Enhanced Models

/// Device Identity - High-level device info
class DeviceIdentity {
  final String installationId;
  final String deviceName;
  final String deviceModel;
  final String osVersion;
  final String appVersion;
  final DateTime registeredAt;

  DeviceIdentity({
    required this.installationId,
    required this.deviceName,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() => {
        'installation_id': installationId,
        'device_name': deviceName,
        'device_model': deviceModel,
        'os_version': osVersion,
        'app_version': appVersion,
        'registered_at': registeredAt.toIso8601String(),
      };
}

/// Hardware Profile - Comprehensive hardware characteristics
class HardwareProfile {
  final String deviceId;
  final String brand;
  final String manufacturer;
  final String model;
  final String hardware;
  final String product;
  final String device;
  final String osVersion;
  final int? sdkInt;
  final int? screenWidth;  // Made nullable
  final int? screenHeight; // Made nullable
  final int? screenDensity; // Made nullable
  final List<String>? supportedAbis;
  final String? board;
  final String? bootloader;
  final String? fingerprint;
  final String? host;
  final String appVersion;
  final String appBuildNumber;

  HardwareProfile({
    required this.deviceId,
    required this.brand,
    required this.manufacturer,
    required this.model,
    required this.hardware,
    required this.product,
    required this.device,
    required this.osVersion,
    this.sdkInt,
    this.screenWidth,
    this.screenHeight,
    this.screenDensity,
    this.supportedAbis,
    this.board,
    this.bootloader,
    this.fingerprint,
    this.host,
    required this.appVersion,
    required this.appBuildNumber,
  });

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'brand': brand,
        'manufacturer': manufacturer,
        'model': model,
        'hardware': hardware,
        'product': product,
        'device': device,
        'os_version': osVersion,
        if (sdkInt != null) 'sdk_int': sdkInt,
        if (screenWidth != null) 'screen_width': screenWidth,
        if (screenHeight != null) 'screen_height': screenHeight,
        if (screenDensity != null) 'screen_density': screenDensity,
        if (supportedAbis != null) 'supported_abis': supportedAbis,
        if (board != null) 'board': board,
        if (bootloader != null) 'bootloader': bootloader,
        if (fingerprint != null) 'fingerprint': fingerprint,
        if (host != null) 'host': host,
        'app_version': appVersion,
        'app_build_number': appBuildNumber,
      };

  factory HardwareProfile.fromJson(Map<String, dynamic> json) =>
      HardwareProfile(
        deviceId: json['device_id'],
        brand: json['brand'],
        manufacturer: json['manufacturer'],
        model: json['model'],
        hardware: json['hardware'],
        product: json['product'],
        device: json['device'],
        osVersion: json['os_version'],
        sdkInt: json['sdk_int'],
        screenWidth: json['screen_width'],
        screenHeight: json['screen_height'],
        screenDensity: json['screen_density'],
        supportedAbis: json['supported_abis'] != null
            ? List<String>.from(json['supported_abis'])
            : null,
        board: json['board'],
        bootloader: json['bootloader'],
        fingerprint: json['fingerprint'],
        host: json['host'],
        appVersion: json['app_version'],
        appBuildNumber: json['app_build_number'],
      );
}

/// Device Consistency Report
class DeviceConsistencyReport {
  final bool isValid;
  final bool installationIdMatch;
  final bool fingerprintMatch;
  final List<SecurityViolation> violations;
  final DateTime checkedAt;

  DeviceConsistencyReport({
    required this.isValid,
    required this.installationIdMatch,
    required this.fingerprintMatch,
    required this.violations,
    required this.checkedAt,
  });
}

enum ViolationType {
  rootDetected,
  jailbreakDetected,
  developerMode,
  debuggerAttached,
  emulatorDetected,
  screenRecording,
  unauthorizedApp,
  deviceMismatch,
  tamperedApp,
  networkViolation,
  multipleDevices,
  suspiciousBehavior,
  internetConnection,
  mobileDataEnabled,
  externalInternet,
  appSwitch,
  screenshot,
}

enum ViolationSeverity { low, medium, high, critical }

class SecurityViolation {
  final ViolationType type;
  final ViolationSeverity severity;
  final String description;
  final DateTime detectedAt;
  final Map<String, dynamic>? metadata;

  SecurityViolation({
    required this.type,
    required this.severity,
    required this.description,
    required this.detectedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'violation_type': type.name,
        'severity': severity.name,
        'description': description,
        'detected_at': detectedAt.toIso8601String(),
        'metadata': metadata,
      };
}