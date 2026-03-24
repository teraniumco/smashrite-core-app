import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freerasp/freerasp.dart';
import 'package:package_info_plus/package_info_plus.dart' as package_info;
import 'package:uuid/uuid.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';

class SecurityService {
  static Function()? onMultiWindowDetected;
  static const platform = MethodChannel('com.smashrite.core/violations');

  static Function(int count, DateTime timestamp)? onScreenshotDetected;
  static Function(bool isRecording)? onScreenRecordingChanged;
  static Function()? onAppSwitched;
  static Function()? onAppResumed;

  static Function(SecurityViolation violation)? onSecurityViolation;
  static Function()? onDeviceBindingViolation;

  static bool _isInitialized = false;
  static Timer? _recordingMonitor;
  static Timer? _periodicSecurityCheck;
  static DateTime? _lastAppSwitchTime;
  static bool _isInBackground = false;

  static String? _currentQuestionId;

  static bool _isDeviceRegistered = false;
  static bool _hasActiveViolation = false;
  static SecurityViolation? _currentViolation;
  static DeviceIdentity? _deviceIdentity;
  static String? _installationId;
  static HardwareProfile? _hardwareProfile;
  static String? _compositeFingerprint;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final ServerConnectionService _serverService =
      ServerConnectionService();
  static ExamServer? _currentServer;

  // ── Dio instances ──────────────────────────────────────────────────────────
  // _dio        → institution server (set by _configureServerConnection)
  // _defaultDio → Smashrite cloud API (api.smashrite.com)
  static Dio? _dio;
  static Dio? _defaultDio;

  // Cached SecurityContext — built once, reused for every Dio instance
  static SecurityContext? _securityContext;

  // ── Secure Dio builder ────────────────────────────────────────────────────

  /// Load the Smashrite CA from bundled assets and build a SecurityContext
  /// that trusts ONLY that CA (withTrustedRoots: false).
  /// Called once; result is cached in [_securityContext].
  static Future<SecurityContext> _buildSecurityContext() async {
    if (_securityContext != null) return _securityContext!;

    try {
      final caBytes = await rootBundle.load('assets/certs/smashrite_ca.crt');
      final context = SecurityContext(withTrustedRoots: false);
      context.setTrustedCertificatesBytes(caBytes.buffer.asUint8List());
      _securityContext = context;
      debugPrint('[SSL] SecurityContext built — Smashrite CA loaded.');
    } catch (e) {
      debugPrint('[SSL] CRITICAL: Failed to load CA cert: $e');
      rethrow; // Do NOT continue without a trusted CA
    }

    return _securityContext!;
  }

  /// Apply the Smashrite CA-pinned HttpClient to [dio].
  /// Must be called right after every Dio instance is created.
  static Future<void> _applySecureAdapter(Dio dio) async {
    final context = await _buildSecurityContext();

    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient(context: context);

      // Reject anything that does not match our CA — log and refuse
      client.badCertificateCallback = (
        X509Certificate cert,
        String host,
        int port,
      ) {
        debugPrint('[SSL] Rejected cert for unexpected host: $host:$port');
        return false;
      };

      return client;
    };

