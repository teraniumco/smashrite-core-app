import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';

class AuthService {
  static Dio? _dio;

  /// Initialize auth service with base URL and token
  static void initialize(String baseUrl, {String? authToken}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      ),
    );

    if (kDebugMode) {
      _dio!.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }
  }

  static Dio get dio {
    if (_dio == null) {
      throw Exception(
        'AuthService not initialized. Call AuthService.initialize() first.',
      );
    }
    return _dio!;
  }

  /// Update auth token
  static void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Login with access code and enhanced device fingerprinting
  static Future<Map<String, dynamic>> login({
    required ExamServer server,
    required String studentId,
    required String accessCode,
  }) async {
    try {
      final serverURL = dio.options.baseUrl;

      // Gather device fingerprinting data from SecurityService
      final deviceData = <String, dynamic>{
        'access_code': accessCode,
        'student_id': studentId,
      };

      // Add enhanced device fingerprinting if available
      if (SecurityService.installationId != null) {
        deviceData['installation_id'] = SecurityService.installationId;
      }

      if (SecurityService.compositeFingerprint != null) {
        deviceData['composite_fingerprint'] = SecurityService.compositeFingerprint;
      }

      if (SecurityService.hardwareProfile != null) {
        deviceData['hardware_profile'] = SecurityService.hardwareProfile!.toJson();
      }

      if (SecurityService.deviceIdentity != null) {
        deviceData['device_identity'] = SecurityService.deviceIdentity!.toJson();
      }

      debugPrint('🔐 Login request with device data:');
      debugPrint('   - Installation ID: ${SecurityService.installationId?.substring(0, 8)}...');
      debugPrint('   - Composite Fingerprint: ${SecurityService.compositeFingerprint?.substring(0, 16)}...');
      debugPrint('   - Has Hardware Profile: ${SecurityService.hardwareProfile != null}');
      debugPrint('   - Has Device Identity: ${SecurityService.deviceIdentity != null}');

      final response = await dio.post(
        '$serverURL/auth/login',
        data: deviceData,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          final responseData = data['data'] as Map<String, dynamic>;

          // Save Access code
          await StorageService.save(
            AppConstants.accessCodeId,
            responseData['access_code_id'].toString(),
          );

          // Save access token
          if (responseData['access_token'] != null) {
            await StorageService.save(
              AppConstants.accessToken,
              responseData['access_token'],
            );
          }

          // Save student data
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

            // Save entire student data as JSON
            await StorageService.save(
              AppConstants.studentData,
              jsonEncode(student),
            );
          }

          // Save test/exam data
          if (responseData['test'] != null) {
            final test = responseData['test'] as Map<String, dynamic>;
            await StorageService.save(
              AppConstants.currentExamData,
              jsonEncode(test),
            );
          }

          // Log device registration status
          final deviceRegistered = responseData['device_registered'] ?? false;
          final deviceId = responseData['device_id'];
          debugPrint('✅ Device registration status: $deviceRegistered');
          if (deviceId != null) {
            debugPrint('   Device ID: $deviceId');
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
        // Device verification failed or other forbidden responses
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
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } on DioException catch (e) {
      // Handle 403 Forbidden responses (device verification failures)
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
      final serverURL = dio.options.baseUrl;

      final response = await dio.get('$serverURL/auth/me');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw Exception('Failed to get user info');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Verify session is still active with device check
  static Future<bool> verifySession() async {
    try {
      final serverURL = dio.options.baseUrl;

      final data = <String, dynamic>{};

      // Add installation_id for device verification
      if (SecurityService.installationId != null) {
        data['installation_id'] = SecurityService.installationId;
      }

      final response = await dio.post(
        '$serverURL/auth/verify-session',
        data: data,
      );

      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      debugPrint('Session verification failed: $e');
      return false;
    }
  }

  /// Force logout from other devices
  static Future<Map<String, dynamic>> forceLogoutOtherDevices() async {
    try {
      final serverURL = dio.options.baseUrl;

      if (SecurityService.installationId == null) {
        return {
          'success': false,
          'message': 'Device information not available',
        };
      }

      final response = await dio.post(
        '$serverURL/auth/force-logout-other-devices',
        data: {
          'installation_id': SecurityService.installationId,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'Success',
          'sessions_ended': data['sessions_ended'] ?? 0,
        };
      }

      return {
        'success': false,
        'message': 'Failed to logout other devices',
      };
    } on DioException catch (e) {
      debugPrint('Force logout failed: $e');
      return {
        'success': false,
        'message': 'Failed to logout other devices',
      };
    }
  }

  /// Logout - ends session and revokes tokens
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
    } catch (e) {
      return {'success': false, 'message': 'Logout failed'};
    }
  }

  /// Handle Dio errors
  static Exception _handleDioError(DioException error) {
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