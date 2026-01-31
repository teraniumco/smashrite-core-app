import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart' as package_info;

class FeedbackService {
  final ServerConnectionService _serverService = ServerConnectionService();

  static const String _pendingFeedbackKey = 'pending_feedback';
  static const String _syncedFeedbackKey = 'synced_feedback';

  /// Submit feedback (stores locally and syncs to server if online)
  Future<Map<String, dynamic>> submitFeedback(
    Map<String, dynamic> feedbackData,
  ) async {
    try {
      // Get current exam and student data for context
      // Handle both String (JSON) and Map storage formats
      final examData = _getMapFromStorage(AppConstants.currentExamData);
      final studentData = _getMapFromStorage(AppConstants.studentData);
      final accessCodeId = StorageService.get<String>(
        AppConstants.accessCodeId,
      );
      final packageInfo = await package_info.PackageInfo.fromPlatform();

      debugPrint('📝 FeedbackService: examData type: ${examData.runtimeType}');
      debugPrint('📝 FeedbackService: studentData: ${studentData}');

      // Enrich feedback with metadata
      final enrichedFeedback = {
        ...feedbackData,
        'test_id': examData?['id'],
        'exam_title': examData?['title'],
        'student_id': studentData?['id'],
        'student_name': studentData?['full_name'],
        'studentId': studentData?['student_id'],
        'access_code_id': accessCodeId,
        'device_info': await _getDeviceInfo(),
        'app_version': packageInfo.version,
      };

      debugPrint('📝 FeedbackService: Enriched feedback: $enrichedFeedback');

      // Store locally first (always succeeds)
      await _storeLocalFeedback(enrichedFeedback);

      // Try to sync to server
      final syncResult = await _syncToServer(enrichedFeedback);

      if (syncResult['success'] == true) {
        // Successfully synced - move to synced storage
        await _markAsSynced(enrichedFeedback);
        return {
          'success': true,
          'message': 'Feedback submitted successfully',
          'synced': true,
        };
      } else {
        // Failed to sync but stored locally
        return {
          'success': true,
          'message': 'Feedback saved. Will sync when online.',
          'synced': false,
        };
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[!! WARNING !!] FeedbackService: Error submitting feedback: $e',
      );
      debugPrint('[!! WARNING !!] Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Failed to save feedback',
        'error': e.toString(),
      };
    }
  }

  /// Helper to get Map from storage, handling both String and Map formats
  Map<String, dynamic>? _getMapFromStorage(String key) {
    try {
      final data = StorageService.get(key);

      if (data == null) {
        return null;
      }

      // If it's already a Map
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      // If it's a String (JSON), parse it
      if (data is String) {
        return jsonDecode(data) as Map<String, dynamic>;
      }

      debugPrint(
        '[!! WARNING !!] FeedbackService: Unexpected data type for $key: ${data.runtimeType}',
      );
      return null;
    } catch (e) {
      debugPrint('[!! WARNING !!] FeedbackService: Error parsing $key: $e');
      return null;
    }
  }

  /// Store feedback locally using Hive
  Future<void> _storeLocalFeedback(Map<String, dynamic> feedback) async {
    try {
      // Get existing pending feedback
      final pendingData = StorageService.get(_pendingFeedbackKey);
      List<dynamic> pendingList = [];

      if (pendingData != null) {
        if (pendingData is List) {
          pendingList = pendingData;
        } else if (pendingData is String) {
          // If stored as JSON string
          pendingList = jsonDecode(pendingData) as List;
        }
      }

      // Add new feedback with timestamp
      final feedbackWithId = {
        ...feedback,
        'local_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'stored_at': DateTime.now().toIso8601String(),
        'sync_attempts': 0,
      };

      pendingList.add(feedbackWithId);

      // Save back to storage
      await StorageService.save(_pendingFeedbackKey, pendingList);

      debugPrint(
        '✅ FeedbackService: Feedback stored locally (${pendingList.length} total)',
      );
    } catch (e) {
      debugPrint(
        '[!! WARNING !!] FeedbackService: Error storing local feedback: $e',
      );
      rethrow;
    }
  }

  /// Sync feedback to server
  Future<Map<String, dynamic>> _syncToServer(
    Map<String, dynamic> feedback,
  ) async {
    try {
      // Get server and token
      final server = await _serverService.getSavedServer();
      final token = StorageService.get<String>(AppConstants.accessToken);

      if (server == null || token == null) {
        debugPrint(
          '[!! WARNING !!] FeedbackService: No server or token available',
        );
        return {'success': false, 'message': 'No server or token available'};
      }

      // Make API request
      final url = Uri.parse('${server.url}/student/feedback');

      debugPrint('📤 FeedbackService: Syncing to $url');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(feedback),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      debugPrint('📤 FeedbackService: Response status: ${response.statusCode}');
      debugPrint('📤 FeedbackService: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ FeedbackService: Successfully synced to server');

        return {
          'success': true,
          'message': data['message'] ?? 'Feedback submitted',
          'data': data,
        };
      } else {
        debugPrint(
          '[!! WARNING !!] FeedbackService: Server returned ${response.statusCode}',
        );
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('[!! WARNING !!] FeedbackService: Sync error: $e');
      return {
        'success': false,
        'message': 'Could not connect to server',
        'error': e.toString(),
      };
    }
  }