    debugPrint('[SSL] Secure adapter applied to Dio instance.');
  }

  /// Force every URL to HTTPS before making a request.
  static String _enforceHttps(String url) {
    if (url.startsWith('http://')) {
      debugPrint('[SSL] Warning: upgrading HTTP → HTTPS for $url');
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  // ── Default API client (api.smashrite.com) ────────────────────────────────

  /// Lazily build the default cloud API client.
  /// Returns a Future because applying the secure adapter is async.
  static Future<Dio> _getDefaultApiClient() async {
    if (_defaultDio != null) return _defaultDio!;

    _defaultDio = Dio(
      BaseOptions(
        baseUrl: _enforceHttps('https://api.smashrite.com/v1'),
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // ── Secure adapter ────────────────────────────────────────────────────
    await _applySecureAdapter(_defaultDio!);

    // ── Auth interceptor ──────────────────────────────────────────────────
    _defaultDio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final authToken = StorageService.get(AppConstants.accessToken);
          if (authToken != null && authToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $authToken';
            debugPrint('[API] Auth token attached');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) => handler.next(response),
        onError: (DioException error, handler) {
          _logDioError('[DefaultAPI]', error);
          return handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _defaultDio!.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[DefaultAPI] $obj'),
        ),
      );
    }

    return _defaultDio!;
  }

  // ── Institution server client (_dio) ──────────────────────────────────────

  static Future<void> _configureServerConnection({ExamServer? server}) async {
    try {
      debugPrint('[Server] Configuring server connection...');

      ExamServer? targetServer = server;
      targetServer ??= await _serverService.getSavedServer();

      _currentServer = targetServer;

      if (targetServer == null) {
        debugPrint(
          '[Server] WARNING: No server configured — institution API calls will fail.',
        );
        return;
      }

      final baseUrl = _enforceHttps(targetServer.url);
      debugPrint('[Server] Target URL: $baseUrl');

      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // ── Secure adapter ──────────────────────────────────────────────────
      await _applySecureAdapter(_dio!);

      // ── Auth interceptor ────────────────────────────────────────────────
      _dio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final authToken = StorageService.get(AppConstants.accessToken);
            if (authToken != null && authToken.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $authToken';
            }
            return handler.next(options);
          },
          onResponse: (response, handler) => handler.next(response),
          onError: (DioException error, handler) {
            _logDioError('[InstitutionAPI]', error);
            return handler.next(error);
          },
        ),
      );

      if (kDebugMode) {
        _dio!.interceptors.add(
          LogInterceptor(
            requestBody: true,
            responseBody: true,
            logPrint: (obj) => debugPrint('[InstitutionAPI] $obj'),
          ),
        );
      }

      debugPrint('[Server] Institution Dio configured: $baseUrl');
    } catch (e) {
      debugPrint('[Server] ERROR configuring server connection: $e');
    }
  }

  /// Shared DioException logger with SSL-specific messaging
  static void _logDioError(String tag, DioException error) {
    if (error.error is HandshakeException) {
      debugPrint(
        '$tag SSL HandshakeException — cert may not be signed by Smashrite CA: ${error.message}',
      );
    } else {
      debugPrint('$tag DioException [${error.type}]: ${error.message}');
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  static bool get isInitialized => _isInitialized;
  static bool get isDeviceRegistered => _isDeviceRegistered;
  static bool get hasActiveViolation => _hasActiveViolation;
  static SecurityViolation? get currentViolation => _currentViolation;
  static DeviceIdentity? get deviceIdentity => _deviceIdentity;
  static String? get installationId => _installationId;
  static String? get compositeFingerprint => _compositeFingerprint;
  static HardwareProfile? get hardwareProfile => _hardwareProfile;

  static Future<void> configureServer(ExamServer server) async {
    await _configureServerConnection(server: server);
    debugPrint('[Server] Reconfigured: ${server.url}');
  }

  static void setCurrentQuestionId(String? questionId) {
    _currentQuestionId = questionId;
    debugPrint('[Security] Current question ID: $questionId');
  }

  /// Initialize security monitoring
  static Future<void> initialize({ExamServer? server}) async {
    if (_isInitialized) {
      if (server != null) await configureServer(server);
      return;
    }

    debugPrint('[Security] Initializing enhanced security service...');

    try {
      // 0. Server connection (institution Dio)
      await _configureServerConnection(server: server);

      // 1. Installation ID
      await _initializeInstallationId();
      debugPrint(
        '[Security] Installation ID: ${_installationId?.substring(0, 8)}...',
      );

      // 2. Hardware profile
      await _collectHardwareProfile();
      debugPrint('[Security] Hardware profile collected.');

      // 3. Composite fingerprint
      await _generateCompositeFingerprint();
      debugPrint(
        '[Security] Fingerprint: ${_compositeFingerprint?.substring(0, 16)}...',
      );

      final accessToken = StorageService.get<String>(AppConstants.accessToken);
      final isAuthenticated = accessToken != null && accessToken.isNotEmpty;

      if (isAuthenticated) {
        // 4. Device registration
        await _checkDeviceRegistration();
        debugPrint('[Security] Device registered: $_isDeviceRegistered');

        // 5. Consistency check
        final consistency = await checkDeviceConsistency();
        if (!consistency.isValid) {
          debugPrint('[Security] Consistency issues detected:');
          for (var v in consistency.violations) {
            debugPrint('   - ${v.type}: ${v.description}');
          }
        }
      } else {
        debugPrint(
          '[Security] WARNING: Not authenticated — skipping device checks.',
        );
      }

      // 6. FreeRASP
      await _initializeFreeRASP();
      debugPrint('[Security] FreeRASP initialized.');

      // 7. Native monitoring
      await _setupNativeSecurityMonitoring();

      _isInitialized = true;
      debugPrint('[Security] Fully initialized.');
    } catch (e) {
      debugPrint('[Security] Initialization failed: $e');
      rethrow;
    }
  }

  // ── Device fingerprinting ─────────────────────────────────────────────────

  static Future<void> _initializeInstallationId() async {
    String? storedId = await _secureStorage.read(key: 'installation_id');
    if (storedId == null || storedId.isEmpty) {
      const uuid = Uuid();
      storedId = uuid.v4();
      await _secureStorage.write(key: 'installation_id', value: storedId);
      debugPrint('[Security] New installation ID created.');
    } else {
      debugPrint('[Security] Existing installation ID loaded.');
    }
    _installationId = storedId;
  }

  static Future<void> _collectHardwareProfile() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final pkgInfo = await package_info.PackageInfo.fromPlatform();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      _hardwareProfile = HardwareProfile(
        deviceId: androidInfo.id,
        brand: androidInfo.brand,
        manufacturer: androidInfo.manufacturer,
        model: androidInfo.model,
        hardware: androidInfo.hardware,
        product: androidInfo.product,
        device: androidInfo.device,
        osVersion: 'Android ${androidInfo.version.release}',
        sdkInt: androidInfo.version.sdkInt,
        screenWidth: 0,
        screenHeight: 0,
        screenDensity: 0,
        supportedAbis: androidInfo.supportedAbis,
        board: androidInfo.board,
        bootloader: androidInfo.bootloader,
        fingerprint: androidInfo.fingerprint,
        host: androidInfo.host,
        appVersion: pkgInfo.version,
        appBuildNumber: pkgInfo.buildNumber,
      );
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      _hardwareProfile = HardwareProfile(
        deviceId: iosInfo.identifierForVendor ?? '',
        brand: 'Apple',
        manufacturer: 'Apple',
        model: iosInfo.model,
        hardware: iosInfo.utsname.machine,
        product: iosInfo.model,
        device: iosInfo.name,
        osVersion: 'iOS ${iosInfo.systemVersion}',
        screenWidth: 0,
        screenHeight: 0,
        screenDensity: 0,
        appVersion: pkgInfo.version,
        appBuildNumber: pkgInfo.buildNumber,
      );
    }

    await _secureStorage.write(
      key: 'hardware_profile',
      value: jsonEncode(_hardwareProfile!.toJson()),
    );

    _deviceIdentity = DeviceIdentity(
      installationId: _installationId!,
      deviceName: _hardwareProfile!.device,
      deviceModel: _hardwareProfile!.model,
      osVersion: _hardwareProfile!.osVersion,
      appVersion: _hardwareProfile!.appVersion,
      registeredAt: DateTime.now(),
    );
  }

  static Future<void> _generateCompositeFingerprint() async {
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

    await _secureStorage.write(
      key: 'composite_fingerprint',
      value: _compositeFingerprint,
    );
  }

  static Future<DeviceConsistencyReport> checkDeviceConsistency() async {
    try {
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

      final installIdMatch = storedInstallationId == _installationId;
      if (!installIdMatch) {
        violations.add(
          SecurityViolation(
            type: ViolationType.deviceMismatch,
            severity: ViolationSeverity.critical,
            description: 'Installation ID mismatch detected.',
            detectedAt: DateTime.now(),
            metadata: {
              'expected': storedInstallationId,
              'actual': _installationId,
            },
          ),
        );
      }

      final fingerprintMatch = storedFingerprint == _compositeFingerprint;
      if (!fingerprintMatch) {
        violations.add(
          SecurityViolation(
            type: ViolationType.deviceMismatch,
            severity: ViolationSeverity.high,
            description: 'Device fingerprint mismatch detected.',
            detectedAt: DateTime.now(),
            metadata: {
              'expected_hash': storedFingerprint?.substring(0, 16),
              'actual_hash': _compositeFingerprint?.substring(0, 16),
            },
          ),
        );
      }

      if (storedHwProfileJson != null) {
        final storedProfile = HardwareProfile.fromJson(
          jsonDecode(storedHwProfileJson),
        );
        final changed = <String>[];
        if (storedProfile.manufacturer != _hardwareProfile!.manufacturer)
          changed.add('manufacturer');
        if (storedProfile.model != _hardwareProfile!.model)
          changed.add('model');
        if (storedProfile.brand != _hardwareProfile!.brand)
          changed.add('brand');
        if (changed.isNotEmpty) {
          violations.add(
            SecurityViolation(
              type: ViolationType.suspiciousBehavior,
              severity: ViolationSeverity.critical,
              description:
                  'Critical hardware fields changed: ${changed.join(", ")}',
              detectedAt: DateTime.now(),
              metadata: {'changed_fields': changed},
            ),
          );
        }
      }

      return DeviceConsistencyReport(
        isValid: violations.isEmpty,
        installationIdMatch: installIdMatch,
        fingerprintMatch: fingerprintMatch,
        violations: violations,
        checkedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[Security] Consistency check failed: $e');
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

  /// Verify device registration against the institution server backend
  static Future<void> _checkDeviceRegistration() async {
    try {
      final studentId = await _secureStorage.read(key: 'student_id');
      if (_compositeFingerprint == null || studentId == null) {
        _isDeviceRegistered = false;
        return;
      }

      // Use institution server Dio — requires CA cert
      final client = _dio;
      if (client == null) {
        debugPrint(
          '[Security] No institution server configured for device check.',
        );
        _isDeviceRegistered = false;
        return;
      }

      final response = await client.post(
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
      debugPrint('[Security] Device registration check failed: $e');
      _isDeviceRegistered = false;
    }
  }

  // ── FreeRASP ──────────────────────────────────────────────────────────────

  static Future<void> _initializeFreeRASP() async {
    try {
      final config = TalsecConfig(
        androidConfig: AndroidConfig(
          packageName: 'com.smashrite.core',
          signingCertHashes: [
            '0gJLOReCKvmh/rfIf6gHVGGnMIC2T4jKmRh83zugZDM=',
            '8+WltjxTGAciGT7MECW+1MNT3WQCOHZfGt4HQG37SPU=',
          ],
        ),
        iosConfig: IOSConfig(
          bundleIds: ['com.smashrite.core'],
          teamId: 'YOUR_TEAM_ID',
        ),
        watcherMail: '',
        isProd: kReleaseMode,
        killOnBypass: true, // NEW: kills app if attacker suppresses callbacks
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
        onSecureHardwareNotAvailable: () => _handleThreat('secureHardwareNotAvailable'),
        onSimulator: () => _handleThreat('simulator'),
        onUnofficialStore: () => _handleThreat('unofficialStore'),
        onDevMode: () => _handleThreat('devMode'),
        onSystemVPN: () => _handleThreat('systemVPN'),
        onTimeSpoofing: () => _handleThreat('timeSpoofing'),
        onLocationSpoofing: () => _handleThreat('locationSpoofing'),
      );

      Talsec.instance.attachListener(callback);

      await Talsec.instance
          .start(config)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('[Security] FreeRASP start timed out — continuing.');
            },
          );

      debugPrint('[Security] FreeRASP started.');
    } on TimeoutException catch (e) {
      debugPrint('[Security] FreeRASP timeout: $e — continuing with basic security.');
    } catch (e) {
      debugPrint('[Security] FreeRASP failed: $e — continuing with basic security.');
    }
  }

  static Future<void> _handleThreat(String threatType) async {
    debugPrint('[Security] THREAT DETECTED: $threatType');

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
      case 'devMode':         
      case 'timeSpoofing':    
      case 'locationSpoofing':
      case 'systemVPN':       
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
        return 'Root/Jailbreak detected. Smashrite cannot run on rooted/jailbroken devices.';
      case 'debug':
        return 'Debugger detected. Close all debugging tools and restart the app.';
      case 'simulator':
        return 'Emulator detected. Smashrite must run on a physical device.';
      case 'appIntegrity':
        return 'App tampering detected. Reinstall the official Smashrite app.';
      case 'deviceBinding':
      case 'deviceID':
        return 'Device mismatch. This device is not registered for your account.';
      case 'hooks':
        return 'Suspicious app behavior detected. Ensure no third-party tools are running.';
      case 'unofficialStore':
        return 'App not installed from official store. Download from Google Play or App Store.';
      case 'passcode':
        return 'Device passcode is disabled. Enable a passcode for security.';
      default:
        return 'Security violation detected. Contact support for assistance.';
    }
  }

  // ── Native monitoring ─────────────────────────────────────────────────────

  static Future<void> _setupNativeSecurityMonitoring() async {
    platform.setMethodCallHandler(_handleMethodCall);
    try {
      final result = await platform.invokeMethod('enableScreenSecurity');
      debugPrint(
        result == true
            ? '[Security] Screen security enabled.'
            : '[Security] Screen security not supported.',
      );
    } catch (e) {
      debugPrint('[Security] Error enabling screen security: $e');
    }

    if (Platform.isIOS) {
      _startScreenRecordingMonitor();
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScreenshotDetected':
        final count = call.arguments['count'] as int;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          ((call.arguments['timestamp'] as double) * 1000).toInt(),
        );
        debugPrint('[Security] Screenshot detected! Count: $count');
        onScreenshotDetected?.call(count, timestamp);
        await _reportScreenshotViolation(count, timestamp);
        break;

      case 'onScreenRecordingChanged':
        final isRecording = call.arguments['isRecording'] as bool;
        debugPrint(
          '[Security] Screen recording ${isRecording ? "STARTED" : "STOPPED"}',
        );
        onScreenRecordingChanged?.call(isRecording);
        if (isRecording) await _reportScreenRecordingViolation();
        break;

      case 'onMultiWindowDetected':
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          ((call.arguments['timestamp'] as double) * 1000).toInt(),
        );
        debugPrint('[Security] CRITICAL: Multi-window detected at $timestamp');
        onMultiWindowDetected?.call();
        await _reportMultiWindowViolation(timestamp);
        break;
    }
  }

  static Future<void> _reportMultiWindowViolation(DateTime timestamp) async {
    await _reportSecurityViolation(
      SecurityViolation(
        type: ViolationType.suspiciousBehavior,
        severity: ViolationSeverity.critical,
        description: 'Split-screen/Multi-window mode detected during exam.',
        detectedAt: timestamp,
        metadata: {
          'composite_fingerprint': _compositeFingerprint,
          'question_index': _currentQuestionId,
        },
      ),
    );
  }

  static void _startScreenRecordingMonitor() {
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
      } catch (_) {}
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

      final consistency = await checkDeviceConsistency();

      // Use institution Dio for periodic checks
      final client = _dio;
      if (client == null) return;

      await client.post(
        '/security/log-check',
        data: {
          'student_id': int.parse(studentId),
          'exam_attempt_id':
              examSessionId != null ? int.parse(examSessionId) : null,
          'device_id': int.parse(deviceId),
          'installation_id': _installationId,
          'root_check_passed': !_hasActiveViolation,
          'integrity_check_passed': !_hasActiveViolation,
          'device_consistency_valid': consistency.isValid,
          'composite_fingerprint': _compositeFingerprint,
          'checked_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[Security] Periodic check failed: $e');
    }
  }

  // ── Violation reporting ───────────────────────────────────────────────────

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

      final payload = {
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

      // Use institution server Dio — violations reported to local server
      final client = _dio;
      if (client != null) {
        await client.post('/security/report-violation', data: payload);
        debugPrint(
          '[Security] Violation reported: ${type.name} (${severity.name})',
        );
      } else {
        debugPrint(
          '[Security] WARNING: No Dio client — violation not reported remotely.',
        );
      }
    } catch (e) {
      debugPrint('[Security] Failed to report violation: $e');
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
    await _reportSecurityViolation(
      SecurityViolation(
        type: ViolationType.screenshot,
        severity: ViolationSeverity.high,
        description: 'Screenshot attempt detected during exam.',
        detectedAt: timestamp,
        metadata: {
          'screenshot_count': count,
          'composite_fingerprint': _compositeFingerprint,
          'question_index': _currentQuestionId,
        },
      ),
    );
  }

  static Future<void> _reportScreenRecordingViolation() async {
    await _reportSecurityViolation(
      SecurityViolation(
        type: ViolationType.screenRecording,
        severity: ViolationSeverity.critical,
        description: 'Screen recording detected during exam.',
        detectedAt: DateTime.now(),
        metadata: {
          'composite_fingerprint': _compositeFingerprint,
          'question_index': _currentQuestionId,
        },
      ),
    );
  }

  // ── Device registration ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> registerDevice({
    required int studentId,
  }) async {
    try {
      final client = _dio;
      if (client == null) throw Exception('No institution server configured.');

      final response = await client.post(
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
        debugPrint('[Security] Device registered successfully.');
      }

      return response.data;
    } catch (e) {
      debugPrint('[Security] Device registration failed: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getStudentDevices(
    int studentId,
  ) async {
    final client = _dio ?? await _getDefaultApiClient();
    final response = await client.get('/security/student-devices/$studentId');
    return List<Map<String, dynamic>>.from(response.data['devices']);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  static void handleAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        if (!_isInBackground) {
          final now = DateTime.now();
          if (_lastAppSwitchTime == null ||
              now.difference(_lastAppSwitchTime!).inSeconds >= 2) {
            _isInBackground = true;
            _lastAppSwitchTime = now;
            debugPrint('[Security] App switched — user left exam.');
            onAppSwitched?.call();
          }
        }
        break;
      case AppLifecycleState.resumed:
        _isInBackground = false;
        debugPrint('[Security] App resumed.');
        onAppResumed?.call();
        break;
      case AppLifecycleState.inactive:
        debugPrint('[Security] App inactive.');
        break;
      case AppLifecycleState.detached:
        debugPrint('[Security] App detached.');
        break;
      case AppLifecycleState.hidden:
        debugPrint('[Security] App hidden.');
        break;
    }
  }

  static Future<void> performImmediateSecurityCheck() async {
    debugPrint('[Security] Performing immediate security check...');
    try {
      await Future.delayed(const Duration(seconds: 2));
      final consistency = await checkDeviceConsistency();
      debugPrint('[Security] Has violation: $_hasActiveViolation');
      debugPrint('[Security] Violation type: ${_currentViolation?.type}');
      debugPrint('[Security] Device registered: $_isDeviceRegistered');
      debugPrint('[Security] Consistency valid: ${consistency.isValid}');
    } catch (e) {
      debugPrint('[Security] Immediate check failed: $e');
    }
  }

  static void clearViolation() {
    _hasActiveViolation = false;
    _currentViolation = null;
    debugPrint('[Security] Violation cleared.');
  }

  static Future<void> disable() async {
    debugPrint('[Security] Disabling security service...');
    try {
      await platform.invokeMethod('disableScreenSecurity');
    } catch (e) {
      debugPrint('[Security] Error disabling screen security: $e');
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
    } catch (_) {
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

// ── Models ────────────────────────────────────────────────────────────────────

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
  final int? screenWidth;
  final int? screenHeight;
  final int? screenDensity;
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
        supportedAbis:
            json['supported_abis'] != null
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
  hooks,
  devMode,
  timeSpoofing,
  locationSpoofing,
  systemVPN,
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
