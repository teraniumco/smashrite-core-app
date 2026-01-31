import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:smashrite/features/exam/data/models/question.dart';

part 'exam_session.freezed.dart';
part 'exam_session.g.dart';

@freezed
class ExamSession with _$ExamSession {
  const ExamSession._();

  const factory ExamSession({
    required String id,
    required String examId,
    required String studentId,
    required String title,
    required Duration duration,
    required DateTime startedAt,
    DateTime? submittedAt,
    required List<Question> questions,
    @Default({}) Map<String, Answer> answers,
    @Default([]) List<String> flaggedQuestions,
    @Default([]) List<ViolationLog> violations,
    @Default(ExamStatus.inProgress) ExamStatus status,
  }) = _ExamSession;

  factory ExamSession.fromJson(Map<String, dynamic> json) =>
      _$ExamSessionFromJson(json);

  Duration getRemainingTime() {
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = duration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isTimeUp => getRemainingTime().inSeconds <= 0;

  int get answeredCount => answers.length;

  int get unansweredCount => questions.length - answeredCount;

  double get progressPercentage => 
      (answeredCount / questions.length * 100).clamp(0, 100);
}

enum ExamStatus {
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('submitted')
  submitted,
  @JsonValue('auto_submitted')
  autoSubmitted,
}

@freezed
class ViolationLog with _$ViolationLog {
  const factory ViolationLog({
    required String type,
    required DateTime timestamp,
    String? details,
  }) = _ViolationLog;

  factory ViolationLog.fromJson(Map<String, dynamic> json) =>
      _$ViolationLogFromJson(json);
}
