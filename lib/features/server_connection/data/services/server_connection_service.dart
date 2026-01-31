import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/network/udp_discovery_service.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import '../models/exam_server.dart';

/// Service for managing server connections
class ServerConnectionService {
  late Dio _dio;

  ServerConnectionService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Get API key from storage
  Future<String?> _getApiKey() async {
    return StorageService.get<String>(AppConstants.apiKey);
  }

  /// Test connection to exam server with auth code
  Future<Map<String, dynamic>> testConnection(ExamServer server) async {
    try {
      final apiKey = await _getApiKey();
      
      final response = await _dio.post(
        '${server.url}/server/connect',
        data: {
          "auth_code": server.authCode,
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
            'primary_color': serverData['primary_color'],
            'secondary_color': serverData['secondary_color'],
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
      debugPrint('Connection test failed: ${e.message}');
      
      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          return {
            'success': false,
            'message': data['message'] ?? 'Invalid auth code',
          };
        }
      }
      
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    } catch (e) {
      debugPrint('Connection test error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  /// Get user-friendly error message from DioException
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

  /// Save server details to local storage
  Future<void> saveServerDetails(ExamServer server) async {
    try {
      final serverJson = json.encode(server.toJson());
      await StorageService.save(AppConstants.examServerId, serverJson);
      await StorageService.save(AppConstants.hasConnectedToServer, true);
      debugPrint('Server details saved successfully');
    } catch (e) {
      debugPrint('Error saving server details: $e');
      rethrow;
    }
  }

  /// Get saved server details
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

  /// Clear saved server details
  Future<void> clearServerDetails() async {
    try {
      await StorageService.remove(AppConstants.examServerId);
      await StorageService.save(AppConstants.hasConnectedToServer, false);
      debugPrint('Server details cleared');
    } catch (e) {
      debugPrint('Error clearing server details: $e');
      rethrow;
    }
  }

  /// Discover servers on local network using UDP broadcast
  Future<List<ExamServer>> discoverServers() async {
    try {
      debugPrint('🔍 Starting server discovery...');
      
      final discoveryService = UdpDiscoveryService();
      final discoveredServers = await discoveryService.discoverServers();
      
      debugPrint('📡 Found ${discoveredServers.length} server(s)');
      
      // Convert discovered servers to ExamServer objects
      final examServers = discoveredServers.map((server) {
        return ExamServer(
          name: server.serverName,
          ipAddress: server.serverIp,
          port: server.port,
          signalStrength: _calculateSignalStrength(server.timestamp),
        );
      }).toList();
      
      // Sort by signal strength (newest broadcasts = stronger signal)
      examServers.sort((a, b) => 
        (b.signalStrength ?? 0).compareTo(a.signalStrength ?? 0)
      );
      
      return examServers;
    } catch (e) {
      debugPrint('❌ Discovery error: $e');
      return [];
    }
  }

  /// Calculate signal strength based on broadcast freshness
  /// Newer broadcasts = stronger signal (0-100%)
  int _calculateSignalStrength(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final age = now - timestamp;
    
    if (age < 10) return 95; // Very fresh (< 10 seconds)
    if (age < 30) return 80; // Fresh (< 30 seconds)
    if (age < 60) return 65; // Somewhat fresh (< 1 minute)
    return 50; // Older broadcast
  }
}