import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smashrite/core/services/hive_encryption_service.dart';
import 'package:smashrite/features/exam/data/services/exam_service.dart';

class AnswerSyncService {
  static const String _pendingAnswersBox = 'pending_answers';
  static const String _pendingFlagsBox = 'pending_flags';
  static const Duration _defaultSyncInterval = Duration(minutes: 5);

  static Timer? _syncTimer;
  static bool _isSyncing = false;

  /// Initialize Hive boxes with encryption
  static Future<void> init() async {
    // Get encryption key
    final encryptionKey = await HiveEncryptionService.getEncryptionKey();
    final cipher = HiveAesCipher(encryptionKey);

    if (!Hive.isBoxOpen(_pendingAnswersBox)) {
      await Hive.openBox(_pendingAnswersBox, encryptionCipher: cipher);
    }
    if (!Hive.isBoxOpen(_pendingFlagsBox)) {
      await Hive.openBox(_pendingFlagsBox, encryptionCipher: cipher);
    }
    debugPrint('🔐 AnswerSyncService initialized with encryption');
  }

  /// Start background sync timer (lenient mode - no timeouts or failure limits)
  ///
  /// Calculates sync interval based on exam duration:
  /// - Syncs approximately 3 times during exam period (duration / 3)
  /// - Falls back to 5-minute default if no exam duration provided
  ///
  /// Example: 60-minute exam → sync every 20 minutes
  static void startBackgroundSync(
    Function(SyncStatus) onSyncStatusChanged, {
    int? examDurationMinutes,
  }) {
    stopBackgroundSync(); // Clear any existing timer

    // Calculate sync interval based on exam duration
    // Sync approximately 3 times during the exam period (duration / 3)
    final Duration interval =
        examDurationMinutes != null
            ? Duration(minutes: (examDurationMinutes / 3).ceil())
            : _defaultSyncInterval;

    _syncTimer = Timer.periodic(interval, (_) async {
      //  Background sync: no timeout, no max failures
      try {
        await syncPendingAnswers(
          onSyncStatusChanged,
          timeout: null, // No timeout for background sync
          maxFailures: null, // No failure limit for background sync
        );
      } catch (e) {
        // Background sync errors are logged but don't disrupt exam
        debugPrint('[!! WARNING !!] Background sync encountered error: $e');
      }
    });

    // Format interval display
    final intervalDisplay =
        interval.inMinutes >= 1
            ? '${interval.inMinutes}m'
            : '${interval.inSeconds}s';

    debugPrint(
      '🔄 Background sync started (every $intervalDisplay, lenient mode)',
    );
  }

