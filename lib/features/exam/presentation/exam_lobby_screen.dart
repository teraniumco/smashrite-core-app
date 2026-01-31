import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/network/network_service.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/exam/data/models/exam.dart';
import 'package:smashrite/features/exam/data/models/student.dart';
import 'package:smashrite/features/exam/data/services/exam_service.dart';
import 'package:smashrite/features/auth/data/services/auth_service.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';
import 'package:smashrite/features/auth/presentation/widgets/server_info_modal.dart';
import 'package:smashrite/features/exam/presentation/widgets/student_info_modal.dart';
import 'package:smashrite/shared/utils/snackbar_helper.dart';

class ExamLobbyScreen extends StatefulWidget {
  const ExamLobbyScreen({super.key});

  @override
  State<ExamLobbyScreen> createState() => _ExamLobbyScreenState();
}

class _ExamLobbyScreenState extends State<ExamLobbyScreen> {
  final ServerConnectionService _serverService = ServerConnectionService();

  ExamServer? _currentServer;
  Student? _student;
  Exam? _exam;
  bool _agreedToPolicies = false;
  bool _isLoading = true;

  // Network validation states
  bool _isCheckingNetwork = true;
  String? _networkError;

  @override
  void initState() {
    super.initState();
    _loadData();
    _validateNetwork();
  }