  /// Mark feedback as synced (move from pending to synced storage)
  Future<void> _markAsSynced(Map<String, dynamic> feedback) async {
    try {
      // Get pending and synced lists
      final pendingData = StorageService.get(_pendingFeedbackKey);
      final syncedData = StorageService.get(_syncedFeedbackKey);

      List<dynamic> pendingList = [];
      List<dynamic> syncedList = [];

      // Parse pending list
      if (pendingData != null) {
        if (pendingData is List) {
          pendingList = pendingData;
        } else if (pendingData is String) {
          pendingList = jsonDecode(pendingData) as List;
        }
      }

      // Parse synced list
      if (syncedData != null) {
        if (syncedData is List) {
          syncedList = syncedData;
        } else if (syncedData is String) {
          syncedList = jsonDecode(syncedData) as List;
        }
      }

      // Find and remove from pending
      final localId = feedback['local_id'];
      pendingList.removeWhere((item) {
        if (item is Map) {
          return item['local_id'] == localId;
        }
        return false;
      });

      // Add to synced with sync timestamp
      syncedList.add({
        ...feedback,
        'synced_at': DateTime.now().toIso8601String(),
      });

      // Save both lists
      await StorageService.save(_pendingFeedbackKey, pendingList);
      await StorageService.save(_syncedFeedbackKey, syncedList);

      debugPrint(
        '✅ FeedbackService: Marked as synced (${pendingList.length} pending remaining)',
      );
    } catch (e) {
      debugPrint(
        '[!! WARNING !!] FeedbackService: Error marking as synced: $e',
      );
    }
  }

  /// Retry syncing all pending feedback (call this when app detects online)
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
        '📤 FeedbackService: Syncing ${pendingList.length} pending feedback(s)',
      );

      int successCount = 0;
      int failCount = 0;

      // Create a copy to iterate over
      final feedbacksToSync = List<dynamic>.from(pendingList);

      for (var feedback in feedbacksToSync) {
        if (feedback is! Map) continue;

        // Increment sync attempts
        final updatedFeedback = Map<String, dynamic>.from(feedback);
        updatedFeedback['sync_attempts'] = (feedback['sync_attempts'] ?? 0) + 1;

        final result = await _syncToServer(updatedFeedback);

        if (result['success'] == true) {
          await _markAsSynced(updatedFeedback);
          successCount++;
        } else {
          failCount++;

          // If too many failed attempts (>5), skip this one for now
          if (updatedFeedback['sync_attempts'] > 5) {
            debugPrint(
              '[!! WARNING !!] FeedbackService: Skipping feedback after ${updatedFeedback['sync_attempts']} attempts',
            );
          } else {
            // Update the attempt count in storage
            final index = pendingList.indexWhere(
              (item) =>
                  item is Map &&
                  item['local_id'] == updatedFeedback['local_id'],
            );
            if (index != -1) {
              pendingList[index] = updatedFeedback;
            }
          }
        }
      }

      // Save updated pending list with new attempt counts
      await StorageService.save(_pendingFeedbackKey, pendingList);

      return {
        'success': true,
        'message': 'Sync complete',
        'synced_count': successCount,
        'failed_count': failCount,
      };
    } catch (e) {
      debugPrint('[!! WARNING !!] FeedbackService: Error syncing pending: $e');
      return {
        'success': false,
        'message': 'Sync failed',
        'error': e.toString(),
      };
    }
  }

  /// Get device info for context
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      // You can enhance this with device_info_plus package
      return {
        'platform': defaultTargetPlatform.name,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'platform': 'unknown', 'error': e.toString()};
    }
  }

  /// Get pending feedback count (useful for debugging)
  Future<int> getPendingCount() async {
    final pendingData = StorageService.get(_pendingFeedbackKey);

    if (pendingData == null) return 0;

    if (pendingData is List) {
      return pendingData.length;
    }

    if (pendingData is String) {
      final list = jsonDecode(pendingData) as List;
      return list.length;
    }

    return 0;
  }

  /// Get synced feedback count (useful for debugging)
  Future<int> getSyncedCount() async {
    final syncedData = StorageService.get(_syncedFeedbackKey);

    if (syncedData == null) return 0;

    if (syncedData is List) {
      return syncedData.length;
    }

    if (syncedData is String) {
      final list = jsonDecode(syncedData) as List;
      return list.length;
    }

    return 0;
  }

  /// Get all pending feedback (for debugging/admin view)
  Future<List<Map<String, dynamic>>> getPendingFeedback() async {
    final pendingData = StorageService.get(_pendingFeedbackKey);

    if (pendingData == null) return [];

    List<dynamic> pendingList = [];

    if (pendingData is List) {
      pendingList = pendingData;
    } else if (pendingData is String) {
      pendingList = jsonDecode(pendingData) as List;
    }

    return pendingList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Get all synced feedback (for debugging/admin view)
  Future<List<Map<String, dynamic>>> getSyncedFeedback() async {
    final syncedData = StorageService.get(_syncedFeedbackKey);

    if (syncedData == null) return [];

    List<dynamic> syncedList = [];

    if (syncedData is List) {
      syncedList = syncedData;
    } else if (syncedData is String) {
      syncedList = jsonDecode(syncedData) as List;
    }

    return syncedList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Clear all local feedback (use with caution - only for testing/cleanup)
  Future<void> clearAllFeedback() async {
    await StorageService.remove(_pendingFeedbackKey);
    await StorageService.remove(_syncedFeedbackKey);
    debugPrint('🗑️ FeedbackService: All feedback cleared');
  }

  /// Clear only synced feedback (for cleanup after successful sync)
  Future<void> clearSyncedFeedback() async {
    await StorageService.remove(_syncedFeedbackKey);
    debugPrint('🗑️ FeedbackService: Synced feedback cleared');
  }
}
