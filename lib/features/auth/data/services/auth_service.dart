import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';

class AuthService {
  static Dio? _dio;

  // ── Shared CA SecurityContext ─────────────────────────────────────────────
  // Cached after first load — same CA used by SecurityService and
  // ServerConnectionService. Building it once avoids redundant asset reads.
  static SecurityContext? _securityContext;

  static Future<SecurityContext> _buildSecurityContext() async {
    if (_securityContext != null) return _securityContext!;

    try {
      final caBytes = await rootBundle.load('assets/certs/smashrite_ca.crt');
      final context = SecurityContext(withTrustedRoots: false);
      context.setTrustedCertificatesBytes(caBytes.buffer.asUint8List());
      _securityContext = context;
      debugPrint(
        '[AuthService][SSL] Smashrite CA loaded into SecurityContext.',
      );
    } catch (e) {
      debugPrint('[AuthService][SSL] CRITICAL: Failed to load CA cert: $e');
      rethrow; // Never proceed without a trusted CA
    }

    return _securityContext!;
  }

  /// Apply the CA-pinned HttpClient to [dio].
  /// Must be called right after every Dio(...) constructor.
  static Future<void> _applySecureAdapter(Dio dio) async {
    final context = await _buildSecurityContext();

    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient(context: context);

      // Reject anything NOT signed by the Smashrite CA
      client.badCertificateCallback = (
        X509Certificate cert,
        String host,
        int port,
      ) {
        debugPrint(
          '[AuthService][SSL] Rejected cert for unexpected host: $host:$port',
        );
        return false;
      };

      return client;
    };

