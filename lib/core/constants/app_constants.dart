class AppConstants {
  // Storage Keys
  static const String isFirstLaunch = 'is_first_launch';
  static const String accessToken = 'access_token';
  static const String accessCodeId = 'access_code_id';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String examServerId = 'exam_server_id';
  static const String hasConnectedToServer = 'has_connected_to_server';
  static const String apiKey = 'api_key';
  static const String examViolationStatus = 'exam_violation_status';
  static const String examViolationDetails = 'exam_violation_details';

  // Student Info
  static const String studentId = 'student_id';
  static const String studentName = 'student_name';
  static const String studentData = 'student_data';
  static const String currentExamData = 'current_exam_data';
  
  // App Info
  static const String appName = 'Smashrite';
  static const String appVersion = '1.0.0';
  
  // Animation Durations
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration fadeInDuration = Duration(milliseconds: 1200);
  
  // Pagination
  static const int itemsPerPage = 20;
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
