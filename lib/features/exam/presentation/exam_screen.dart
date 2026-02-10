import 'package:flutter/material.dart';
import 'dart:io' show exit;
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/services/network_monitor_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/features/exam/data/models/exam_session.dart';
import 'package:smashrite/features/exam/data/models/question.dart';
import 'package:smashrite/features/exam/data/providers/exam_provider.dart';
import 'package:smashrite/features/exam/data/services/answer_sync_service.dart';
import 'package:smashrite/features/exam/widgets/question_widgets.dart';
import 'package:smashrite/features/exam/widgets/question_navigator_modal.dart';
import 'package:smashrite/features/exam/widgets/submit_confirmation_modal.dart';
import 'package:smashrite/features/exam/widgets/sync_status_indicator.dart';
import 'package:smashrite/features/exam/widgets/violation_alert_modal.dart';
import 'package:smashrite/features/exam/widgets/connection_status_badge.dart';
import 'package:smashrite/features/exam/widgets/exam_timer.dart';
import 'package:smashrite/features/security/presentation/widgets/security_status_widget.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';
import 'package:smashrite/core/services/security_globals.dart';
import 'package:smashrite/features/exam/widgets/question_image.dart';
import 'package:smashrite/core/services/kiosk_service.dart';

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSubmitting = false;

  static final ServerConnectionService _serverService =
      ServerConnectionService();
  static ExamServer? _currentServer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeExam();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    SecurityService.handleAppLifecycleChange(state);
    
    // Handle background tracking in provider
    switch (state) {
      case AppLifecycleState.paused:
        // App went to background
        ref.read(examProvider.notifier).handleAppPaused();
        break;
        
      case AppLifecycleState.resumed:
        // App came back to foreground
        ref.read(examProvider.notifier).handleAppResumed();
        break;
        
      default:
        break;
    }
  }

  Future<void> _initializeExam() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final server = await _serverService.getSavedServer();
    if (mounted) {
      setState(() {
        _currentServer = server;
      });
    }

    try {
      final earlyViolation = getLastGlobalSecurityViolation();
      final hasDeviceMismatch = hasDeviceMismatchViolation();
      
      if (earlyViolation != null && earlyViolation.severity == ViolationSeverity.critical) {
        debugPrint('🚨 Found early critical violation: ${earlyViolation.type}');
        
        if (mounted) {
          context.go('/security-violation', extra: earlyViolation);
          return;
        }
      }
      
      if (hasDeviceMismatch) {
        debugPrint('🚨 Found early device mismatch');
        
        if (mounted) {
          context.go('/device-mismatch');
          return;
        }
      }

      // Setup security callbacks BEFORE initializing SecurityService
      _setupSecurityCallbacksEarly();

      // Initialize security (if not already initialized)
      if (!SecurityService.isInitialized) {
        await SecurityService.initialize(server: _currentServer);
        debugPrint('✅ Security initialized');
        
        await SecurityService.performImmediateSecurityCheck();
      }

      // Wait for FreeRASP initial checks
      debugPrint('⏳ Waiting for FreeRASP initial checks...');
      await Future.delayed(const Duration(seconds: 3));
      
      // Check again for violations after delay
      final lateViolation = getLastGlobalSecurityViolation();
      if (lateViolation != null && lateViolation.severity == ViolationSeverity.critical) {
        debugPrint('🚨 Found violation after FreeRASP delay: ${lateViolation.type}');
        
        if (mounted) {
          context.go('/security-violation', extra: lateViolation);
          return;
        }
      }

      // Sync pending answers before starting exam
      final syncSuccessful = await _syncPendingAnswersIfAny();

      if (!syncSuccessful) {
        debugPrint('❌ Exam start aborted - pending answers not synced');
        return;
      }

      // Start exam
      await ref.read(examProvider.notifier).startExam();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Exam initialization failed: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _extractErrorMessage(e);
        });
      }
    }
  }


  // ✅ MODIFY: Update to NOT override global callbacks
  void _setupSecurityCallbacksEarly() {
    debugPrint('🔒 Setting up exam screen security callbacks...');

    // DON'T override - just add additional handling
    // The global callbacks from main.dart will still work
    
    // Just set up providers for UI updates
    final originalSecurityCallback = SecurityService.onSecurityViolation;
    SecurityService.onSecurityViolation = (violation) {
      // Call original callback first
      originalSecurityCallback?.call(violation);
      
      if (!mounted) return;

      debugPrint(
        '🚨 FreeRASP violation in exam screen: ${violation.type} (${violation.severity})',
      );

      // Update provider for navigation
      if (violation.severity == ViolationSeverity.critical) {
        debugPrint('🚨 CRITICAL violation - triggering navigation');
        ref.read(criticalSecurityViolationProvider.notifier).state = violation;
      }
    };

    final originalDeviceCallback = SecurityService.onDeviceBindingViolation;
    SecurityService.onDeviceBindingViolation = () {
      // Call original callback first
      originalDeviceCallback?.call();
      
      if (!mounted) return;

      debugPrint('🚨 Device mismatch in exam screen');
      ref.read(deviceMismatchProvider.notifier).state = true;
    };

    debugPrint('✅ Exam screen callbacks registered (wrapping global callbacks)');
  }


  /// Sync any pending answers before starting exam
  Future<bool> _syncPendingAnswersIfAny() async {
    try {
      final hasPending = await AnswerSyncService.hasPendingAnswers();

      if (!hasPending) {
        debugPrint('✅ No pending answers to sync');
        return true;
      }

      final counts = await AnswerSyncService.getPendingCounts();
      debugPrint(
        '[!! WARNING !!] Found ${counts['answers']} pending answers and ${counts['flags']} pending flags',
      );

      if (mounted) {
        ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
      }

      await AnswerSyncService.syncPendingAnswers(
        (status) {
          if (mounted) {
            ref.read(syncStatusProvider.notifier).state = status;
          }
        },
        timeout: const Duration(seconds: 15),
        maxFailures: 3,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('✅ Pending answers synced successfully');

      final remainingCount = await AnswerSyncService.getPendingCount();
      if (remainingCount > 0) {
        throw Exception(
          'Sync incomplete: $remainingCount ${remainingCount == 1 ? 'item' : 'items'} still pending',
        );
      }

      return true;
    } on TimeoutException catch (e) {
      debugPrint('⏱️ CRITICAL: Sync timed out: $e');

      if (!mounted) return false;

      setState(() => _isLoading = false);

      final shouldContinue = await _showSyncFailureDialog(
        'Sync operation timed out after 15 seconds. '
        'The exam server may be unavailable or your connection is too slow.',
      );

      if (shouldContinue == true) {
        debugPrint('[!! WARNING !!] Student chose to continue despite timeout');
        if (mounted) setState(() => _isLoading = true);
        return true;
      } else if (shouldContinue == false) {
        debugPrint('🔄 Student chose to retry after timeout');
        if (mounted) setState(() => _isLoading = true);
        return await _syncPendingAnswersIfAny();
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('❌ CRITICAL: Failed to sync pending answers: $e');

      if (!mounted) return false;

      setState(() => _isLoading = false);

      final shouldContinue = await _showSyncFailureDialog(e.toString());

      if (shouldContinue == true) {
        debugPrint(
          '[!! WARNING !!] Student chose to continue despite sync failure',
        );
        if (mounted) setState(() => _isLoading = true);
        return true;
      } else if (shouldContinue == false) {
        debugPrint('🔄 Student chose to retry sync');
        if (mounted) setState(() => _isLoading = true);
        return await _syncPendingAnswersIfAny();
      } else {
        return false;
      }
    }
  }

  Future<bool?> _showSyncFailureDialog(String error) async {
    final counts = await AnswerSyncService.getPendingCounts();
    final answersCount = counts['answers'] ?? 0;
    final flagsCount = counts['flags'] ?? 0;
    final totalCount = counts['total'] ?? 0;

    int? syncedCount;
    final syncedMatch = RegExp(
      r'Successfully synced: (\d+)/',
    ).firstMatch(error);
    if (syncedMatch != null) {
      syncedCount = int.tryParse(syncedMatch.group(1) ?? '0');
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Critical: Sync Failed',
                    style: TextStyle(fontSize: 20, color: Colors.red),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have unsaved data from your previous exam session that could not be synced to the exam server.',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (syncedCount != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sync Progress:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Successfully synced: $syncedCount items',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.error,
                                size: 16,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Failed to sync: $totalCount items',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Still Pending:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (answersCount > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$answersCount ${answersCount == 1 ? 'answer' : 'answers'}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        if (flagsCount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.flag,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$flagsCount ${flagsCount == 1 ? 'flag' : 'flags'}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Error Details:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          error,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'What would you like to do?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '[!! WARNING !!] Important Notice:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '• Retry: Recommended. Attempt to sync your data again.\n'
                          '• Continue: Not recommended. Proceed at your own risk. Your previous answers may be lost if the connection issue is not resolved.',
                          style: TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Sync'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary, width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.warning_amber),
                label: const Text('Continue Anyway'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  String _extractErrorMessage(dynamic error) {
    final errorString = error.toString();
    if (errorString.startsWith('Exception: ')) {
      return errorString.substring(11);
    }
    return errorString;
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);

    final examState = ref.read(examProvider);
    if (examState?.status != ExamStatus.submitted &&
        examState?.status != ExamStatus.autoSubmitted) {
      debugPrint(
        '[!! WARNING !!] Exam screen disposed without submission - stopping monitoring',
      );
      NetworkMonitorService.dispose();
      SecurityService.disable();
    }

    super.dispose();
    KioskService.forceDisable().then((_) {
      debugPrint('✅ Kiosk mode disabled on screen disposal');
    });
  }

  void _goToQuestion(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showQuestionNavigator() {
    final examSession = ref.read(examProvider);
    if (examSession == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => QuestionNavigatorModal(
            examSession: examSession,
            currentQuestionIndex: _currentQuestionIndex,
            onQuestionSelected: (index) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              _goToQuestion(index);
            },
          ),
    );
  }

  void _showSubmitConfirmation() {
    final examSession = ref.read(examProvider);
    if (examSession == null) return;
    final connectionStatus = ref.read(connectionStatusProvider);
    if (!connectionStatus.isConnected) {
      _showServerDisconnectedNoSubmissionAlert();
      return;
    }

    // Get current time from the timer provider
    final timeRemaining = ref.read(timeRemainingProvider) ?? Duration.zero;


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder:
          (modalContext) => SubmitConfirmationModal(
            examSession: examSession,
            timeRemaining: timeRemaining,
            onConfirm: () async {
              if (_isSubmitting) return;

              Navigator.of(modalContext).pop();

              if (!mounted) return;

              setState(() {
                _isSubmitting = true;
              });

              showDialog(
                context: context,
                barrierDismissible: false,
                builder:
                    (loadingContext) => WillPopScope(
                      onWillPop: () async => false,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
              );

              try {
                await ref.read(examProvider.notifier).submitExam();
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop();
                context.go('/exam-submitted');
              } catch (e) {
                debugPrint('[!! WARNING !!] Submission error in UI: $e');

                if (!mounted) return;

                Navigator.of(context, rootNavigator: true).pop();

                final shouldExit = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (dialogContext) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 8),
                            Text('Submission Issue'),
                          ],
                        ),
                        content: Text(
                          'There was an issue submitting to the server.\n\n'
                          'Error: ${e.toString()}\n\n'
                          'Your answers are safe. You can exit now.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed:
                                () => Navigator.of(dialogContext).pop(false),
                            child: const Text('Stay'),
                          ),
                          ElevatedButton(
                            onPressed:
                                () => Navigator.of(dialogContext).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: const Text(
                              'Exit Exam',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                );

                if (!mounted) return;

                if (shouldExit == true) {
                  context.go('/exam-submitted');
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isSubmitting = false;
                  });
                }
              }
            },
          ),
    );
  }

  void _handleAutoSubmit() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Exam Auto-Submitted',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Your exam is being automatically submitted due to excessive violations of exam rules.',
                style: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.bold),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    if (mounted) {
                      Navigator.of(context).pop();
                      context.go('/exam-submitted');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Exit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showServerDisconnectedAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your answers are safe.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
      ),
    );

    ref.read(serverDisconnectedProvider.notifier).state = false;
  }

  void _showServerReconnectedAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connection to exam server restored! Syncing answers...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
      ),
    );

    AnswerSyncService.syncPendingAnswers((status) {
      ref.read(syncStatusProvider.notifier).state = status;
    });

    ref.read(serverReconnectedProvider.notifier).state = false;
  }

  void _showServerDisconnectedNoSubmissionAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are not connected to exam server. You can not submit now. Contact Digital Exam Administrator now.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
      ),
    );

    ref.read(serverDisconnectedProvider.notifier).state = false;
  }



  // Check if violation type triggers termination
  bool _shouldShowTerminationWarning(String violationType) {
    switch (violationType) {
      case 'root_detected':
      case 'emulator':
      case 'app_tampering':
      case 'device_mismatch':
      case 'screenshot':
      case 'screen_recording':
        return true;
      default:
        return false;
    }
  }

  // Show termination warning modal
  void _showTerminationWarning(String violationType, String details) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Exam Terminated',
                  style: TextStyle(fontSize: 20, color: Colors.red),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your exam has been terminated due to a critical security violation.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Violation Type:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getViolationDisplayName(violationType),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'The application will now close.',
                style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // App will terminate automatically, this just dismisses the dialog
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getViolationDisplayName(String type) {
    switch (type) {
      case 'root_detected':
        return 'Rooted/Jailbroken Device';
      case 'emulator':
        return 'Emulator Detected';
      case 'app_tampering':
        return 'App Tampering Detected';
      case 'device_mismatch':
        return 'Unauthorized Device';
      case 'screenshot':
        return 'Screenshot Attempt';
      case 'screen_recording':
        return 'Screen Recording Detected';
      case 'app_switch':
        return 'Left Exam Application';
      case 'internet':
      case 'mobile_data':
      case 'external_internet':
        return 'Unauthorized Internet Access';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final syncStatus = ref.watch(syncStatusProvider);

      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _getLoadingMessage(syncStatus),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (syncStatus == SyncStatus.syncing) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Please wait while we sync your previous answers to the exam server...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.warning),
                  const SizedBox(height: 24),
                  Text(
                    'Failed to load exam',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/dashboard'),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Lobby'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _initializeExam,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final examSession = ref.watch(examProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);

    // Listen for app termination due to violations
    // This will show a modal before the app exits
    ref.listen<int>(
      examProvider.select((session) => session?.violations.length ?? 0),
      (previous, next) {
        if (!mounted) return;
        
        final examState = ref.read(examProvider);
        if (examState == null) return;
        
        // Check if we hit a termination violation
        final lastViolation = examState.violations.lastOrNull;
        if (lastViolation == null) return;
        
        final shouldTerminate = _shouldShowTerminationWarning(lastViolation.type);
        
        if (shouldTerminate) {
          _showTerminationWarning(lastViolation.type, lastViolation.details ?? '');
        }
      },
    );

    // ✅ Listen for critical security violations
    ref.listen<SecurityViolation?>(criticalSecurityViolationProvider, (
      previous,
      next,
    ) {
      if (next != null && mounted) {
        // exit(0);
        context.go('/security-violation', extra: next);
      }
    });

    // ✅ Listen for device mismatch
    ref.listen<bool>(deviceMismatchProvider, (previous, next) {
      if (next && mounted) {
        context.go('/device-mismatch');
      }
    });

    // Listen for violations (your existing system)
    ref.listen<ViolationState>(violationProvider, (previous, next) {
      if (!mounted) return;
      if (next.showAlert && !next.isModalShowing) {
        ref.read(violationProvider.notifier).markModalShowing();
        _showViolationAlert(next);
      }
    });

    ref.listen<DateTime?>(autoSubmitTriggerProvider, (previous, next) {
      if (next != null && mounted) {
        _handleAutoSubmit();
      }
    });

    ref.listen<bool>(serverDisconnectedProvider, (previous, next) {
      if (next && mounted && previous != next) {
        _showServerDisconnectedAlert();
      }
    });

    ref.listen<bool>(serverReconnectedProvider, (previous, next) {
      if (next && mounted && previous != next) {
        _showServerReconnectedAlert();
      }
    });

    ref.listen<Duration?>(timeRemainingProvider, (previous, next) {
      if (!mounted) return;

      if (next != null) {
        if (next.inMinutes == 5 && next.inSeconds == 300) {
          _showTimeWarning('5 minutes remaining!');
        } else if (next.inMinutes == 1 && next.inSeconds == 60) {
          _showTimeWarning('1 minute remaining!');
        } else if (next.inSeconds == 0) {
          if (mounted) {
            _handleTimeUp();
          }
        }
      }
    });

    if (examSession == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: WillPopScope(
        onWillPop: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please submit your exam to exit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(examSession, connectionStatus),
          body: Column(
            children: [
              if (!connectionStatus.isConnected) _buildDisconnectionBanner(),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentQuestionIndex = index;
                    });
                    // Sync current question page index with provider
                    // ref.read(examProvider.notifier).setCurrentQuestionIndex(index);

                    // Also set current question id in provider and SecurityService
                    final questionId = examSession.questions[index].id;
                    ref.read(examProvider.notifier).setCurrentQuestionId(questionId);
                  },
                  itemCount: examSession.questions.length,
                  itemBuilder: (context, index) {
                    return _buildQuestionPage(
                      examSession.questions[index],
                      index,
                      examSession.questions.length,
                    );
                  },
                ),
              ),

              const SyncStatusIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  String _getLoadingMessage(SyncStatus syncStatus) {
    switch (syncStatus) {
      case SyncStatus.syncing:
        return 'Syncing Previous Answers...';
      case SyncStatus.synced:
        return 'Preparing Exam...';
      case SyncStatus.error:
        return 'Sync Failed';
      default:
        return 'Loading Exam...';
    }
  }

  // Added SecurityStatusWidget to app bar
  PreferredSizeWidget _buildAppBar(
    ExamSession examSession,
    ConnectionStatus connectionStatus,
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.grid_view, color: Colors.black87),
        onPressed: _showQuestionNavigator,
      ),
      titleSpacing: 0,
      title: LayoutBuilder(
        builder: (context, constraints) {
          // Determine if we're on a small screen
          final isSmallScreen = constraints.maxWidth < 300;
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [

              // Security status - icon only on small screens
              SecurityStatusWidget(compact: isSmallScreen),
              const SizedBox(width: 6),

              // Connection status - icon only on small screens
              ConnectionStatusBadge(
                isConnected: connectionStatus.isConnected,
                compact: isSmallScreen,
              ),
              const SizedBox(width: 6),
              
              // Timer - always flexible
              Flexible(
                child: ExamTimer(
                  duration: examSession.duration,
                  onTimeUpdate: (remaining) {
                    ref.read(timeRemainingProvider.notifier).state = remaining;
                  },
                  compact: isSmallScreen,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton(
            onPressed: _showSubmitConfirmation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Submit',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisconnectionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Connection to exam server lost! Contact your Digital Exam Administrator now.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(Question question, int index, int total) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.swipe_left, size: 20, color: Colors.grey),
                SizedBox(width: 6),
                Text(
                  'Swipe to navigate',
                  style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                ),
                SizedBox(width: 6),
                Icon(Icons.swipe_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Questions ${index + 1} of $total',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Question text
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          
          // IMAGE DISPLAY - ADD THIS SECTION
          if (question.imageUrl != null) ...[
            const SizedBox(height: 16),
            QuestionImage(
              imageUrl: question.imageUrl!,
              questionId: question.id,
            ),
          ],
          
          const SizedBox(height: 24),

          _buildQuestionWidget(question),

          const SizedBox(height: 24),

          _buildFlagButton(question.id),
        ],
      ),
    );
  }

  Widget _buildQuestionWidget(Question question) {
    switch (question.type) {
      case QuestionType.singleChoice:
        return SingleChoiceQuestion(question: question);
      case QuestionType.multipleChoice:
        return MultipleChoiceQuestion(question: question);
      case QuestionType.trueFalse:
        return TrueFalseQuestion(question: question);
      case QuestionType.fillInBlank:
        return FillInBlankQuestion(question: question);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFlagButton(String questionId) {
    final isFlagged = ref.watch(
      examProvider.select(
        (session) => session?.flaggedQuestions.contains(questionId) ?? false,
      ),
    );

    return OutlinedButton.icon(
      onPressed: () {
        ref.read(examProvider.notifier).toggleFlag(questionId);
      },
      icon: Icon(
        isFlagged ? Icons.flag : Icons.flag_outlined,
        color: isFlagged ? Colors.orange : Colors.grey,
      ),
      label: Text(
        'Flag',
        style: TextStyle(color: isFlagged ? Colors.orange : Colors.grey),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isFlagged ? Colors.orange : Colors.grey.shade300,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  void _showViolationAlert(ViolationState state) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => ViolationAlertModal(
            violationType: state.lastViolationType ?? 'unknown',
            violationCount: state.violationCount,
            onDismiss: () {
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
              if (mounted) {
                ref.read(violationProvider.notifier).dismissAlert();
              }
            },
          ),
    ).then((_) {
      if (mounted) {
        ref.read(violationProvider.notifier).dismissAlert();
      }
    });
  }

  void _showTimeWarning(String message) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(Icons.access_time, color: Colors.white),
          const SizedBox(width: 12),
          Text(message),
        ],
      ),
      backgroundColor: Colors.orange.shade700,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  bool _timeUpHandled = false;
  void _handleTimeUp() {
    if (!mounted || _isSubmitting || _timeUpHandled) return;

    _timeUpHandled = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.timer_off, color: Colors.red),
                SizedBox(width: 8),
                Text('Time Up!'),
              ],
            ),
            content: const Text(
              'Your exam time has expired. Your exam will be submitted automatically.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  if (_isSubmitting || !mounted) return;

                  setState(() {
                    _isSubmitting = true;
                  });

                  Navigator.of(dialogContext).pop();

                  if (!mounted) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (loadingContext) => WillPopScope(
                          onWillPop: () async => false,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                  );

                  try {
                    await ref.read(examProvider.notifier).submitExam();
                    if (!mounted) return;
                    Navigator.of(context, rootNavigator: true).pop();
                    context.go('/exam-submitted');
                  } catch (e) {
                    debugPrint('❌ Auto-submit failed: $e');

                    if (!mounted) return;

                    Navigator.of(context, rootNavigator: true).pop();

                    if (mounted) {
                      context.go('/exam-submitted');
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isSubmitting = false;
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
