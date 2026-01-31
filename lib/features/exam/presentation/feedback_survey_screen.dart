import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // Add to pubspec.yaml
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/auth/data/services/auth_service.dart';
import 'package:smashrite/features/exam/data/services/feedback_service.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';
import 'package:smashrite/shared/utils/snackbar_helper.dart';

class FeedbackSurveyScreen extends StatefulWidget {
  const FeedbackSurveyScreen({super.key});

  @override
  State<FeedbackSurveyScreen> createState() => _FeedbackSurveyScreenState();
}

class _FeedbackSurveyScreenState extends State<FeedbackSurveyScreen> {
  final ServerConnectionService _serverService = ServerConnectionService();
  final FeedbackService _feedbackService = FeedbackService();

  ExamServer? _currentServer;
  bool _isSubmitting = false;
  bool _isLoggingOut = false;

  // Survey responses
  double _starRating = 0;
  String _comfortLevel =
      ''; // 'very_comfortable', 'comfortable', 'neutral', 'uncomfortable', 'very_uncomfortable'
  String _preferOverDesktop = ''; // 'yes', 'no', 'maybe'
  String _devicePerformance = ''; // 'yes', 'no'
  final TextEditingController _additionalCommentsController =
      TextEditingController();

  @override
  void dispose() {
    _additionalCommentsController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _starRating > 0 &&
        _comfortLevel.isNotEmpty &&
        _preferOverDesktop.isNotEmpty &&
        _devicePerformance.isNotEmpty;
  }

