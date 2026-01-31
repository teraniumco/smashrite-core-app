import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:smashrite/features/auth/data/services/auth_service.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';
import 'package:smashrite/shared/utils/snackbar_helper.dart';

class ExamSubmittedScreen extends StatefulWidget {
  const ExamSubmittedScreen({super.key});

  @override
  State<ExamSubmittedScreen> createState() => _ExamSubmittedScreenState();
}

class _ExamSubmittedScreenState extends State<ExamSubmittedScreen> {
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoggingOut = false;
  final ServerConnectionService _serverService = ServerConnectionService();

  ExamServer? _currentServer;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );

    // Trigger confetti and sound on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
      _playSuccessSound();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSuccessSound() async {
    try {
      // Play a success sound (you'll need to add this asset)
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      // Silently fail if sound doesn't exist
      debugPrint('Could not play success sound: $e');
    }
  }

  // Handle logout
  Future<void> _handleLogout() async {
    // Prevent multiple logout attempts
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      // Get the access token
      final token = StorageService.get<String>(AppConstants.accessToken);

      if (token == null || token.isEmpty) {
        // No token found, just clear local data and navigate
        await _clearLocalDataAndNavigate();
        return;
      }

      // Load server info
      final server = await _serverService.getSavedServer();
      if (mounted) {
        setState(() {
          _currentServer = server;
        });
      }

      // Initialize AuthService with current server
      if (_currentServer != null) {
        AuthService.initialize(_currentServer!.url, authToken: token);
      }

      // Call logout API (ends session, revokes tokens)
      final result = await AuthService.logout();

      if (!mounted) return;

      if (result['success'] == true) {
        // Logout successful - clear local data and navigate
        await _clearLocalDataAndNavigate();
      } else {
        // Logout failed - show error and allow retry
        setState(() {
          _isLoggingOut = false;
        });

        showTopSnackBar(
          context,
          message: result['message'] ?? 'Logout failed. Please try again.',
          backgroundColor: AppColors.error,
        );
      }
    } catch (e) {
      debugPrint('[!! WARNING !!] Logout error: $e');

      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      // Show user-friendly error message
      showTopSnackBar(
        context,
        message:
            'Unable to logout. Please check your connection and try again.',
        backgroundColor: AppColors.error,
      );
    }
  }

  // Clear local storage and navigate to login
  Future<void> _clearLocalDataAndNavigate() async {
    try {
      // Clear all stored data
      await StorageService.remove(AppConstants.accessCodeId);
      await StorageService.remove(AppConstants.accessToken);
      await StorageService.remove(AppConstants.studentData);
      await StorageService.remove(AppConstants.currentExamData);
      // Clear security session data (but keep device registered)
      await SecurityService.clearExamAttempt();

      if (!mounted) return;

      // Navigate to login screen
      context.go('/login');
    } catch (e) {
      debugPrint('[!! WARNING !!] Error clearing local data: $e');

      // Even if clearing fails, try to navigate
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.2,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icons/test-completed.png', width: 140),

                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Exam Submitted!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Message
                    Text(
                      'Your exam has been submitted successfully. You can now logout.',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Success details card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            icon: Icons.access_time,
                            label: 'Submitted at',
                            value: _formatTime(DateTime.now()),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.cloud_done,
                            label: 'Status',
                            value: 'Synced to server',
                            valueColor: Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Logout button with inline loading
                    // SizedBox(
                    //   width: double.infinity,
                    //   child: ElevatedButton(
                    //     onPressed: _isLoggingOut ? null : _handleLogout,
                    //     style: ElevatedButton.styleFrom(
                    //       backgroundColor:
                    //           _isLoggingOut
                    //               ? AppColors.primary.withOpacity(0.6)
                    //               : AppColors.primary,
                    //       foregroundColor: Colors.white,
                    //       padding: const EdgeInsets.symmetric(vertical: 10),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(12),
                    //       ),
                    //       elevation: 0,
                    //       disabledBackgroundColor: AppColors.primary
                    //           .withOpacity(0.6),
                    //       disabledForegroundColor: AppColors.primary,
                    //     ),
                    //     child:
                    //         _isLoggingOut
                    //             ? const SizedBox(
                    //               height: 20,
                    //               width: 20,
                    //               child: CircularProgressIndicator(
                    //                 strokeWidth: 2,
                    //                 valueColor: AlwaysStoppedAnimation<Color>(
                    //                   Colors.white,
                    //                 ),
                    //               ),
                    //             )
                    //             : const Text(
                    //               'Logout',
                    //               style: TextStyle(
                    //                 fontSize: 18,
                    //                 fontWeight: FontWeight.bold,
                    //               ),
                    //             ),
                    //   ),
                    // ),

                    // Navigate to Feedback button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to feedback survey
                          context.push('/feedback-survey');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continue to Logout',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
