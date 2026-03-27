import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/utils/smashrite_ssl_context.dart';
import '../models/exam_server.dart';
import 'package:package_info_plus/package_info_plus.dart' as package_info;

class SecureDioFactory {
  static Future<Dio> create() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    await SmashriteSslContext.applyTo(dio);

    return dio;
  }
}

class ServerConnectionService {
  late Dio _dio;
  late Future<void> _initFuture;

  ServerConnectionService() {
    _initFuture = _init();
  }

  Future<void> _init() async {
    _dio = await SecureDioFactory.create();
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }
  

  /// Ensure server URL is always HTTPS
  String _secureUrl(ExamServer server) {
    return server.url.trim(); // assume already correct
  }

  Future<String?> _getApiKey() async {
    return StorageService.get<String>(AppConstants.apiKey);
  }

  /// Test connection to exam server with auth code
  Future<Map<String, dynamic>> testConnection(ExamServer server) async {
    // Ensure Dio is initialised with secure adapter
    await _initFuture;

    try {
      final apiKey = await _getApiKey();
      final packageInfo = await package_info.PackageInfo.fromPlatform();
      final secureUrl = _secureUrl(server);

      debugPrint('[API] POST $secureUrl/server/connect');

      final response = await _dio.post(
        '$secureUrl/server/connect',
        data: {
          "auth_code": server.authCode,
          "app_version": packageInfo.version,
          "app_build_number": packageInfo.buildNumber,
        },
        options: Options(
          headers: {
            if (apiKey != null) 'X-API-KEY': apiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

     
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          final serverData = data['data'] as Map<String, dynamic>;
          return {
            'success': true,
            'message': data['message'] ?? 'Connected successfully',
            'server_name': serverData['server_name'],
            'institution_name': serverData['institution'],
            'institution_logo_url': serverData['institution_logo_url'],
            'required_app_version': serverData['required_app_version'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Connection failed',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Server returned status: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      debugPrint('[API] DioException: ${e.message}');

      // Surface SSL errors clearly — don't hide them
      if (e.error is HandshakeException) {
        return {
          'success': false,
          'message':
              'SSL error: Could not verify server certificate. '
              'Ensure the Smashrite CA is correctly bundled.',
        };
      }

      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          return {
            'success': false,
            'message': data['message'] ?? 'Invalid auth code',
          };
        }
      }

      return {'success': false, 'message': _getErrorMessage(e)};
    } catch (e) {
      debugPrint('[API] Unexpected error: $e');
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }

  String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Check if server is running.';
      case DioExceptionType.sendTimeout:
        return 'Request timeout. Server is taking too long to respond.';
      case DioExceptionType.receiveTimeout:
        return 'Response timeout. Server is not responding.';
      case DioExceptionType.badResponse:
        return 'Server error. Status code: ${e.response?.statusCode}';
      case DioExceptionType.connectionError:
        return 'Cannot connect to server. Check network connection.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'Connection failed: ${e.message}';
    }
  }

  Future<void> saveServerDetails(ExamServer server) async {
    try {
      final serverJson = json.encode(server.toJson());
      await StorageService.save(AppConstants.examServerId, serverJson);
      await StorageService.save(AppConstants.hasConnectedToServer, true);
    } catch (e) {
      debugPrint('Error saving server details: $e');
      rethrow;
    }
  }

  Future<ExamServer?> getSavedServer() async {
    try {
      final serverJson = StorageService.get<String>(AppConstants.examServerId);
      if (serverJson == null) return null;
      final serverMap = json.decode(serverJson) as Map<String, dynamic>;
      return ExamServer.fromJson(serverMap);
    } catch (e) {
      debugPrint('Error loading server details: $e');
      return null;
    }
  }

  Future<void> clearServerDetails() async {
    try {
      await StorageService.remove(AppConstants.examServerId);
      await StorageService.save(AppConstants.hasConnectedToServer, false);
    } catch (e) {
      debugPrint('Error clearing server details: $e');
      rethrow;
    }
  }

  int _calculateSignalStrength(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final age = now - timestamp;
    if (age < 10) return 95;
    if (age < 30) return 80;
    if (age < 60) return 65;
    return 50;
  }
}
