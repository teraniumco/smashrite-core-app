// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exam_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ExamSession _$ExamSessionFromJson(Map<String, dynamic> json) {
  return _ExamSession.fromJson(json);
}

/// @nodoc
mixin _$ExamSession {
  String get id => throw _privateConstructorUsedError;
  String get examId => throw _privateConstructorUsedError;
  String get studentId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  Duration get duration => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  DateTime? get submittedAt => throw _privateConstructorUsedError;
  List<Question> get questions => throw _privateConstructorUsedError;
  Map<String, Answer> get answers => throw _privateConstructorUsedError;
  List<String> get flaggedQuestions => throw _privateConstructorUsedError;
  List<ViolationLog> get violations => throw _privateConstructorUsedError;
  ExamStatus get status => throw _privateConstructorUsedError;

  /// Serializes this ExamSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExamSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExamSessionCopyWith<ExamSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExamSessionCopyWith<$Res> {
  factory $ExamSessionCopyWith(
          ExamSession value, $Res Function(ExamSession) then) =
      _$ExamSessionCopyWithImpl<$Res, ExamSession>;
  @useResult
  $Res call(
      {String id,
      String examId,
      String studentId,
      String title,
      Duration duration,
      DateTime startedAt,
      DateTime? submittedAt,
      List<Question> questions,
      Map<String, Answer> answers,
      List<String> flaggedQuestions,
      List<ViolationLog> violations,
      ExamStatus status});
}

/// @nodoc
class _$ExamSessionCopyWithImpl<$Res, $Val extends ExamSession>
    implements $ExamSessionCopyWith<$Res> {
  _$ExamSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExamSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? examId = null,
    Object? studentId = null,
    Object? title = null,
    Object? duration = null,
    Object? startedAt = null,
    Object? submittedAt = freezed,
    Object? questions = null,
    Object? answers = null,
    Object? flaggedQuestions = null,
    Object? violations = null,
    Object? status = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      examId: null == examId
          ? _value.examId
          : examId // ignore: cast_nullable_to_non_nullable
              as String,
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      submittedAt: freezed == submittedAt
          ? _value.submittedAt
          : submittedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      questions: null == questions
          ? _value.questions
          : questions // ignore: cast_nullable_to_non_nullable
              as List<Question>,
      answers: null == answers
          ? _value.answers
          : answers // ignore: cast_nullable_to_non_nullable
              as Map<String, Answer>,
      flaggedQuestions: null == flaggedQuestions
          ? _value.flaggedQuestions
          : flaggedQuestions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      violations: null == violations
          ? _value.violations
          : violations // ignore: cast_nullable_to_non_nullable
              as List<ViolationLog>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ExamStatus,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExamSessionImplCopyWith<$Res>
    implements $ExamSessionCopyWith<$Res> {
  factory _$$ExamSessionImplCopyWith(
          _$ExamSessionImpl value, $Res Function(_$ExamSessionImpl) then) =
      __$$ExamSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String examId,
      String studentId,
      String title,
      Duration duration,
      DateTime startedAt,
      DateTime? submittedAt,
      List<Question> questions,
      Map<String, Answer> answers,
      List<String> flaggedQuestions,
      List<ViolationLog> violations,
      ExamStatus status});
}

