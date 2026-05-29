// lib/features/viva/data/models/viva_section.dart

import 'package:smashrite/features/viva/data/models/viva_question.dart';

/// A test section (objective or subjective).
/// Returned by GET /exam/viva/sections.
class VivaSection {
  final int id;
  final String title;

  /// 'objective' or 'subjective'
  final String type;

  /// 'cbt' or 'viva'
  final String engine;

  final String? instructions;
  final bool isDefault;
  final int? timeLimitMinutes;

  const VivaSection({
    required this.id,
    required this.title,
    required this.type,
    required this.engine,
    this.instructions,
    this.isDefault = false,
    this.timeLimitMinutes,
  });

  bool get isSubjective => type == 'subjective';
  bool get isObjective  => type == 'objective';
  bool get isVivaSection => engine == 'viva';

  factory VivaSection.fromJson(Map<String, dynamic> json) {
    return VivaSection(
      id: json['id'] as int,
      title: json['title'] as String,
      type: json['type'] as String,
      engine: json['engine'] as String? ?? 'cbt',
      instructions: json['instructions'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      timeLimitMinutes: json['time_limit_minutes'] as int?,
    );
  }
}

/// Complete response from POST /exam/viva/init
/// Contains everything the ExaminerEngine needs to start or resume.
class VivaInitData {
  final bool isResuming;
  final VivaSection section;
  final List<VivaQuestionGroup> questionGroups;

  /// Questions not in any group
  final List<VivaQuestion> standaloneQuestions;

  final VivaServerState vivaState;
  final List<Map<String, dynamic>> conversationLog;
  final int remainingSeconds;

  const VivaInitData({
    required this.isResuming,
    required this.section,
    required this.questionGroups,
    required this.standaloneQuestions,
    required this.vivaState,
    required this.conversationLog,
    required this.remainingSeconds,
  });

  /// All root questions in correct order (groups first, then standalone)
  List<VivaQuestion> get allRootQuestions {
    final fromGroups = questionGroups.expand((g) => g.questions).toList();
    return [...fromGroups, ...standaloneQuestions];
  }

  factory VivaInitData.fromJson(Map<String, dynamic> json) {
    return VivaInitData(
      isResuming: json['is_resuming'] as bool? ?? false,
      section: VivaSection.fromJson(json['section'] as Map<String, dynamic>),
      questionGroups: (json['question_groups'] as List<dynamic>?)
              ?.map((g) => VivaQuestionGroup.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      standaloneQuestions:
          (json['standalone_questions'] as List<dynamic>?)
              ?.map((q) => VivaQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
      vivaState: VivaServerState.fromJson(
        json['viva_state'] as Map<String, dynamic>,
      ),
      conversationLog:
          (json['conversation_log'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      remainingSeconds: json['remaining_seconds'] as int? ?? 0,
    );
  }
}

/// Current engine step as stored on the server — used for session resume.
class VivaServerState {
  final int id;
  final String currentStep;
  final int? currentQuestionId;
  final int? currentSubQuestionId;
  final List<int> questionsOrder;
  final List<int> questionsAnswered;
  final List<int> questionsRemaining;
  final List<String> dropsEmitted;
  final double percentageComplete;
  final DateTime lastUpdated;

  const VivaServerState({
    required this.id,
    required this.currentStep,
    this.currentQuestionId,
    this.currentSubQuestionId,
    required this.questionsOrder,
    required this.questionsAnswered,
    required this.questionsRemaining,
    required this.dropsEmitted,
    required this.percentageComplete,
    required this.lastUpdated,
  });

  factory VivaServerState.fromJson(Map<String, dynamic> json) {
    return VivaServerState(
      id: json['id'] as int,
      currentStep: json['current_step'] as String? ?? 'grounding',
      currentQuestionId: json['current_question_id'] as int?,
      currentSubQuestionId: json['current_sub_question_id'] as int?,
      questionsOrder: (json['questions_order'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      questionsAnswered: (json['questions_answered'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      questionsRemaining: (json['questions_remaining'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      dropsEmitted: (json['drops_emitted'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      percentageComplete:
          (json['percentage_complete'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: DateTime.parse(
        json['last_updated'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