  Future<void> _validateNetwork() async {
    setState(() {
      _isCheckingNetwork = true;
      _networkError = null;
    });

    final error = await NetworkService.validateNetworkForExam();

    if (mounted) {
      setState(() {
        _isCheckingNetwork = false;
        _networkError = error;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load server info
      final server = await _serverService.getSavedServer();

      // Load student data
      final studentJson = StorageService.get<String>(AppConstants.studentData);
      Student? student;
      if (studentJson != null) {
        student = Student.fromJson(jsonDecode(studentJson));
      }

      // Load exam data
      final examJson = StorageService.get<String>(AppConstants.currentExamData);
      Exam? exam;
      if (examJson != null) {
        exam = Exam.fromJson(jsonDecode(examJson));
      }

      if (mounted) {
        setState(() {
          _currentServer = server;
          _student = student;
          _exam = exam;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showServerInfo() {
    if (_currentServer == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => ServerInfoModal(
            server: _currentServer!,
            onDisconnect: _handleDisconnect,
          ),
    );
  }

  // NEW: Show student info modal
  void _showStudentInfo() {
    if (_student == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              StudentInfoModal(student: _student!, onLogout: _handleLogout),
    );
  }

  // Handle logout
  Future<void> _handleLogout() async {
    Navigator.pop(context); // Close modal

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text(
              'Are you sure you want to logout? You will need to login again to access the exam.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Call logout API (ends session, revokes tokens)
        final token =
            StorageService.get<String>(AppConstants.accessToken) ?? '';
        AuthService.initialize(_currentServer!.url, authToken: token);
        final result = await AuthService.logout();
        if (result['success'] == true) {
        } else {
          // Close loading dialog
          if (mounted) Navigator.pop(context);

          showTopSnackBar(
            context,
            message: result['message'] ?? 'Logout failed. Please try again.',
            backgroundColor: AppColors.error,
          );
          return;
        }
      } catch (e) {
        debugPrint('[!! WARNING !!] Logout error: $e');
        // Continue with local cleanup even if API fails
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Clear all stored data
      await StorageService.remove(AppConstants.accessCodeId);
      await StorageService.remove(AppConstants.accessToken);
      await StorageService.remove(AppConstants.studentData);
      await StorageService.remove(AppConstants.currentExamData);

      if (!mounted) return;
      context.go('/login');
    }
  }

  Future<void> _handleDisconnect() async {
    Navigator.pop(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Disconnect from Server?'),
            content: const Text(
              'You will be logged out and need to reconnect. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Disconnect'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _serverService.clearServerDetails();
      await StorageService.remove(AppConstants.accessCodeId);
      await StorageService.remove(AppConstants.accessToken);
      await StorageService.remove(AppConstants.studentData);
      await StorageService.remove(AppConstants.currentExamData);

      if (!mounted) return;
      context.go('/server-connection');
    }
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Network Error'),
            content: Text(
              _networkError ?? 'Network validation failed',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _validateNetwork();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
    );
  }

  void _startExam() {
    // Check network first
    if (_isCheckingNetwork) {
      showTopSnackBar(
        context,
        message: 'Please wait while we validate the network...',
        backgroundColor: AppColors.info,
      );
      return;
    }

    if (_networkError != null) {
      _showNetworkErrorDialog();
      return;
    }

    if (!_agreedToPolicies) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please agree to the exam policies to continue'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final token = StorageService.get<String>(AppConstants.accessToken) ?? '';

    ExamService.initialize(_currentServer!.url, authToken: token);

    context.go('/exam');
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_exam == null || _student == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Failed to load exam data'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      );
    }

    final canStartExam =
        !_isCheckingNetwork && _networkError == null && _agreedToPolicies;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student ID and Server Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // UPDATED: Make student name tappable
                        InkWell(
                          onTap: _showStudentInfo,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.warning.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.account_circle_outlined,
                                  size: 18,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _firstName(_student!.fullName),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Server Status
                        if (_currentServer != null)
                          InkWell(
                            onTap: _showServerInfo,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.dns,
                                    color: AppColors.success,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _currentServer!.name,
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Exam Title
                    Text(
                      _exam!.title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Network Status Banner
                    if (_isCheckingNetwork)
                      _buildStatusBanner(
                        icon: Icons.wifi_find,
                        text: 'Checking network...',
                        color: AppColors.info,
                      )
                    else if (_networkError != null)
                      _buildStatusBanner(
                        icon: Icons.warning_rounded,
                        text: _networkError!,
                        color: AppColors.error,
                        action: TextButton(
                          onPressed: _validateNetwork,
                          child: const Text('Retry'),
                        ),
                      )
                    else
                      _buildStatusBanner(
                        icon: Icons.check_circle_rounded,
                        text: 'No Internet and device is ready!',
                        color: AppColors.success,
                      ),

                    const SizedBox(height: 24),

                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.access_time_rounded,
                            value: _exam!.durationMinutes.toString(),
                            label: 'Minutes',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.help_outline_rounded,
                            value: _exam!.totalQuestions.toString(),
                            label: 'Questions',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.check_circle_outline_rounded,
                            value: _exam!.totalMarks.toString(),
                            label: 'Marks',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Exam Description
                    Text(
                      'This exam consists of ${_exam!.totalQuestions} questions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Instructions Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InstructionItem(
                            text:
                                'You have ${_exam!.durationMinutes} minutes to complete the exam.',
                          ),
                          const SizedBox(height: 12),
                          const _InstructionItem(
                            text:
                                'You can flag questions to review them later.',
                          ),
                          const SizedBox(height: 12),
                          const _InstructionItem(
                            text:
                                'Ensure your device has sufficient battery life.',
                          ),
                          const SizedBox(height: 12),
                          const _InstructionItem(
                            text:
                                'Do not close the application during the exam.',
                          ),
                          const SizedBox(height: 12),
                          const _InstructionItem(
                            text:
                                'Answers are saved automatically to the server.',
                          ),
                          const SizedBox(height: 12),
                          const _InstructionItem(
                            text:
                                'Academic integrity is monitored. Do not violate the honor code.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Policy Agreement
                    InkWell(
                      onTap:
                          () => setState(
                            () => _agreedToPolicies = !_agreedToPolicies,
                          ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreedToPolicies,
                              onChanged: (value) {
                                setState(
                                  () => _agreedToPolicies = value ?? false,
                                );
                              },
                              activeColor: const Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'I agree to the exam policies and honor code. I understand that my screen activity may be monitored.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canStartExam ? _startExam : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        disabledBackgroundColor: AppColors.textSecondary
                            .withOpacity(0.3),
                      ),
                      child: Text(
                        'Start Exam',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              canStartExam
                                  ? Colors.white
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner({
    required IconData icon,
    required String text,
    required Color color,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionItem extends StatelessWidget {
  final String text;

  const _InstructionItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: AppColors.textPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