/// @nodoc
class __$$ExamSessionImplCopyWithImpl<$Res>
    extends _$ExamSessionCopyWithImpl<$Res, _$ExamSessionImpl>
    implements _$$ExamSessionImplCopyWith<$Res> {
  __$$ExamSessionImplCopyWithImpl(
      _$ExamSessionImpl _value, $Res Function(_$ExamSessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of ExamSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? examId = null,
    Object? studentId = null,
    Object? title = null,
    Object? duration = null,
    Object? startedAt = null,
    Object? submittedAt = freezed,
    Object? questions = null,
    Object? answers = null,
    Object? flaggedQuestions = null,
    Object? violations = null,
    Object? status = null,
  }) {
    return _then(_$ExamSessionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      examId: null == examId
          ? _value.examId
          : examId // ignore: cast_nullable_to_non_nullable
              as String,
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      submittedAt: freezed == submittedAt
          ? _value.submittedAt
          : submittedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      questions: null == questions
          ? _value._questions
          : questions // ignore: cast_nullable_to_non_nullable
              as List<Question>,
      answers: null == answers
          ? _value._answers
          : answers // ignore: cast_nullable_to_non_nullable
              as Map<String, Answer>,
      flaggedQuestions: null == flaggedQuestions
          ? _value._flaggedQuestions
          : flaggedQuestions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      violations: null == violations
          ? _value._violations
          : violations // ignore: cast_nullable_to_non_nullable
              as List<ViolationLog>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ExamStatus,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ExamSessionImpl extends _ExamSession {
  const _$ExamSessionImpl(
      {required this.id,
      required this.examId,
      required this.studentId,
      required this.title,
      required this.duration,
      required this.startedAt,
      this.submittedAt,
      required final List<Question> questions,
      final Map<String, Answer> answers = const {},
      final List<String> flaggedQuestions = const [],
      final List<ViolationLog> violations = const [],
      this.status = ExamStatus.inProgress})
      : _questions = questions,
        _answers = answers,
        _flaggedQuestions = flaggedQuestions,
        _violations = violations,
        super._();

  factory _$ExamSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExamSessionImplFromJson(json);

  @override
  final String id;
  @override
  final String examId;
  @override
  final String studentId;
  @override
  final String title;
  @override
  final Duration duration;
  @override
  final DateTime startedAt;
  @override
  final DateTime? submittedAt;
  final List<Question> _questions;
  @override
  List<Question> get questions {
    if (_questions is EqualUnmodifiableListView) return _questions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_questions);
  }

  final Map<String, Answer> _answers;
  @override
  @JsonKey()
  Map<String, Answer> get answers {
    if (_answers is EqualUnmodifiableMapView) return _answers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_answers);
  }

  final List<String> _flaggedQuestions;
  @override
  @JsonKey()
  List<String> get flaggedQuestions {
    if (_flaggedQuestions is EqualUnmodifiableListView)
      return _flaggedQuestions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_flaggedQuestions);
  }

  final List<ViolationLog> _violations;
  @override
  @JsonKey()
  List<ViolationLog> get violations {
    if (_violations is EqualUnmodifiableListView) return _violations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_violations);
  }

  @override
  @JsonKey()
  final ExamStatus status;

  @override
  String toString() {
    return 'ExamSession(id: $id, examId: $examId, studentId: $studentId, title: $title, duration: $duration, startedAt: $startedAt, submittedAt: $submittedAt, questions: $questions, answers: $answers, flaggedQuestions: $flaggedQuestions, violations: $violations, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExamSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.examId, examId) || other.examId == examId) &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            const DeepCollectionEquality()
                .equals(other._questions, _questions) &&
            const DeepCollectionEquality().equals(other._answers, _answers) &&
            const DeepCollectionEquality()
                .equals(other._flaggedQuestions, _flaggedQuestions) &&
            const DeepCollectionEquality()
                .equals(other._violations, _violations) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      examId,
      studentId,
      title,
      duration,
      startedAt,
      submittedAt,
      const DeepCollectionEquality().hash(_questions),
      const DeepCollectionEquality().hash(_answers),
      const DeepCollectionEquality().hash(_flaggedQuestions),
      const DeepCollectionEquality().hash(_violations),
      status);

  /// Create a copy of ExamSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExamSessionImplCopyWith<_$ExamSessionImpl> get copyWith =>
      __$$ExamSessionImplCopyWithImpl<_$ExamSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExamSessionImplToJson(
      this,
    );
  }
}

abstract class _ExamSession extends ExamSession {
  const factory _ExamSession(
      {required final String id,
      required final String examId,
      required final String studentId,
      required final String title,
      required final Duration duration,
      required final DateTime startedAt,
      final DateTime? submittedAt,
      required final List<Question> questions,
      final Map<String, Answer> answers,
      final List<String> flaggedQuestions,
      final List<ViolationLog> violations,
      final ExamStatus status}) = _$ExamSessionImpl;
  const _ExamSession._() : super._();

