// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExamSessionImpl _$$ExamSessionImplFromJson(Map<String, dynamic> json) =>
    _$ExamSessionImpl(
      id: json['id'] as String,
      examId: json['examId'] as String,
      studentId: json['studentId'] as String,
      title: json['title'] as String,
      duration: Duration(microseconds: (json['duration'] as num).toInt()),
      startedAt: DateTime.parse(json['startedAt'] as String),
      submittedAt: json['submittedAt'] == null
          ? null
          : DateTime.parse(json['submittedAt'] as String),
      questions: (json['questions'] as List<dynamic>)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList(),
      answers: (json['answers'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, Answer.fromJson(e as Map<String, dynamic>)),
          ) ??
          const {},
      flaggedQuestions: (json['flaggedQuestions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      violations: (json['violations'] as List<dynamic>?)
              ?.map((e) => ViolationLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      status: $enumDecodeNullable(_$ExamStatusEnumMap, json['status']) ??
          ExamStatus.inProgress,
    );

Map<String, dynamic> _$$ExamSessionImplToJson(_$ExamSessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'examId': instance.examId,
      'studentId': instance.studentId,
      'title': instance.title,
      'duration': instance.duration.inMicroseconds,
      'startedAt': instance.startedAt.toIso8601String(),
      'submittedAt': instance.submittedAt?.toIso8601String(),
      'questions': instance.questions,
      'answers': instance.answers,
      'flaggedQuestions': instance.flaggedQuestions,
      'violations': instance.violations,
      'status': _$ExamStatusEnumMap[instance.status]!,
    };

const _$ExamStatusEnumMap = {
  ExamStatus.inProgress: 'in_progress',
  ExamStatus.submitted: 'submitted',
  ExamStatus.autoSubmitted: 'auto_submitted',
};

_$ViolationLogImpl _$$ViolationLogImplFromJson(Map<String, dynamic> json) =>
    _$ViolationLogImpl(
      type: json['type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      details: json['details'] as String?,
    );

Map<String, dynamic> _$$ViolationLogImplToJson(_$ViolationLogImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'timestamp': instance.timestamp.toIso8601String(),
      'details': instance.details,
    };
