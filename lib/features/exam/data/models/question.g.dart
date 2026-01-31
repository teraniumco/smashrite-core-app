// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$QuestionImpl _$$QuestionImplFromJson(Map<String, dynamic> json) =>
    _$QuestionImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      type: $enumDecode(_$QuestionTypeEnumMap, json['type']),
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      correctAnswer: json['correctAnswer'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );

Map<String, dynamic> _$$QuestionImplToJson(_$QuestionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'type': _$QuestionTypeEnumMap[instance.type]!,
      'options': instance.options,
      'correctAnswer': instance.correctAnswer,
      'imageUrl': instance.imageUrl,
    };

const _$QuestionTypeEnumMap = {
  QuestionType.singleChoice: 'single_choice',
  QuestionType.multipleChoice: 'multiple_choice',
  QuestionType.trueFalse: 'true_false',
  QuestionType.fillInBlank: 'fill_in_blank',
};

_$QuestionOptionImpl _$$QuestionOptionImplFromJson(Map<String, dynamic> json) =>
    _$QuestionOptionImpl(
      id: json['id'] as String,
      text: json['text'] as String,
    );

Map<String, dynamic> _$$QuestionOptionImplToJson(
        _$QuestionOptionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
    };

_$AnswerImpl _$$AnswerImplFromJson(Map<String, dynamic> json) => _$AnswerImpl(
      questionId: json['questionId'] as String,
      selectedOptions: (json['selectedOptions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      textAnswer: json['textAnswer'] as String?,
      answeredAt: DateTime.parse(json['answeredAt'] as String),
    );

Map<String, dynamic> _$$AnswerImplToJson(_$AnswerImpl instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'selectedOptions': instance.selectedOptions,
      'textAnswer': instance.textAnswer,
      'answeredAt': instance.answeredAt.toIso8601String(),
    };