  factory _ExamSession.fromJson(Map<String, dynamic> json) =
      _$ExamSessionImpl.fromJson;

  @override
  String get id;
  @override
  String get examId;
  @override
  String get studentId;
  @override
  String get title;
  @override
  Duration get duration;
  @override
  DateTime get startedAt;
  @override
  DateTime? get submittedAt;
  @override
  List<Question> get questions;
  @override
  Map<String, Answer> get answers;
  @override
  List<String> get flaggedQuestions;
  @override
  List<ViolationLog> get violations;
  @override
  ExamStatus get status;

  /// Create a copy of ExamSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExamSessionImplCopyWith<_$ExamSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ViolationLog _$ViolationLogFromJson(Map<String, dynamic> json) {
  return _ViolationLog.fromJson(json);
}

/// @nodoc
mixin _$ViolationLog {
  String get type => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  String? get details => throw _privateConstructorUsedError;

  /// Serializes this ViolationLog to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ViolationLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ViolationLogCopyWith<ViolationLog> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ViolationLogCopyWith<$Res> {
  factory $ViolationLogCopyWith(
          ViolationLog value, $Res Function(ViolationLog) then) =
      _$ViolationLogCopyWithImpl<$Res, ViolationLog>;
  @useResult
  $Res call({String type, DateTime timestamp, String? details});
}

/// @nodoc
class _$ViolationLogCopyWithImpl<$Res, $Val extends ViolationLog>
    implements $ViolationLogCopyWith<$Res> {
  _$ViolationLogCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ViolationLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? timestamp = null,
    Object? details = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      details: freezed == details
          ? _value.details
          : details // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ViolationLogImplCopyWith<$Res>
    implements $ViolationLogCopyWith<$Res> {
  factory _$$ViolationLogImplCopyWith(
          _$ViolationLogImpl value, $Res Function(_$ViolationLogImpl) then) =
      __$$ViolationLogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, DateTime timestamp, String? details});
}

/// @nodoc
class __$$ViolationLogImplCopyWithImpl<$Res>
    extends _$ViolationLogCopyWithImpl<$Res, _$ViolationLogImpl>
    implements _$$ViolationLogImplCopyWith<$Res> {
  __$$ViolationLogImplCopyWithImpl(
      _$ViolationLogImpl _value, $Res Function(_$ViolationLogImpl) _then)
      : super(_value, _then);

  /// Create a copy of ViolationLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? timestamp = null,
    Object? details = freezed,
  }) {
    return _then(_$ViolationLogImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      details: freezed == details
          ? _value.details
          : details // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ViolationLogImpl implements _ViolationLog {
  const _$ViolationLogImpl(
      {required this.type, required this.timestamp, this.details});

  factory _$ViolationLogImpl.fromJson(Map<String, dynamic> json) =>
      _$$ViolationLogImplFromJson(json);

  @override
  final String type;
  @override
  final DateTime timestamp;
  @override
  final String? details;

  @override
  String toString() {
    return 'ViolationLog(type: $type, timestamp: $timestamp, details: $details)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ViolationLogImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.details, details) || other.details == details));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, timestamp, details);

  /// Create a copy of ViolationLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ViolationLogImplCopyWith<_$ViolationLogImpl> get copyWith =>
      __$$ViolationLogImplCopyWithImpl<_$ViolationLogImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ViolationLogImplToJson(
      this,
    );
  }
}

abstract class _ViolationLog implements ViolationLog {
  const factory _ViolationLog(
      {required final String type,
      required final DateTime timestamp,
      final String? details}) = _$ViolationLogImpl;

  factory _ViolationLog.fromJson(Map<String, dynamic> json) =
      _$ViolationLogImpl.fromJson;

  @override
  String get type;
  @override
  DateTime get timestamp;
  @override
  String? get details;

  /// Create a copy of ViolationLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ViolationLogImplCopyWith<_$ViolationLogImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
