import 'package:hive_flutter/hive_flutter.dart';
import 'package:smashrite/core/services/hive_encryption_service.dart';
import 'package:smashrite/features/exam/data/models/exam_session.dart';
import 'package:smashrite/features/exam/data/models/question.dart';
import 'package:smashrite/features/exam/data/services/answer_sync_service.dart';

class ExamStorageService {
  static const String _examSessionBox = 'exam_sessions';
  static const String _answersBox = 'exam_answers';
  static const String _violationsBox = 'exam_violations';
  static const String _syncMetaBox = 'sync_metadata';

  /// Initialize Hive boxes with encryption
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Get encryption key
    final encryptionKey = await HiveEncryptionService.getEncryptionKey();
    final cipher = HiveAesCipher(encryptionKey);
    
    // Open all boxes with encryption
    await Hive.openBox(_examSessionBox, encryptionCipher: cipher);
    await Hive.openBox(_answersBox, encryptionCipher: cipher);
    await Hive.openBox(_violationsBox, encryptionCipher: cipher);
    await Hive.openBox(_syncMetaBox, encryptionCipher: cipher);
    
    // Initialize AnswerSyncService boxes
    await AnswerSyncService.init();
  }

  /// Save exam session
  static Future<void> saveExamSession(ExamSession session) async {
    final box = Hive.box(_examSessionBox);
    await box.put(session.id, session.toJson());
  }

  /// Load exam session
  static Future<ExamSession?> loadExamSession(String examId) async {
    final box = Hive.box(_examSessionBox);
    
    // Find session by exam ID (not session ID)
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null && data['exam_id'] == examId) {
        // Check if session is not yet submitted
        if (data['status'] == 'in_progress') {
          return ExamSession.fromJson(Map<String, dynamic>.from(data));
        }
      }
    }
    
    return null;
  }

  /// Save individual answer
  static Future<void> saveAnswer(String sessionId, Answer answer) async {
    final box = Hive.box(_answersBox);
    final key = '${sessionId}_${answer.questionId}';
    await box.put(key, answer.toJson());
  }

  /// Load all answers for a session
  static Future<Map<String, Answer>> loadAnswers(String sessionId) async {
    final box = Hive.box(_answersBox);
    final answers = <String, Answer>{};
    
    for (var key in box.keys) {
      if (key.toString().startsWith('${sessionId}_')) {
        final data = box.get(key);
        if (data != null) {
          final answer = Answer.fromJson(Map<String, dynamic>.from(data));
          answers[answer.questionId] = answer;
        }
      }
    }
    
    return answers;
  }

  /// Save flagged questions
  static Future<void> saveFlaggedQuestions(
    String sessionId,
    List<String> flaggedQuestions,
  ) async {
    final box = Hive.box(_examSessionBox);
    final sessionData = box.get(sessionId);
    
    if (sessionData != null) {
      sessionData['flagged_questions'] = flaggedQuestions;
      await box.put(sessionId, sessionData);
    }
  }

  /// Save violation log
  static Future<void> saveViolation(
    String sessionId,
    ViolationLog violation,
  ) async {
    final box = Hive.box(_violationsBox);
    final key = '${sessionId}_${violation.timestamp.millisecondsSinceEpoch}';
    await box.put(key, violation.toJson());
  }

  /// Load all violations for a session
  static Future<List<ViolationLog>> loadViolations(String sessionId) async {
    final box = Hive.box(_violationsBox);
    final violations = <ViolationLog>[];
    
    for (var key in box.keys) {
      if (key.toString().startsWith('${sessionId}_')) {
        final data = box.get(key);
        if (data != null) {
          violations.add(
            ViolationLog.fromJson(Map<String, dynamic>.from(data)),
          );
        }
      }
    }
    
    return violations;
  }

  /// Update last sync time
  static Future<void> updateLastSyncTime(
    String sessionId,
    DateTime syncTime,
  ) async {
    final box = Hive.box(_syncMetaBox);
    await box.put('${sessionId}_last_sync', syncTime.toIso8601String());
  }

  /// Get last sync time
  static Future<DateTime?> getLastSyncTime(String sessionId) async {
    final box = Hive.box(_syncMetaBox);
    final syncTimeStr = box.get('${sessionId}_last_sync');
    
    if (syncTimeStr != null) {
      return DateTime.parse(syncTimeStr);
    }
    
    return null;
  }

  /// Clear exam session after successful submission
  static Future<void> clearExamSession(String sessionId) async {
    // Clear session
    final sessionBox = Hive.box(_examSessionBox);
    await sessionBox.delete(sessionId);
    
    // Clear answers
    final answersBox = Hive.box(_answersBox);
    final answerKeys = answersBox.keys
        .where((key) => key.toString().startsWith('${sessionId}_'))
        .toList();
    for (var key in answerKeys) {
      await answersBox.delete(key);
    }
    
    // Clear violations
    final violationsBox = Hive.box(_violationsBox);
    final violationKeys = violationsBox.keys
        .where((key) => key.toString().startsWith('${sessionId}_'))
        .toList();
    for (var key in violationKeys) {
      await violationsBox.delete(key);
    }
    
    // Clear sync metadata
    final syncBox = Hive.box(_syncMetaBox);
    await syncBox.delete('${sessionId}_last_sync');
  }

  /// Get pending sessions (sessions that failed to submit)
  static Future<List<ExamSession>> getPendingSessions() async {
    final box = Hive.box(_examSessionBox);
    final sessions = <ExamSession>[];
    
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final session = ExamSession.fromJson(Map<String, dynamic>.from(data));
        if (session.status == ExamStatus.submitted && 
            session.submittedAt != null) {
          sessions.add(session);
        }
      }
    }
    
    return sessions;
  }

  /// Retry submitting pending sessions
  static Future<void> retryPendingSubmissions() async {
    final sessions = await getPendingSessions();
    
    for (var session in sessions) {
      try {
        // Attempt to submit to server
        // This will be called from a background service
        // await ExamService.submitExam(...);
        
        // If successful, clear the session
        await clearExamSession(session.id);
      } catch (e) {
        // Keep session for next retry
        print('Failed to submit session ${session.id}: $e');
      }
    }
  }
}
