import 'package:dio/dio.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/features/exam/data/models/question.dart';
import 'package:smashrite/features/exam/data/models/exam_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ExamService {
  static Dio? _dio;
  
  /// Initialize Dio with your base URL
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

    // Add logging in debug mode
    if (kDebugMode) {
      _dio!.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }

  static Dio get dio {
    if (_dio == null) {
      throw Exception('ExamService not initialized. Call ExamService.initialize() first.');
    }
    return _dio!;
  }

  /// Update auth token
  static void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Start exam attempt
  static Future<Map<String, dynamic>> startExam() async {
    try {
      final accessCodeId = StorageService.get<String>(AppConstants.accessCodeId);

      if (accessCodeId == null) {
        throw Exception('Invalid access code ID');
      }

      final response = await dio.post(
        '/exam/start',
        data: {
          'access_code_id': accessCodeId,
        },
      );

      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid server response');
      }
      
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) 
      {
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
        throw Exception(response.data['message'] ?? 'Failed to fetch questions');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Save individual answer
  static Future<void> saveAnswer({
    required String questionId,
    dynamic answer, // Can be String (text), List<String> (option IDs), or null
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
      debugPrint('Answer save failed: ${e.message}');
      rethrow; // Re-throw so we know it failed
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
      debugPrint('Flag toggle failed: ${e.message}');
      rethrow;
    }
  }

  /// Submit exam (final submission)
   static Future<Map<String, dynamic>> submitExam() async {
    try {
      final response = await dio.post('/exam/submit');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ Exam submitted successfully');
        return response.data['data'];
      } else {
        final message = response.data['message'] ?? 'Submission failed';
        debugPrint('❌ Submission failed: $message');
        throw Exception(message);
      }
    } on DioException catch (e) {
      // Better error message for server errors
      if (e.response?.statusCode == 500) {
        debugPrint('❌ Server error during submission: ${e.response?.data}');
        throw Exception('Server error occurred. Please contact support if this persists.');
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

  /// Check for internet connection (should return false during exam)
  static Future<bool> checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      // If connected to WiFi or Mobile data, try to ping external site
      if (connectivityResult == ConnectivityResult.wifi ||
          connectivityResult == ConnectivityResult.mobile) {
        try {
          // Try to reach an external site (not your local server)
          final testDio = Dio();
          final response = await testDio.get(
            'https://www.google.com',
            options: Options(
              receiveTimeout: const Duration(seconds: 3),
              sendTimeout: const Duration(seconds: 3),
            ),
          );
          return response.statusCode == 200;
        } catch (e) {
          // If ping fails, no internet
          return false;
        }
      }
      
      return false;
    } catch (e) {
      return false;
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
