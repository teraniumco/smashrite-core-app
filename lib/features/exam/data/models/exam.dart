import 'package:equatable/equatable.dart';

class Exam extends Equatable {
  final int id;
  final String title;
  final String? description;
  final String? instructions;
  final int durationMinutes;
  final double totalMarks;
  final int totalQuestions;
  final bool shuffleQuestions;
  final bool shuffleOptions;

  const Exam({
    required this.id,
    required this.title,
    this.description,
    this.instructions,
    required this.durationMinutes,
    required this.totalMarks,
    required this.totalQuestions,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      instructions: json['instructions'] as String?,
      durationMinutes: json['duration_minutes'] as int,
      totalMarks: double.parse(json['total_marks'].toString()),
      totalQuestions: json['total_questions'] as int,
      shuffleQuestions: json['shuffle_questions'] as bool? ?? false,
      shuffleOptions: json['shuffle_options'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'instructions': instructions,
      'duration_minutes': durationMinutes,
      'total_marks': totalMarks.toStringAsFixed(2),
      'total_questions': totalQuestions,
      'shuffle_questions': shuffleQuestions,
      'shuffle_options': shuffleOptions,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        instructions,
        durationMinutes,
        totalMarks,
        totalQuestions,
        shuffleQuestions,
        shuffleOptions,
      ];
}