    debugPrint('[AuthService][SSL] Secure adapter applied.');
  }

  /// Enforce HTTPS — upgrade any http:// URL and log a warning
  static String _enforceHttps(String url) {
    if (url.startsWith('http://')) {
      debugPrint('[AuthService][SSL] Warning: upgrading HTTP → HTTPS for $url');
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Initialize the auth Dio client.
  /// Now async so the secure adapter can be applied before any request fires.
  /// Call with: await AuthService.initialize(server.url)
  static Future<void> initialize(String baseUrl, {String? authToken}) async {
    final secureUrl = _enforceHttps(baseUrl);

    _dio = Dio(
      BaseOptions(
        baseUrl: secureUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      ),
    );

    // ── Secure adapter (CA pinning) ───────────────────────────────────────
    await _applySecureAdapter(_dio!);

    // ── Debug logging ─────────────────────────────────────────────────────
    if (kDebugMode) {
      _dio!.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[AuthService] $obj'),
        ),
      );
    }

    debugPrint('[AuthService] Initialized with base URL: $secureUrl');
  }

  static Dio get dio {
    if (_dio == null) {
      throw Exception(
        'AuthService not initialized. Call await AuthService.initialize() first.',
      );
    }
    return _dio!;
  }

  /// Update the Bearer token on the active Dio instance
  static void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ── Auth methods ──────────────────────────────────────────────────────────

  /// Login with access code and enhanced device fingerprinting
  static Future<Map<String, dynamic>> login({
    required ExamServer server,
    required String studentId,
    required String accessCode,
  }) async {
    try {
      final skipCount =
          StorageService.get<int>(AppConstants.versionSkipCount) ?? 0;
      final skipsRemaining = AppConstants.maxVersionSkips - skipCount;

      if (skipsRemaining <= 0) {
        return {
          'success': false,
          'message': 'Login failed. You need to update your app version.',
          'reason': 'app_update_required',
        };
      }

      // Build payload with device fingerprinting
      final deviceData = <String, dynamic>{
        'access_code': accessCode,
        'student_id': studentId,
        'app_update_skips': skipsRemaining,
      };

      if (SecurityService.installationId != null) {
        deviceData['installation_id'] = SecurityService.installationId;
      }
      if (SecurityService.compositeFingerprint != null) {
        deviceData['composite_fingerprint'] =
            SecurityService.compositeFingerprint;
      }
      if (SecurityService.hardwareProfile != null) {
        deviceData['hardware_profile'] =
            SecurityService.hardwareProfile!.toJson();
      }
      if (SecurityService.deviceIdentity != null) {
        deviceData['device_identity'] =
            SecurityService.deviceIdentity!.toJson();
      }

      debugPrint('[AuthService] Login — device fingerprint summary:');
      debugPrint(
        '   Installation ID : ${SecurityService.installationId?.substring(0, 8)}...',
      );
      debugPrint(
        '   Fingerprint     : ${SecurityService.compositeFingerprint?.substring(0, 16)}...',
      );
      debugPrint(
        '   Hardware profile: ${SecurityService.hardwareProfile != null}',
      );
      debugPrint(
        '   Device identity : ${SecurityService.deviceIdentity != null}',
      );

      final response = await dio.post('/auth/login', data: deviceData);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          final responseData = data['data'] as Map<String, dynamic>;

          await StorageService.save(
            AppConstants.accessCodeId,
            responseData['access_code_id'].toString(),
          );

          if (responseData['access_token'] != null) {
            await StorageService.save(
              AppConstants.accessToken,
              responseData['access_token'],
            );
          }

          if (responseData['student'] != null) {
            final student = responseData['student'] as Map<String, dynamic>;
            await StorageService.save(
              AppConstants.userId,
              student['id'].toString(),
            );
            await StorageService.save(
              AppConstants.studentId,
              student['student_id'].toString(),
            );
            await StorageService.save(
              AppConstants.studentName,
              student['full_name'].toString(),
            );
            await StorageService.save(
              AppConstants.studentData,
              jsonEncode(student),
            );
          }

          if (responseData['test'] != null) {
            await StorageService.save(
              AppConstants.currentExamData,
              jsonEncode(responseData['test']),
            );
          }

          final deviceRegistered = responseData['device_registered'] ?? false;
          final deviceId = responseData['device_id'];
          debugPrint(
            '[AuthService] Device registration status: $deviceRegistered',
          );
          if (deviceId != null) {
            debugPrint('[AuthService] Device ID: $deviceId');
          }

          return {
            'success': true,
            'message': data['message'] ?? 'Login successful',
            'data': responseData,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Login failed',
            'reason': data['reason'],
            'requires_action': data['requires_action'],
            'active_session': data['active_session'],
            'device_info': data['device_info'],
          };
        }
      } else if (response.statusCode == 403) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': false,
          'message': data['message'] ?? 'Access denied',
          'reason': data['reason'],
          'requires_action': data['requires_action'] ?? false,
          'active_session': data['active_session'],
          'device_info': data['device_info'],
        };
      } else {
        final data = response.data as Map<String, dynamic>;
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } on DioException catch (e) {
      // Surface SSL errors clearly
      if (e.error is HandshakeException) {
        debugPrint(
          '[AuthService][SSL] HandshakeException on login — cert not trusted by Smashrite CA.',
        );
        return {
          'success': false,
          'message':
              'SSL error: Could not verify server certificate. Ensure the server is using a Smashrite-issued cert.',
        };
      }

      if (e.response?.statusCode == 403) {
        final data = e.response?.data as Map<String, dynamic>?;
        return {
          'success': false,
          'message': data?['message'] ?? 'Access denied',
          'reason': data?['reason'],
          'requires_action': data?['requires_action'] ?? false,
          'active_session': data?['active_session'],
          'device_info': data?['device_info'],
        };
      }

      throw _handleDioError(e);
    }
  }

  /// Get current user info
  static Future<Map<String, dynamic>> me() async {
    try {
      final response = await dio.get('/auth/me');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw Exception('Failed to get user info');
      }
    } on DioException catch (e) {
      if (e.error is HandshakeException) {
        debugPrint('[AuthService][SSL] HandshakeException on /auth/me');
        throw Exception('SSL error: Could not verify server certificate.');
      }
      throw _handleDioError(e);
    }
  }

  /// Verify session is still active with device check
  static Future<bool> verifySession() async {
    try {
      final data = <String, dynamic>{};
      if (SecurityService.installationId != null) {
        data['installation_id'] = SecurityService.installationId;
      }

      final response = await dio.post('/auth/verify-session', data: data);

      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      if (e.error is HandshakeException) {
        debugPrint('[AuthService][SSL] HandshakeException on verify-session');
      } else {
        debugPrint('[AuthService] Session verification failed: $e');
      }
      return false;
    }
  }

  /// Force logout from other devices
  static Future<Map<String, dynamic>> forceLogoutOtherDevices() async {
    try {
      if (SecurityService.installationId == null) {
        return {
          'success': false,
          'message': 'Device information not available',
        };
      }

      final response = await dio.post(
        '/auth/force-logout-other-devices',
        data: {'installation_id': SecurityService.installationId},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'Success',
          'sessions_ended': data['sessions_ended'] ?? 0,
        };
      }

      return {'success': false, 'message': 'Failed to logout other devices'};
    } on DioException catch (e) {
      if (e.error is HandshakeException) {
        debugPrint('[AuthService][SSL] HandshakeException on force-logout');
      } else {
        debugPrint('[AuthService] Force logout failed: $e');
      }
      return {'success': false, 'message': 'Failed to logout other devices'};
    }
  }

  /// Logout — ends session and revokes tokens
  static Future<Map<String, dynamic>> logout() async {
    try {
      final response = await dio.post('/auth/logout');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Logged out successfully',
          };
        }
      }

      return {'success': false, 'message': 'Logout failed'};
    } on DioException catch (e) {
      if (e.error is HandshakeException) {
        debugPrint('[AuthService][SSL] HandshakeException on logout');
      }
      return {'success': false, 'message': 'Logout failed'};
    }
  }

  // ── Error handling ────────────────────────────────────────────────────────

  static Exception _handleDioError(DioException error) {
    // Catch SSL failures with a clear message
    if (error.error is HandshakeException) {
      return Exception(
        'SSL error: Could not verify server certificate. '
        'Ensure the Smashrite CA is installed on this server.',
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please check your connection.');
      case DioExceptionType.badResponse:
        final message = error.response?.data['message'] ?? 'Request failed';
        return Exception(message);
      case DioExceptionType.cancel:
        return Exception('Request cancelled');
      case DioExceptionType.connectionError:
        return Exception('No connection to server. Check your network.');
      default:
        return Exception('An error occurred: ${error.message}');
    }
  }
}
