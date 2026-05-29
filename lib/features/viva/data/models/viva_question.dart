// lib/features/viva/data/models/viva_question.dart
//
// Viva-specific question models. Separate from the objective Question model
// (features/exam/data/models/question.dart) to avoid polluting the existing
// objective exam with subjective-specific fields.

/// Question types handled by the Viva engine.
enum VivaQuestionType {
  essay,
  calculation,
  diagram,
  compound, // parent question whose children are the real answer units
}

/// A question (or sub-question) in the Viva engine.
class VivaQuestion {
  final int id;

  /// Human-readable label: "1", "1a", "1b(i)", etc.
  final String questionLabel;

  final VivaQuestionType type;
  final String questionText;
  final double marks;

  /// 0 = root, 1 = sub-question, 2 = sub-sub-question
  final int depth;

  /// Whether this question requires a photo (calculation + diagram)
  final bool requiresPhoto;

  /// Whether this question requires a typed final answer (calculation only)
  final bool requiresFinalAnswer;

  /// Whether to show optional working notes input (calculation only)
  final bool showWorkingNotes;

  /// Essay word limits
  final int? minWords;
  final int? maxWords;

  /// Diagram: what must be present in the drawing
  final List<String> diagramChecklist;

  /// Whether a grading rubric is configured on the server
  final bool hasRubric;

  /// Sub-questions for compound type (recursive)
  final List<VivaQuestion> subQuestions;

  const VivaQuestion({
    required this.id,
    required this.questionLabel,
    required this.type,
    required this.questionText,
    required this.marks,
    this.depth = 0,
    this.requiresPhoto = false,
    this.requiresFinalAnswer = false,
    this.showWorkingNotes = true,
    this.minWords,
    this.maxWords,
    this.diagramChecklist = const [],
    this.hasRubric = false,
    this.subQuestions = const [],
  });

  factory VivaQuestion.fromJson(Map<String, dynamic> json) {
    final typeStr = json['question_type'] as String? ?? 'essay';
    final type = _parseType(typeStr);

    return VivaQuestion(
      id: json['id'] as int,
      questionLabel: json['question_label'] as String? ?? '',
      type: type,
      questionText: json['question_text'] as String? ?? '',
      marks: _parseDouble(json['marks']),
      depth: json['depth'] as int? ?? 0,
      requiresPhoto: json['requires_photo'] as bool? ?? false,
      requiresFinalAnswer: json['requires_final_answer'] as bool? ?? false,
      showWorkingNotes: json['show_working_notes'] as bool? ?? true,
      minWords: json['min_words'] as int?,
      maxWords: json['max_words'] as int?,
      diagramChecklist: (json['diagram_checklist'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      hasRubric: json['has_rubric'] as bool? ?? false,
      subQuestions: (json['sub_questions'] as List<dynamic>?)
              ?.map((q) => VivaQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static VivaQuestionType _parseType(String type) {
    return switch (type) {
      'essay'       => VivaQuestionType.essay,
      'calculation' => VivaQuestionType.calculation,
      'diagram'     => VivaQuestionType.diagram,
      'compound'    => VivaQuestionType.compound,
      _             => VivaQuestionType.essay,
    };
  }

  /// Returns leaf sub-questions in display order.
  /// For non-compound types, returns [this].
  List<VivaQuestion> get leafQuestions {
    if (type != VivaQuestionType.compound) return [this];
    return subQuestions.expand((sub) => sub.leafQuestions).toList();
  }

  bool get isRoot => depth == 0;
  bool get isEssay => type == VivaQuestionType.essay;
  bool get isCalculation => type == VivaQuestionType.calculation;
  bool get isDiagram => type == VivaQuestionType.diagram;
  bool get isCompound => type == VivaQuestionType.compound;

  @override
  String toString() => 'VivaQuestion($questionLabel, $type, marks: $marks)';
}

/// A question group within a section — groups questions with optional/required logic.
class VivaQuestionGroup {
  final int id;
  final String title;
  final String instructions;

  /// 'optional' = student selects [requiredCount] from the group
  /// 'required'  = student answers all
  final String mode;

  /// Only meaningful when mode == 'optional'
  final int? requiredCount;
  final int totalCount;
  final List<VivaQuestion> questions;

  const VivaQuestionGroup({
    required this.id,
    required this.title,
    required this.instructions,
    required this.mode,
    this.requiredCount,
    required this.totalCount,
    required this.questions,
  });

  bool get isOptional => mode == 'optional';
  bool get isRequired => mode == 'required';

  factory VivaQuestionGroup.fromJson(Map<String, dynamic> json) {
    return VivaQuestionGroup(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      mode: json['mode'] as String? ?? 'required',
      requiredCount: json['required_count'] as int?,
      totalCount: json['total_count'] as int? ?? 0,
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => VivaQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// A photo capture code returned by the server.
class PhotoCodeData {
  final int photoCodeId;
  final String code;
  final String questionLabel;

  /// "ENG/2023/044 · Q1a · 9H2K" — pre-formatted display string
  final String displayText;

  final DateTime expiresAt;

  /// Countdown to show on screen (seconds)
  final int displaySeconds;

  final int attemptNumber;

  const PhotoCodeData({
    required this.photoCodeId,
    required this.code,
    required this.questionLabel,
    required this.displayText,
    required this.expiresAt,
    required this.displaySeconds,
    required this.attemptNumber,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory PhotoCodeData.fromJson(Map<String, dynamic> json) {
    return PhotoCodeData(
      photoCodeId: json['photo_code_id'] as int,
      code: json['code'] as String,
      questionLabel: json['question_label'] as String,
      displayText: json['display_text'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      displaySeconds: json['display_seconds'] as int? ?? 30,
      attemptNumber: json['attempt_number'] as int? ?? 1,
    );
  }
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}