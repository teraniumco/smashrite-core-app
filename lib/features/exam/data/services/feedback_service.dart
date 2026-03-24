import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';
import 'package:package_info_plus/package_info_plus.dart' as package_info;

class FeedbackService {
  final ServerConnectionService _serverService = ServerConnectionService();

  static const String _pendingFeedbackKey = 'pending_feedback';
  static const String _syncedFeedbackKey = 'synced_feedback';

  // ── Shared CA SecurityContext ─────────────────────────────────────────────
  // Pinned to the Smashrite CA — same cert used across all services.
  // The plain http package cannot use a custom SecurityContext, which is
  // why it has been replaced with Dio + IOHttpClientAdapter here.
  static SecurityContext? _securityContext;

  static Future<SecurityContext> _buildSecurityContext() async {
    if (_securityContext != null) return _securityContext!;

    try {
      final caBytes = await rootBundle.load('assets/certs/smashrite_ca.crt');
      final context = SecurityContext(withTrustedRoots: false);
      context.setTrustedCertificatesBytes(caBytes.buffer.asUint8List());
      _securityContext = context;
      debugPrint('[FeedbackService][SSL] Smashrite CA loaded.');
    } catch (e) {
      debugPrint('[FeedbackService][SSL] CRITICAL: Failed to load CA cert: $e');
      rethrow;
    }

    return _securityContext!;
  }

