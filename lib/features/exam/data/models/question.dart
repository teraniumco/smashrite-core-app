import 'package:freezed_annotation/freezed_annotation.dart';

part 'question.freezed.dart';
part 'question.g.dart';

enum QuestionType {
  @JsonValue('single_choice')
  singleChoice,
  @JsonValue('multiple_choice')
  multipleChoice,
  @JsonValue('true_false')
  trueFalse,
  @JsonValue('fill_in_blank')
  fillInBlank,
}

@freezed
class Question with _$Question {
  const factory Question({
    required String id,
    required String text,
    required QuestionType type,
    @Default([]) List<QuestionOption> options,
    String? correctAnswer, // For fill-in-blank questions
    String? imageUrl, // ADD THIS LINE
  }) = _Question;

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);
}

@freezed
class QuestionOption with _$QuestionOption {
  const factory QuestionOption({
    required String id,
    required String text,
  }) = _QuestionOption;

  factory QuestionOption.fromJson(Map<String, dynamic> json) =>
      _$QuestionOptionFromJson(json);
}

@freezed
class Answer with _$Answer {
  const factory Answer({
    required String questionId,
    @Default([]) List<String> selectedOptions, // For MCQ
    String? textAnswer, // For fill-in-blank
    required DateTime answeredAt,
  }) = _Answer;

  factory Answer.fromJson(Map<String, dynamic> json) =>
      _$AnswerFromJson(json);
}