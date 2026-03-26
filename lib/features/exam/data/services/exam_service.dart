import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:smashrite/core/utils/smashrite_ssl_context.dart';

class ExamService {
  static Dio? _dio;

  // ── Shared CA SecurityContext ──────────────────────────────────────────────
  static SecurityContext? _securityContext;

  static Future<SecurityContext> _buildSecurityContext() async {
    if (_securityContext != null) return _securityContext!;

    try {
      final caBytes = await rootBundle.load('assets/certs/smashrite_ca.crt');
      final context = SecurityContext(withTrustedRoots: false);
      context.setTrustedCertificatesBytes(caBytes.buffer.asUint8List());
      _securityContext = context;
      debugPrint('[ExamService][SSL] Smashrite CA loaded.');
    } catch (e) {
      debugPrint('[ExamService][SSL] CRITICAL: Failed to load CA cert: $e');
      rethrow;
    }

    return _securityContext!;
  }

  static Future<void> _applySecureAdapter(Dio dio) async {
    await SmashriteSslContext.applyTo(dio);
  }

  static String _enforceHttps(String url) {
    if (url.startsWith('http://')) {
      debugPrint('[ExamService][SSL] Warning: upgrading HTTP → HTTPS for $url');
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Initialize ExamService with base URL and optional auth token.
  /// Now async — must be called with await.
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

    // ── Secure adapter ────────────────────────────────────────────────────
    await _applySecureAdapter(_dio!);

    if (kDebugMode) {
      _dio!.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[ExamService] $obj'),
        ),
      );
    }

    debugPrint('[ExamService] Initialized with base URL: $secureUrl');
  }

  static Dio get dio {
    if (_dio == null) {
      throw Exception(
        'ExamService not initialized. Call await ExamService.initialize() first.',
      );
    }
    return _dio!;
  }

  static void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ── Exam methods ──────────────────────────────────────────────────────────

  /// Start exam attempt
  static Future<Map<String, dynamic>> startExam() async {
    try {
      final accessCodeId = StorageService.get<String>(
        AppConstants.accessCodeId,
      );

      if (accessCodeId == null) {
        throw Exception('Invalid access code ID');
      }

      final response = await dio.post(
        '/exam/start',
        data: {'access_code_id': accessCodeId},
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid server response');
      }

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get exam questions
  static Future<Map<String, dynamic>> getQuestions() async {
    try {
      final response = await dio.get('/exam/questions');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw Exception(
          response.data['message'] ?? 'Failed to fetch questions',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Save individual answer
  static Future<void> saveAnswer({
    required String questionId,
    dynamic answer,
    bool? isFlagged,
  }) async {
    try {
      final response = await dio.post(
        '/exam/answer',
        data: {
          'question_id': questionId,
          'answer': answer,
          if (isFlagged != null) 'is_flagged': isFlagged,
        },
      );

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception('Failed to save answer');
      }
    } on DioException catch (e) {
      if (e.error is HandshakeException) {
        debugPrint(
          '[ExamService][SSL] HandshakeException saving answer for question $questionId',
        );
        throw Exception(
          'SSL error: Could not verify server certificate while saving answer.',
        );
      }
      debugPrint('[ExamService] Answer save failed: ${e.message}');
      rethrow;
    }
  }

  /// Toggle flag on a question
  static Future<void> toggleFlag(String questionId) async {
    try {
      final response = await dio.post(
        '/exam/flag',
        data: {'question_id': questionId},
      );

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception('Failed to toggle flag');
      }
    } on DioException catch (e) {
      if (e.error is HandshakeException) {
        debugPrint(
          '[ExamService][SSL] HandshakeException toggling flag for question $questionId',
        );
        throw Exception(
          'SSL error: Could not verify server certificate while toggling flag.',
        );
      }
      debugPrint('[ExamService] Flag toggle failed: ${e.message}');
      rethrow;
    }
  }

  /// Submit exam (final submission)
  static Future<Map<String, dynamic>> submitExam() async {
    try {
      final response = await dio.post('/exam/submit');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('[ExamService] Exam submitted successfully.');
        return response.data['data'];
      } else {
        final message = response.data['message'] ?? 'Submission failed';
        debugPrint('[ExamService] Submission failed: $message');
        throw Exception(message);
      }
    } on DioException catch (e) {
      if (e.error is HandshakeException) {
        debugPrint(
          '[ExamService][SSL] HandshakeException during exam submission',
        );
        throw Exception(
          'SSL error: Could not verify server certificate during submission.',
        );
      }
      if (e.response?.statusCode == 500) {
        debugPrint(
          '[ExamService] Server error during submission: ${e.response?.data}',
        );
        throw Exception(
          'Server error occurred. Please contact support if this persists.',
        );
      }
      throw _handleDioError(e);
    }
  }

  /// Get exam progress
  static Future<Map<String, dynamic>> getProgress() async {
    try {
      final response = await dio.get('/exam/progress');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw Exception(response.data['message'] ?? 'Failed to fetch progress');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Check for internet connection.
  /// Should return false during exam — uses a plain Dio with no CA pinning
  /// since it is hitting the public internet (google.com), not a Smashrite server.
  static Future<bool> checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.wifi ||
          connectivityResult == ConnectivityResult.mobile) {
        try {
          final testDio = Dio();
          final response = await testDio.get(
            'https://www.google.com',
            options: Options(
              receiveTimeout: const Duration(seconds: 3),
              sendTimeout: const Duration(seconds: 3),
            ),
          );
          return response.statusCode == 200;
        } catch (_) {
          return false;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Error handling ────────────────────────────────────────────────────────

  static Exception _handleDioError(DioException error) {
    if (error.error is HandshakeException) {
      return Exception(
        'SSL error: Could not verify server certificate. '
        'Ensure the server is using a Smashrite-issued cert.',
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