  static Future<void> _applySecureAdapter(Dio dio) async {
    final context = await _buildSecurityContext();

    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient(context: context);
      client.badCertificateCallback = (
        X509Certificate cert,
        String host,
        int port,
      ) {
        debugPrint(
          '[FeedbackService][SSL] Rejected cert for unexpected host: $host:$port',
        );
        return false;
      };
      return client;
    };
  }

  static String _enforceHttps(String url) {
    if (url.startsWith('http://')) {
      debugPrint(
        '[FeedbackService][SSL] Warning: upgrading HTTP → HTTPS for $url',
      );
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  /// Build a CA-pinned Dio instance for a given [baseUrl] and [token].
  /// Called fresh per sync attempt so the latest server URL is always used.
  Future<Dio> _buildDio(String baseUrl, String token) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: _enforceHttps(baseUrl),
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    await _applySecureAdapter(dio);

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[FeedbackService] $obj'),
        ),
      );
    }

    return dio;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Submit feedback — stores locally first, then syncs to server over HTTPS.
  Future<Map<String, dynamic>> submitFeedback(
    Map<String, dynamic> feedbackData,
  ) async {
    try {
      final examData = _getMapFromStorage(AppConstants.currentExamData);
      final studentData = _getMapFromStorage(AppConstants.studentData);
      final accessCodeId = StorageService.get<String>(
        AppConstants.accessCodeId,
      );
      final pkgInfo = await package_info.PackageInfo.fromPlatform();

      debugPrint('[FeedbackService] examData type: ${examData.runtimeType}');
      debugPrint('[FeedbackService] studentData: $studentData');

      final enrichedFeedback = {
        ...feedbackData,
        'test_id': examData?['id'],
        'exam_title': examData?['title'],
        'student_id': studentData?['id'],
        'student_name': studentData?['full_name'],
        'studentId': studentData?['student_id'],
        'access_code_id': accessCodeId,
        'device_info': await _getDeviceInfo(),
        'app_version': pkgInfo.version,
      };

      debugPrint('[FeedbackService] Enriched feedback: $enrichedFeedback');

      // Always store locally first
      await _storeLocalFeedback(enrichedFeedback);

      // Attempt server sync
      final syncResult = await _syncToServer(enrichedFeedback);

      if (syncResult['success'] == true) {
        await _markAsSynced(enrichedFeedback);
        return {
          'success': true,
          'message': 'Feedback submitted successfully',
          'synced': true,
        };
      } else {
        return {
          'success': true,
          'message': 'Feedback saved. Will sync when online.',
          'synced': false,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('[FeedbackService] Error submitting feedback: $e');
      debugPrint('[FeedbackService] Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Failed to save feedback',
        'error': e.toString(),
      };
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Map<String, dynamic>? _getMapFromStorage(String key) {
    try {
      final data = StorageService.get(key);
      if (data == null) return null;
      if (data is Map) return Map<String, dynamic>.from(data);
      if (data is String) return jsonDecode(data) as Map<String, dynamic>;
      debugPrint(
        '[FeedbackService] Unexpected type for $key: ${data.runtimeType}',
      );
      return null;
    } catch (e) {
      debugPrint('[FeedbackService] Error parsing $key: $e');
      return null;
    }
  }

  Future<void> _storeLocalFeedback(Map<String, dynamic> feedback) async {
    try {
      final pendingData = StorageService.get(_pendingFeedbackKey);
      List<dynamic> pendingList = [];

      if (pendingData != null) {
        if (pendingData is List) {
          pendingList = pendingData;
        } else if (pendingData is String) {
          pendingList = jsonDecode(pendingData) as List;
        }
      }

      final feedbackWithId = {
        ...feedback,
        'local_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'stored_at': DateTime.now().toIso8601String(),
        'sync_attempts': 0,
      };

      pendingList.add(feedbackWithId);
      await StorageService.save(_pendingFeedbackKey, pendingList);

      debugPrint(
        '[FeedbackService] Feedback stored locally (${pendingList.length} total)',
      );
    } catch (e) {
      debugPrint('[FeedbackService] Error storing local feedback: $e');
      rethrow;
    }
  }

  /// Sync a single feedback entry to the server using a CA-pinned Dio request.
  Future<Map<String, dynamic>> _syncToServer(
    Map<String, dynamic> feedback,
  ) async {
    try {
      final server = await _serverService.getSavedServer();
      final token = StorageService.get<String>(AppConstants.accessToken);

      if (server == null || token == null) {
        debugPrint('[FeedbackService] No server or token available for sync.');
        return {'success': false, 'message': 'No server or token available'};
      }

      final dio = await _buildDio(server.url, token);

      debugPrint('[FeedbackService] Syncing to ${server.url}/student/feedback');

      final response = await dio.post('/student/feedback', data: feedback);

      debugPrint('[FeedbackService] Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[FeedbackService] Successfully synced to server.');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Feedback submitted',
          'data': response.data,
        };
      } else {
        debugPrint('[FeedbackService] Server returned ${response.statusCode}');
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      // Surface SSL failures clearly
      if (e.error is HandshakeException) {
        debugPrint(
          '[FeedbackService][SSL] HandshakeException — cert not trusted by Smashrite CA.',
        );
        return {
          'success': false,
          'message': 'SSL error: Could not verify server certificate.',
          'error': e.toString(),
        };
      }
      debugPrint('[FeedbackService] Sync DioException: ${e.message}');
      return {
        'success': false,
        'message': 'Could not connect to server',
        'error': e.toString(),
      };
    } catch (e) {
      debugPrint('[FeedbackService] Sync error: $e');
      return {
        'success': false,
        'message': 'Could not connect to server',
        'error': e.toString(),
      };
    }
  }

  Future<void> _markAsSynced(Map<String, dynamic> feedback) async {
    try {
      final pendingData = StorageService.get(_pendingFeedbackKey);
      final syncedData = StorageService.get(_syncedFeedbackKey);

      List<dynamic> pendingList = [];
      List<dynamic> syncedList = [];

      if (pendingData != null) {
        if (pendingData is List) {
          pendingList = pendingData;
        } else if (pendingData is String) {
          pendingList = jsonDecode(pendingData) as List;
        }
      }

      if (syncedData != null) {
        if (syncedData is List) {
          syncedList = syncedData;
        } else if (syncedData is String) {
          syncedList = jsonDecode(syncedData) as List;
        }
      }

      final localId = feedback['local_id'];
      pendingList.removeWhere(
        (item) => item is Map && item['local_id'] == localId,
      );

      syncedList.add({
        ...feedback,
        'synced_at': DateTime.now().toIso8601String(),
      });

      await StorageService.save(_pendingFeedbackKey, pendingList);
      await StorageService.save(_syncedFeedbackKey, syncedList);

      debugPrint(
        '[FeedbackService] Marked as synced (${pendingList.length} pending remaining)',
      );
    } catch (e) {
      debugPrint('[FeedbackService] Error marking as synced: $e');
    }
  }

  // ── Retry pending feedback ────────────────────────────────────────────────

  /// Retry syncing all pending feedback — call when app detects it is back online.
  Future<Map<String, dynamic>> syncPendingFeedback() async {
    try {
      final pendingData = StorageService.get(_pendingFeedbackKey);
      List<dynamic> pendingList = [];

      if (pendingData != null) {
        if (pendingData is List) {
          pendingList = pendingData;
        } else if (pendingData is String) {
          pendingList = jsonDecode(pendingData) as List;
        }
      }

      if (pendingList.isEmpty) {
        return {
          'success': true,
          'message': 'No pending feedback to sync',
          'synced_count': 0,
        };
      }

      debugPrint(
        '[FeedbackService] Syncing ${pendingList.length} pending feedback(s)',
      );

      int successCount = 0;
      int failCount = 0;

      final feedbacksToSync = List<dynamic>.from(pendingList);

      for (var feedback in feedbacksToSync) {
        if (feedback is! Map) continue;

        final updatedFeedback = Map<String, dynamic>.from(feedback);
        updatedFeedback['sync_attempts'] = (feedback['sync_attempts'] ?? 0) + 1;

        final result = await _syncToServer(updatedFeedback);

        if (result['success'] == true) {
          await _markAsSynced(updatedFeedback);
          successCount++;
        } else {
          failCount++;

          if (updatedFeedback['sync_attempts'] > 5) {
            debugPrint(
              '[FeedbackService] Skipping feedback after ${updatedFeedback['sync_attempts']} attempts',
            );
          } else {
            final index = pendingList.indexWhere(
              (item) =>
                  item is Map &&
                  item['local_id'] == updatedFeedback['local_id'],
            );
            if (index != -1) pendingList[index] = updatedFeedback;
          }
        }
      }

      await StorageService.save(_pendingFeedbackKey, pendingList);

      return {
        'success': true,
        'message': 'Sync complete',
        'synced_count': successCount,
        'failed_count': failCount,
      };
    } catch (e) {
      debugPrint('[FeedbackService] Error syncing pending: $e');
      return {
        'success': false,
        'message': 'Sync failed',
        'error': e.toString(),
      };
    }
  }

  // ── Device info ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      return {
        'platform': defaultTargetPlatform.name,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'platform': 'unknown', 'error': e.toString()};
    }
  }

  // ── Storage utilities ─────────────────────────────────────────────────────

  Future<int> getPendingCount() async {
    final data = StorageService.get(_pendingFeedbackKey);
    if (data == null) return 0;
    if (data is List) return data.length;
    if (data is String) return (jsonDecode(data) as List).length;
    return 0;
  }

  Future<int> getSyncedCount() async {
    final data = StorageService.get(_syncedFeedbackKey);
    if (data == null) return 0;
    if (data is List) return data.length;
    if (data is String) return (jsonDecode(data) as List).length;
    return 0;
  }

  Future<List<Map<String, dynamic>>> getPendingFeedback() async {
    final data = StorageService.get(_pendingFeedbackKey);
    if (data == null) return [];
    List<dynamic> list =
        data is List
            ? data
            : data is String
            ? jsonDecode(data) as List
            : [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSyncedFeedback() async {
    final data = StorageService.get(_syncedFeedbackKey);
    if (data == null) return [];
    List<dynamic> list =
        data is List
            ? data
            : data is String
            ? jsonDecode(data) as List
            : [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> clearAllFeedback() async {
    await StorageService.remove(_pendingFeedbackKey);
    await StorageService.remove(_syncedFeedbackKey);
    debugPrint('[FeedbackService] All feedback cleared.');
  }

  Future<void> clearSyncedFeedback() async {
    await StorageService.remove(_syncedFeedbackKey);
    debugPrint('[FeedbackService] Synced feedback cleared.');
  }
}