  Future<void> _submitFeedback() async {
    if (!_canSubmit || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Prepare feedback data
      final feedbackData = {
        'star_rating': _starRating.toInt(),
        'comfort_level': _comfortLevel,
        'prefer_over_desktop': _preferOverDesktop,
        'device_performance': _devicePerformance,
        'additional_comments': _additionalCommentsController.text.trim(),
        'submitted_at': DateTime.now().toIso8601String(),
      };

      // Submit feedback (will handle offline storage automatically)
      await _feedbackService.submitFeedback(feedbackData);

      if (!mounted) return;

      // Show success message
      showTopSnackBar(
        context,
        message: 'Thank you for your feedback!',
        backgroundColor: Colors.green,
      );

      // Wait a moment for user to see the message
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // Proceed to logout
      await _handleLogout();
    } catch (e) {
      debugPrint('[!! WARNING !!] Error submitting feedback: $e');

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      showTopSnackBar(
        context,
        message: 'Feedback saved locally. You can logout now.',
        backgroundColor: Colors.orange,
      );

      // Even if submission fails, allow logout
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        await _handleLogout();
      }
    }
  }

  Future<void> _skipAndLogout() async {
    // User chose to skip feedback - just logout
    await _handleLogout();
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      final token = StorageService.get<String>(AppConstants.accessToken);

      if (token == null || token.isEmpty) {
        await _clearLocalDataAndNavigate();
        return;
      }

      final server = await _serverService.getSavedServer();
      if (mounted) {
        setState(() {
          _currentServer = server;
        });
      }

      if (_currentServer != null) {
        AuthService.initialize(_currentServer!.url, authToken: token);
      }

      final result = await AuthService.logout();

      if (!mounted) return;

      if (result['success'] == true) {
        await _clearLocalDataAndNavigate();
      } else {
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

      showTopSnackBar(
        context,
        message:
            'Unable to logout. Please check your connection and try again.',
        backgroundColor: AppColors.error,
      );
    }
  }

  Future<void> _clearLocalDataAndNavigate() async {
    try {
      await StorageService.remove(AppConstants.accessCodeId);
      await StorageService.remove(AppConstants.accessToken);
      await StorageService.remove(AppConstants.studentData);
      await StorageService.remove(AppConstants.currentExamData);
      await SecurityService.clearExamAttempt();

      if (!mounted) return;

      context.go('/login');
    } catch (e) {
      debugPrint('[!! WARNING !!] Error clearing local data: $e');
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Help Us Improve',
          style: TextStyle(
            fontSize: 25,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Survey content (scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Intro text
                    Text(
                      'Your feedback helps us improve the exam experience for everyone.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Question 1: Star Rating
                    _buildQuestionTitle(
                      '1. How would you rate your overall experience?',
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: RatingBar.builder(
                        initialRating: _starRating,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: false,
                        itemCount: 5,
                        itemSize: 45,
                        itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                        itemBuilder:
                            (context, _) =>
                                const Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) {
                          setState(() {
                            _starRating = rating;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Question 2: Comfort level
                    _buildQuestionTitle(
                      '2. How comfortable were you taking the exam on your phone/tablet?',
                    ),
                    const SizedBox(height: 12),
                    _buildChoiceButtons(
                      selectedValue: _comfortLevel,
                      options: [
                        {
                          'value': 'very_comfortable',
                          'label': 'Very Comfortable',
                        },
                        {'value': 'comfortable', 'label': 'Comfortable'},
                        {'value': 'neutral', 'label': 'Neutral'},
                        {'value': 'uncomfortable', 'label': 'Uncomfortable'},
                        {
                          'value': 'very_uncomfortable',
                          'label': 'Very Uncomfortable',
                        },
                      ],
                      onSelect: (value) {
                        setState(() {
                          _comfortLevel = value;
                        });
                      },
                    ),
                    const SizedBox(height: 32),

                    // Question 3: Prefer over desktop
                    _buildQuestionTitle(
                      '3. Would you prefer this over desktop/laptop CBT?',
                    ),
                    const SizedBox(height: 12),
                    _buildChoiceButtons(
                      selectedValue: _preferOverDesktop,
                      options: [
                        {'value': 'yes', 'label': 'Yes'},
                        {'value': 'maybe', 'label': 'Maybe'},
                        {'value': 'no', 'label': 'No'},
                      ],
                      onSelect: (value) {
                        setState(() {
                          _preferOverDesktop = value;
                        });
                      },
                    ),
                    const SizedBox(height: 32),

                    // Question 4: Device performance
                    _buildQuestionTitle(
                      '4. Did your device perform well throughout?',
                    ),
                    const SizedBox(height: 12),
                    _buildChoiceButtons(
                      selectedValue: _devicePerformance,
                      options: [
                        {'value': 'yes', 'label': 'Yes'},
                        {'value': 'no', 'label': 'No'},
                      ],
                      onSelect: (value) {
                        setState(() {
                          _devicePerformance = value;
                        });
                      },
                    ),
                    const SizedBox(height: 32),

                    // Additional comments (optional)
                    _buildQuestionTitle(
                      '5. Any additional comments? (Optional)',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _additionalCommentsController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Share any other thoughts...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom action buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
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
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          (_canSubmit && !_isSubmitting && !_isLoggingOut)
                              ? _submitFeedback
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child:
                          _isSubmitting || _isLoggingOut
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                              : const Text(
                                'Submit & Logout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Skip BUTTON
                  // SizedBox(
                  //   width: double.infinity,
                  //   child: TextButton(
                  //     onPressed:
                  //         (_isSubmitting || _isLoggingOut)
                  //             ? null
                  //             : _skipAndLogout,
                  //     style: TextButton.styleFrom(
                  //       padding: const EdgeInsets.symmetric(vertical: 16),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //     ),
                  //     child: Text(
                  //       'Skip & Logout',
                  //       style: TextStyle(
                  //         fontSize: 16,
                  //         color: AppColors.textSecondary,
                  //         fontWeight: FontWeight.w600,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        height: 1.4,
      ),
    );
  }

  Widget _buildChoiceButtons({
    required String selectedValue,
    required List<Map<String, String>> options,
    required Function(String) onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          options.map((option) {
            final isSelected = selectedValue == option['value'];
            return InkWell(
              onTap: () => onSelect(option['value']!),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  option['label']!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