  /// Stop background sync
  static void stopBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('⏹️ Background sync stopped');
  }

  // ... rest of the code remains the same

  /// Save answer locally
  static Future<void> saveAnswerLocally({
    required String attemptId,
    required String questionId,
    List<String>? selectedOptions,
    String? textAnswer,
  }) async {
    try {
      final box = Hive.box(_pendingAnswersBox);

      // Save answer with question ID as key
      await box.put(questionId, {
        'question_id': questionId,
        'selected_options': selectedOptions,
        'text_answer': textAnswer,
        'timestamp': DateTime.now().toIso8601String(),
        'attempt_id': attemptId,
      });

      debugPrint('💾 Answer saved locally: Question $questionId');
    } catch (e) {
      debugPrint('❌ Failed to save answer locally: $e');
    }
  }

  /// Save flag locally
  static Future<void> saveFlagLocally({
    required String questionId,
    required bool isFlagged,
  }) async {
    try {
      final box = Hive.box(_pendingFlagsBox);

      // Save flag with question ID as key
      await box.put(questionId, {
        'question_id': questionId,
        'is_flagged': isFlagged,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('💾 Flag saved locally: Question $questionId = $isFlagged');
    } catch (e) {
      debugPrint('❌ Failed to save flag locally: $e');
    }
  }

  /// Sync pending answers to server
  ///
  /// Parameters:
  /// - [onSyncStatusChanged]: Callback for sync status updates
  /// - [timeout]: Maximum time to wait for sync (null = no timeout, for background sync)
  /// - [maxFailures]: Max consecutive failures before stopping (null = no limit, for background sync)
  ///
  /// Throws exception if sync fails (only when maxFailures is set)
  static Future<void> syncPendingAnswers(
    Function(SyncStatus) onSyncStatusChanged, {
    Duration? timeout,
    int? maxFailures,
  }) async {
    if (_isSyncing) {
      debugPrint('⏭️ Sync already in progress, skipping...');
      return;
    }

    _isSyncing = true;

    // Determine if this is background sync (lenient) or critical sync (strict)
    final isBackgroundSync = maxFailures == null && timeout == null;

    try {
      //  Wrap the sync operation in a timeout if specified
      await (timeout != null
          ? _performSync(
            onSyncStatusChanged,
            maxFailures,
            isBackgroundSync,
          ).timeout(
            timeout,
            onTimeout: () {
              throw TimeoutException(
                'Sync operation timed out after ${timeout.inSeconds} seconds. '
                'Connection to exam server may be unavailable.',
              );
            },
          )
          : _performSync(onSyncStatusChanged, maxFailures, isBackgroundSync));
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Sync timeout: $e');
      onSyncStatusChanged(SyncStatus.error);
      rethrow;
    } catch (e) {
      debugPrint('❌ Sync error: $e');
      onSyncStatusChanged(SyncStatus.error);
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Internal method to perform the actual sync operation
  static Future<void> _performSync(
    Function(SyncStatus) onSyncStatusChanged,
    int? maxFailures,
    bool isBackgroundSync,
  ) async {
    final answersBox = Hive.box(_pendingAnswersBox);
    final flagsBox = Hive.box(_pendingFlagsBox);

    final pendingAnswers = Map<String, dynamic>.from(answersBox.toMap());
    final pendingFlags = Map<String, dynamic>.from(flagsBox.toMap());

    if (pendingAnswers.isEmpty && pendingFlags.isEmpty) {
      debugPrint('✅ No pending data to sync');
      onSyncStatusChanged(SyncStatus.synced);
      return;
    }

    final totalItems = pendingAnswers.length + pendingFlags.length;
    debugPrint(
      '🔄 ${isBackgroundSync ? 'Background' : 'Critical'} sync: '
      '${pendingAnswers.length} answers and ${pendingFlags.length} flags...',
    );
    onSyncStatusChanged(SyncStatus.syncing);

    int successCount = 0;
    int failCount = 0;
    final keysToRemove = <String>[];
    final List<String> failedItems = [];

    // Sync answers
    for (var entry in pendingAnswers.entries) {
      //  Check max failures only if limit is set (not for background sync)
      if (maxFailures != null && failCount >= maxFailures) {
        debugPrint('❌ Reached maximum failures ($maxFailures), stopping sync');
        break;
      }

      try {
        final questionId = entry.key.toString();
        final data = Map<String, dynamic>.from(entry.value);

        dynamic answer;
        if (data['text_answer'] != null) {
          answer = data['text_answer'];
        } else if (data['selected_options'] != null) {
          answer = List<String>.from(data['selected_options']);
        }

        await ExamService.saveAnswer(questionId: questionId, answer: answer);

        // Mark for removal on success
        keysToRemove.add(questionId);
        successCount++;

        if (!isBackgroundSync) {
          debugPrint(
            '✅ Synced answer for question $questionId ($successCount/$totalItems)',
          );
        }
      } catch (e) {
        failCount++;
        debugPrint(
          '[!! WARNING !!] Failed to sync answer for question ${entry.key}: $e ($failCount failures)',
        );
        failedItems.add('Answer for question ${entry.key}');

        // For background sync, continue trying all items
        // For critical sync with max failures, this will break on next iteration
      }
    }

    // Remove synced answers
    for (var key in keysToRemove) {
      await answersBox.delete(key);
    }
    keysToRemove.clear();

    //  Continue to flags only if we haven't hit max failures (or no limit set)
    final shouldContinue = maxFailures == null || failCount < maxFailures;

    if (shouldContinue) {
      // Sync flags
      for (var entry in pendingFlags.entries) {
        //  Check max failures only if limit is set
        if (maxFailures != null && failCount >= maxFailures) {
          debugPrint(
            '❌ Reached maximum failures ($maxFailures), stopping sync',
          );
          break;
        }

        try {
          final questionId = entry.key.toString();

          await ExamService.toggleFlag(questionId);

          // Mark for removal on success
          keysToRemove.add(questionId);
          successCount++;

          if (!isBackgroundSync) {
            debugPrint(
              '✅ Synced flag for question $questionId ($successCount/$totalItems)',
            );
          }
        } catch (e) {
          failCount++;
          debugPrint(
            '[!! WARNING !!] Failed to sync flag for question ${entry.key}: $e ($failCount failures)',
          );
          failedItems.add('Flag for question ${entry.key}');
        }
      }

      // Remove synced flags
      for (var key in keysToRemove) {
        await flagsBox.delete(key);
      }
    }

    debugPrint(
      '📊 ${isBackgroundSync ? 'Background' : 'Critical'} sync complete: '
      '$successCount succeeded, $failCount failed out of $totalItems total',
    );

    //  Handle results differently for background vs critical sync
    if (isBackgroundSync) {
      // Background sync: Don't throw errors, just update status
      if (successCount > 0) {
        onSyncStatusChanged(SyncStatus.synced);
        debugPrint(
          '✅ Background sync: $successCount items synced successfully',
        );
      } else {
        onSyncStatusChanged(SyncStatus.failed);
        debugPrint(
          '[!! WARNING !!] Background sync: No items synced, will retry later',
        );
      }
    } else {
      // Critical sync (exam start): Throw errors to force user decision
      if (failCount == 0) {
        // Perfect sync
        onSyncStatusChanged(SyncStatus.synced);
        debugPrint('✅ All items synced successfully');
      } else if (maxFailures != null && failCount >= maxFailures) {
        // Too many failures - likely connection issue
        onSyncStatusChanged(SyncStatus.failed);
        throw Exception(
          'Sync failed: $failCount consecutive failures detected. '
          'Connection to exam server may be lost. '
          'Successfully synced: $successCount/$totalItems items.',
        );
      } else {
        // Some failures but under threshold - partial success
        onSyncStatusChanged(SyncStatus.failed);
        throw Exception(
          'Partial sync failure: $failCount ${failCount == 1 ? 'item' : 'items'} failed to sync. '
          'Successfully synced: $successCount/$totalItems items.',
        );
      }
    }
  }

  /// Check if there are any pending answers to sync
  static Future<bool> hasPendingAnswers() async {
    try {
      final answersBox = Hive.box(_pendingAnswersBox);
      final flagsBox = Hive.box(_pendingFlagsBox);

      final hasPending = answersBox.isNotEmpty || flagsBox.isNotEmpty;

      if (hasPending) {
        debugPrint(
          '[!! WARNING !!] Found ${answersBox.length} pending answers and ${flagsBox.length} pending flags',
        );
      }

      return hasPending;
    } catch (e) {
      debugPrint('❌ Error checking pending answers: $e');
      return false;
    }
  }

  /// Get count of pending answers only (excluding flags)
  static Future<int> getPendingAnswersCount() async {
    try {
      final answersBox = Hive.box(_pendingAnswersBox);
      return answersBox.length;
    } catch (e) {
      debugPrint('❌ Error counting pending answers: $e');
      return 0;
    }
  }

  /// Get count of pending flags only
  static Future<int> getPendingFlagsCount() async {
    try {
      final flagsBox = Hive.box(_pendingFlagsBox);
      return flagsBox.length;
    } catch (e) {
      debugPrint('❌ Error counting pending flags: $e');
      return 0;
    }
  }

  /// Get detailed pending counts
  static Future<Map<String, int>> getPendingCounts() async {
    try {
      final answersBox = Hive.box(_pendingAnswersBox);
      final flagsBox = Hive.box(_pendingFlagsBox);

      return {
        'answers': answersBox.length,
        'flags': flagsBox.length,
        'total': answersBox.length + flagsBox.length,
      };
    } catch (e) {
      debugPrint('❌ Error getting pending counts: $e');
      return {'answers': 0, 'flags': 0, 'total': 0};
    }
  }

  /// Get count of pending items (total)
  static Future<int> getPendingCount() async {
    try {
      final answersBox = Hive.box(_pendingAnswersBox);
      final flagsBox = Hive.box(_pendingFlagsBox);

      return answersBox.length + flagsBox.length;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all pending data (call after exam submission)
  static Future<void> clearPendingData() async {
    try {
      final answersBox = Hive.box(_pendingAnswersBox);
      final flagsBox = Hive.box(_pendingFlagsBox);

      await answersBox.clear();
      await flagsBox.clear();

      debugPrint('🗑️ Cleared all pending sync data');
    } catch (e) {
      debugPrint('❌ Failed to clear pending data: $e');
    }
  }

  /// Force immediate sync (call before submission)
  /// Uses strict timeout and failure limits
  static Future<bool> forceSync(
    Function(SyncStatus) onSyncStatusChanged,
  ) async {
    debugPrint('⚡ Force syncing all pending data...');

    try {
      //  Force sync uses timeout and max failures
      await syncPendingAnswers(
        onSyncStatusChanged,
        timeout: const Duration(seconds: 30), // 30s timeout for submission
        maxFailures: 5, // Allow more failures during submission
      );

      final remaining = await getPendingCount();
      return remaining == 0;
    } catch (e) {
      debugPrint('❌ Force sync failed: $e');
      return false;
    }
  }

  /// Close boxes (call on app dispose)
  static Future<void> dispose() async {
    try {
      stopBackgroundSync();

      if (Hive.isBoxOpen(_pendingAnswersBox)) {
        await Hive.box(_pendingAnswersBox).close();
      }
      if (Hive.isBoxOpen(_pendingFlagsBox)) {
        await Hive.box(_pendingFlagsBox).close();
      }

      debugPrint('👋 AnswerSyncService disposed');
    } catch (e) {
      debugPrint('❌ Error disposing AnswerSyncService: $e');
    }
  }
}

/// Sync status enum
enum SyncStatus { idle, syncing, synced, failed, error }
