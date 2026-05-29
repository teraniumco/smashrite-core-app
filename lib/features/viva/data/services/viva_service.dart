// lib/features/viva/data/services/viva_service.dart
//
// All Viva API calls. Reuses ExamService.dio — same SSL context,
// same base URL, same auth token. No separate initialization needed.

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:smashrite/features/exam/data/services/exam_service.dart';
import 'package:smashrite/features/viva/data/models/viva_question.dart';
import 'package:smashrite/features/viva/data/models/viva_section.dart';

class VivaService {
  // Reuse ExamService Dio instance — already SSL-pinned and authenticated
  static Dio get _dio => ExamService.dio;

  // ── Section discovery ─────────────────────────────────────────────────────

  /// GET /exam/viva/sections
  /// Returns all sections for the active test.
  static Future<Map<String, dynamic>> getSections() async {
    try {
      final response = await _dio.get('/exam/viva/sections');
      return _unwrap(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Session init / resume ─────────────────────────────────────────────────

  /// POST /exam/viva/init
  /// Initialise or resume a Viva session for a section.
  static Future<VivaInitData> initSection(int sectionId) async {
    try {
      final response = await _dio.post(
        '/exam/viva/init',
        data: {'section_id': sectionId},
      );
      return VivaInitData.fromJson(_unwrap(response));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── State (crash recovery) ────────────────────────────────────────────────

  /// GET /exam/viva/state
  static Future<Map<String, dynamic>> getState(int sectionId) async {
    try {
      final response = await _dio.get(
        '/exam/viva/state',
        queryParameters: {'section_id': sectionId},
      );
      return _unwrap(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Question selection ────────────────────────────────────────────────────

  /// POST /exam/viva/questions/select
  /// Lock optional group selection.
  static Future<void> lockSelection({
    required int sectionId,
    required int groupId,
    required List<int> questionIds,
  }) async {
    try {
      final response = await _dio.post(
        '/exam/viva/questions/select',
        data: {
          'section_id': sectionId,
          'group_id': groupId,
          'question_ids': questionIds,
        },
      );
      _assertSuccess(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Answer saving ─────────────────────────────────────────────────────────

  /// POST /exam/viva/answer/text
  /// Save essay text or working notes.
  static Future<Map<String, dynamic>> saveTextAnswer({
    required int sectionId,
    required int questionId,
    required String text,
    bool isWorkingNotes = false,
  }) async {
    try {
      final response = await _dio.post(
        '/exam/viva/answer/text',
        data: {
          'section_id': sectionId,
          'question_id': questionId,
          'text': text,
          'is_working_notes': isWorkingNotes,
        },
      );
      return _unwrap(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST /exam/viva/answer/final
  /// Save final answer for a calculation question.
  static Future<void> saveFinalAnswer({
    required int sectionId,
    required int questionId,
    required String finalAnswer,
  }) async {
    try {
      final response = await _dio.post(
        '/exam/viva/answer/final',
        data: {
          'section_id': sectionId,
          'question_id': questionId,
          'final_answer': finalAnswer,
        },
      );
      _assertSuccess(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Photo codes ───────────────────────────────────────────────────────────

  /// POST /exam/viva/photo-code/generate
  static Future<PhotoCodeData> generatePhotoCode({
    required int sectionId,
    required int questionId,
  }) async {
    try {
      final response = await _dio.post(
        '/exam/viva/photo-code/generate',
        data: {
          'section_id': sectionId,
          'question_id': questionId,
        },
      );
      return PhotoCodeData.fromJson(_unwrap(response));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST /exam/viva/photo-code/regenerate
  static Future<PhotoCodeData> regeneratePhotoCode({
    required int sectionId,
    required int questionId,
    String voidReason = 'student_aborted',
  }) async {
    try {
      final response = await _dio.post(
        '/exam/viva/photo-code/regenerate',
        data: {
          'section_id': sectionId,
          'question_id': questionId,
          'void_reason': voidReason,
        },
      );
      return PhotoCodeData.fromJson(_unwrap(response));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Photo upload ──────────────────────────────────────────────────────────

  /// POST /exam/viva/photo/upload (multipart)
  /// Upload a captured photo. Bytes are passed directly from the camera —
  /// never from the gallery.
  static Future<Map<String, dynamic>> uploadPhoto({
    required int sectionId,
    required int questionId,
    required int photoCodeId,
    required Uint8List photoBytes,
  }) async {
    try {
      final formData = FormData.fromMap({
        'section_id': sectionId,
        'question_id': questionId,
        'photo_code_id': photoCodeId,
        'photo': MultipartFile.fromBytes(
          photoBytes,
          filename: 'q${questionId}_capture.jpg',
          contentType: DioMediaType.parse('image/jpeg'),
        ),
      });

      final response = await _dio.post(
        '/exam/viva/photo/upload',
        data: formData,
        options: Options(
          // Allow more time for photo upload over LAN
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      return _unwrap(response);
    } on DioException catch (e) {
      if (e.error.toString().contains('HandshakeException')) {
        throw Exception(
          'SSL error during photo upload. Check server certificate.',
        );
      }
      throw _handleError(e);
    }
  }

  // ── Engine state sync ─────────────────────────────────────────────────────

  /// POST /exam/viva/session/advance
  /// Called on every engine step transition to keep server in sync.
  static Future<void> advanceStep({
    required int sectionId,
    required String step,
    int? currentQuestionId,
    int? currentSubQuestionId,
    List<int>? questionsOrder,
    List<int>? questionsAnswered,
    List<int>? questionsRemaining,
    Map<String, dynamic>? logEntry,
  }) async {
    try {
      final data = <String, dynamic>{
        'section_id': sectionId,
        'step': step,
        if (currentQuestionId != null) 'current_question_id': currentQuestionId,
        if (currentSubQuestionId != null)
          'current_sub_question_id': currentSubQuestionId,
        if (questionsOrder != null) 'questions_order': questionsOrder,
        if (questionsAnswered != null) 'questions_answered': questionsAnswered,
        if (questionsRemaining != null)
          'questions_remaining': questionsRemaining,
        if (logEntry != null) 'log_entry': logEntry,
      };

      await _dio.post('/exam/viva/session/advance', data: data);
      // Fire and forget — don't block the engine on step sync
    } on DioException catch (e) {
      // Non-fatal: log but don't throw
      debugPrint('[VivaService] advanceStep failed (non-fatal): ${e.message}');
    }
  }

  // ── Section submission ────────────────────────────────────────────────────

  /// POST /exam/viva/submit
  static Future<Map<String, dynamic>> submitSection(int sectionId) async {
    try {
      final response = await _dio.post(
        '/exam/viva/submit',
        data: {'section_id': sectionId},
      );
      return _unwrap(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static Map<String, dynamic> _unwrap(Response response) {
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        response.data['success'] == true) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception(
      response.data['message'] ?? 'Unexpected server response',
    );
  }

  static void _assertSuccess(Response response) {
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(
        response.data['message'] ?? 'Request failed',
      );
    }
  }

  static Exception _handleError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        Exception('Connection timeout. Check your exam network.'),
      DioExceptionType.badResponse =>
        Exception(e.response?.data['message'] ?? 'Request failed'),
      DioExceptionType.connectionError =>
        Exception('Cannot reach exam server. Check LAN connection.'),
      _ => Exception('An error occurred: ${e.message}'),
    };
  }
}
