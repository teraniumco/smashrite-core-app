import 'package:equatable/equatable.dart';

class Student extends Equatable {
  final int id;
  final String studentId;
  final String fullName;
  final String? department;
  final String? level;

  const Student({
    required this.id,
    required this.studentId,
    required this.fullName,
    this.department,
    this.level,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as int,
      studentId: json['student_id'] as String,
      fullName: json['full_name'] as String,
      department: json['department'] as String?,
      level: json['level'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'full_name': fullName,
      'department': department,
      'level': level,
    };
  }

  @override
  List<Object?> get props => [id, studentId, fullName, department, level];
}