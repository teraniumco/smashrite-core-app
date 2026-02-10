import 'dart:io' show exit;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/features/exam/data/models/exam_session.dart';
import 'package:smashrite/features/exam/data/models/question.dart';
import 'package:smashrite/features/exam/data/services/exam_service.dart';
import 'package:smashrite/features/exam/data/services/exam_storage_service.dart';
import 'package:smashrite/features/exam/data/services/answer_sync_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smashrite/core/services/network_monitor_service.dart';
import 'package:smashrite/core/services/kiosk_service.dart';

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

final examProvider = StateNotifierProvider<ExamNotifier, ExamSession?>((ref) {
  return ExamNotifier(ref);
});

class ExamNotifier extends StateNotifier<ExamSession?> {
  final Ref ref;
  Timer? _violationCheckTimer;
  String _currentQuestionId = '';
  bool _isAutoSubmitting = false;
  bool _isTerminatingDueToViolation = false;
  int _maxViolationsCount = 10;

  // Continuous violation timers
  Timer? _internetViolationTimer;
  Timer? _screenRecordingViolationTimer;
  Timer? _appSwitchViolationTimer;

  // Track if currently in violation state
  bool _isInInternetViolation = false;
  bool _isInScreenRecordingViolation = false;
  bool _isInAppSwitchViolation = false;

  // ========== BACKGROUND TIME TRACKING ==========
  DateTime? _lastPausedTime;
  Duration _cumulativeBackgroundTime = Duration.zero;
  Timer? _gracePeriodTimer; // Replaces _backgroundTimeTracker
  int _appSwitchCount = 0; // Count of switches, not exits
  Timer? _backgroundAccumulationTimer;

  // Thresholds
  static const _gracePeriodSeconds = 3; // Grace period before termination
  static const _maxCumulativeBackgroundSeconds = 30; // Total allowed background time
  static const _maxSwitchCount = 5; // Max quick switches allowed (even < 3s each)

  // State snapshot before going to background
  bool? _internetStateBeforePause;
  bool? _screenRecordingBeforePause;
  bool _isInGracePeriod = false;

  ExamNotifier(this.ref) : super(null) {
    _startViolationMonitoring();
  }

  /// Start exam - calls backend to start attempt and fetch questions
  Future<void> startExam() async {
    try {
      // 1. Start exam attempt on backend
      debugPrint('📝 Starting exam...');
      final startResponse = await ExamService.startExam();
      debugPrint('✅ Start Exam Response: $startResponse');

      final attemptId = startResponse['attempt_id'];
      final testId = startResponse['test_id'];
      final startedAtStr = startResponse['started_at'];

      if (attemptId == null) {
        throw Exception('No attempt_id returned from server');
      }

      debugPrint('📋 Attempt ID: $attemptId, Test ID: $testId');

      // 2. Fetch questions
      debugPrint('📚 Fetching questions...');
      final questionsData = await ExamService.getQuestions();
      debugPrint(
        '✅ Questions fetched: ${questionsData['questions'].length} questions',
      );

      // 3. Parse questions
      final questions =
          (questionsData['questions'] as List)
              .map((q) => _parseQuestion(q))
              .toList();

      // 4. Parse saved answers if any
      final savedAnswersList = questionsData['saved_answers'];
      final answers = <String, Answer>{};

      if (savedAnswersList != null && savedAnswersList is Map) {
        savedAnswersList.forEach((questionId, answerData) {
          if (answerData != null && answerData is Map) {
            try {
              final selectedOptions = answerData['selected_option_ids'];
              final answerText = answerData['answer_text'];

              answers[questionId.toString()] = Answer(
                questionId: questionId.toString(),
                selectedOptions:
                    selectedOptions != null && selectedOptions is List
                        ? List<String>.from(
                          selectedOptions.map((e) => e.toString()),
                        )
                        : [],
                textAnswer: answerText?.toString(),
                answeredAt: DateTime.now(),
              );
            } catch (e) {
              debugPrint(
                '[!! WARNING !!] Error parsing saved answer for question $questionId: $e',
              );
            }
          }
        });
      }

      // 5. Get flagged questions
      final flaggedQuestions = <String>[];
      if (savedAnswersList != null && savedAnswersList is Map) {
        savedAnswersList.forEach((questionId, answerData) {
          try {
            if (answerData != null &&
                answerData is Map &&
                answerData['is_flagged'] == true) {
              flaggedQuestions.add(questionId.toString());
            }
          } catch (e) {
            debugPrint(
              '[!! WARNING !!] Error parsing flag for question $questionId: $e',
            );
          }
        });
      }

      debugPrint(
        '📊 Parsed ${answers.length} saved answers and ${flaggedQuestions.length} flagged questions',
      );

      // 6. Get test info
      final testInfo = questionsData['test_info'];
      int remainingSeconds = 0;

      if (testInfo != null && testInfo is Map) {
        remainingSeconds = testInfo['remaining_seconds'] ?? 0;
        debugPrint('⏱️ Remaining time: $remainingSeconds seconds');
      } else {
        debugPrint(
          '[!! WARNING !!] No test_info found, using default duration',
        );
      }

      // 7. Create exam session
      DateTime examStartTime;
      try {
        examStartTime =
            startedAtStr != null
                ? DateTime.parse(startedAtStr)
                : DateTime.now();
      } catch (e) {
        debugPrint(
          '[!! WARNING !!] Error parsing startedAt, using current time: $e',
        );
        examStartTime = DateTime.now();
      }

      state = ExamSession(
        id: attemptId.toString(),
        examId: testId?.toString() ?? 'unknown',
        studentId: '',
        title: 'Current Exam',
        duration: Duration(
          seconds: remainingSeconds > 0 ? remainingSeconds : 3600,
        ),
        startedAt: examStartTime,
        questions: questions,
        answers: answers,
        flaggedQuestions: flaggedQuestions,
      );

      // 8. Setup ALL security callbacks (Native + FreeRASP)
      _setupSecurityCallbacks();

      // Set exam attempt for security violation tracking
      await SecurityService.setCurrentExamAttempt(
        int.parse(attemptId.toString()),
      );
      debugPrint('✅ Exam attempt set for security tracking: $attemptId');

      // 9. Initialize network monitoring with server URL
      await NetworkMonitorService.initialize(
        serverUrl: ExamService.dio.options.baseUrl,
      );
      debugPrint('📡 Network monitoring initialized');

      // 10. Start background sync with dynamic interval based on exam duration
      final durationMinutes = (remainingSeconds / 60).ceil();
      AnswerSyncService.startBackgroundSync(
        (status) {
          ref.read(syncStatusProvider.notifier).state = status;
        },
        examDurationMinutes:
            durationMinutes, // Pass exam duration for smart sync interval
      );

      // 11. Enable kiosk mode for the exam
      debugPrint('🔒 Enabling kiosk mode...');
      final kioskEnabled = await KioskService.enableKioskMode();
      if (!kioskEnabled) {
        debugPrint('⚠️ WARNING: Kiosk mode failed to enable');
      }else{
        debugPrint('✅ Kiosk mode enabled successfully');
      }

      debugPrint(
        '✅ Exam started successfully with background sync (${durationMinutes}min exam)',
      );
    } catch (e) {
      debugPrint('❌ Error starting exam: $e');
      rethrow;
    }
  }

  // Setup ALL security callbacks (Native + FreeRASP)
  void _setupSecurityCallbacks() {
    debugPrint('🔒 Setting up comprehensive security callbacks...');

    // ========== NATIVE SECURITY CALLBACKS ==========

    // Screenshot detection - SecurityService handles reporting internally
    SecurityService.onScreenshotDetected = (count, timestamp) {
      debugPrint('📸 Screenshot #$count detected at $timestamp');
      ref.read(violationProvider.notifier).recordViolation('screenshot');

      // Also track in local state for auto-submit count
      if (state != null) {
        final violation = ViolationLog(
          type: 'screenshot',
          timestamp: DateTime.now(),
          details: 'Screenshot attempt #$count detected',
        );
        state = state!.copyWith(violations: [...state!.violations, violation]);

        _checkAutoSubmitThreshold();
      }
    };

    // Screen recording detection - with continuous tracking
    SecurityService.onScreenRecordingChanged = (isRecording) {
      if (isRecording) {
        debugPrint('🎥 Screen recording started!');
        _startScreenRecordingViolationTracking();
        ref
            .read(violationProvider.notifier)
            .recordViolation('screen_recording');
      } else {
        debugPrint('✅ Screen recording stopped');
        _stopScreenRecordingViolationTracking();
        ref.read(violationProvider.notifier).clearScreenRecordingViolation();
      }
    };

    // App switching detection - with continuous tracking
    SecurityService.onAppSwitched = () {
      debugPrint('[!! WARNING !!] App switched - User left exam!');
      _startAppSwitchViolationTracking();
      ref.read(violationProvider.notifier).recordViolation('app_switch');
    };

    // App resumed callback to stop app switch tracking
    SecurityService.onAppResumed = () {
      debugPrint('✅ App resumed');
      _stopAppSwitchViolationTracking();
    };

    // ========== FREERASP SECURITY CALLBACKS ==========
    SecurityService.onSecurityViolation ??= (violation) {
      debugPrint(
        '🚨 FreeRASP violation: ${violation.type} (${violation.severity})',
      );

      final violationType = _mapFreeRASPViolationType(violation.type);
      ref.read(violationProvider.notifier).recordViolation(violationType);

      // Track in local state for auto-submit
      if (state != null) {
        final violationLog = ViolationLog(
          type: violationType,
          timestamp: DateTime.now(),
          details: violation.description,
        );
        state = state!.copyWith(
          violations: [...state!.violations, violationLog],
        );

        _checkAutoSubmitThreshold();
      }

      if (violation.severity == ViolationSeverity.critical) {
        debugPrint('🚨 CRITICAL violation detected - flagging for UI');
        ref.read(criticalSecurityViolationProvider.notifier).state = violation;
      }
    };

    SecurityService.onDeviceBindingViolation ??= () {
      debugPrint('🚨 Device binding violation!');
      ref.read(deviceMismatchProvider.notifier).state = true;

      // Track in local state
      if (state != null) {
        final violation = ViolationLog(
          type: 'device_mismatch',
          timestamp: DateTime.now(),
          details: 'Unauthorized device detected',
        );
        state = state!.copyWith(violations: [...state!.violations, violation]);
      }
    };

    // ========== NETWORK MONITORING CALLBACKS ==========

    NetworkMonitorService.onMobileDataEnabled = () {
      debugPrint('[!! WARNING !!] Mobile data enabled!');
      _startInternetViolationTracking('mobile_data', 'Mobile data enabled');
      ref.read(violationProvider.notifier).recordViolation('internet');
    };

    NetworkMonitorService.onExternalInternetDetected = () {
      debugPrint('[!! WARNING !!] External internet detected on WiFi!');
      _startInternetViolationTracking(
        'external_internet',
        'External internet access detected',
      );
      ref.read(violationProvider.notifier).recordViolation('external_internet');
    };

    NetworkMonitorService.onServerConnectionChanged = (isConnected) {
      debugPrint('📡 Server connection changed: $isConnected');
      ref.read(connectionStatusProvider.notifier).state = ConnectionStatus(
        isConnected: isConnected,
        lastSyncTime: isConnected ? DateTime.now() : null,
      );
    };

    NetworkMonitorService.onServerDisconnected = () {
      debugPrint('[!! WARNING !!] Server disconnected!');
      ref.read(serverDisconnectedProvider.notifier).state = true;
    };

    NetworkMonitorService.onServerReconnected = () {
      debugPrint('✅ Server reconnected!');
      ref.read(serverReconnectedProvider.notifier).state = true;
    };

    // Multi-window detection
    SecurityService.onMultiWindowDetected = () {
      debugPrint('🚨 Multi-window mode detected - CRITICAL VIOLATION');
      
      // Immediately terminate - this is a critical cheat attempt
      _terminateAppDueToViolation(
        'multi_window_detected',
        'Student attempted to use split-screen/multi-window mode during exam. '
        'This is strictly prohibited as it allows viewing other apps simultaneously.',
      );
    };

    debugPrint('✅ All security callbacks configured');
  }

  // ------- Continuous violation tracking methods

  // -------------------------------- >>>>>>>>>>>>>>>>
  /// Handle app going to background - START grace period
  void handleAppPaused() {
    if (state == null || state!.status == ExamStatus.submitted) return;
    
    debugPrint('⏸️ App paused - starting grace period...');
    
    // Increment switch count (not exit count)
    _appSwitchCount++;
    debugPrint('🔄 App switch #$_appSwitchCount');
    
    // Record when app went to background
    _lastPausedTime = DateTime.now();
    _isInGracePeriod = true;
    
    // Capture current state BEFORE going to background
    _captureDeviceStateBeforePause();
    
    // Start accumulating background time
    _startBackgroundAccumulation();
    
    // Start 3-second grace period timer
    _startGracePeriodTimer();
    
    // Check if exceeded max switches (even quick ones)
    if (_appSwitchCount >= _maxSwitchCount) {
      debugPrint('🚨 CRITICAL: Exceeded maximum app switches ($_maxSwitchCount)');
      
      // Cancel grace period
      _gracePeriodTimer?.cancel();
      _isInGracePeriod = false;
      
      _terminateAppDueToViolation(
        'excessive_app_switches',
        'Student exceeded maximum allowed app switches ($_maxSwitchCount switches). '
        'Even quick switches are suspicious behavior.',
      );
    }
  }

  /// Handle app resuming - VERIFY state and check if within grace period
  Future<void> handleAppResumed() async {
    if (state == null || state!.status == ExamStatus.submitted) return;
    
    debugPrint('▶️ App resumed - verifying state...');
    
    // Calculate time spent in background
    Duration? backgroundDuration;
    if (_lastPausedTime != null) {
      backgroundDuration = DateTime.now().difference(_lastPausedTime!);
      _cumulativeBackgroundTime += backgroundDuration;
      
      debugPrint(
        '⏱️ Background duration: ${backgroundDuration.inSeconds}s '
        '(Total cumulative: ${_cumulativeBackgroundTime.inSeconds}s / $_maxCumulativeBackgroundSeconds limit)',
      );
    }
    
    // Stop timers
    _gracePeriodTimer?.cancel();
    _stopBackgroundAccumulation();
    
    final wasInGracePeriod = _isInGracePeriod;
    _isInGracePeriod = false;
    
    // CRITICAL: Check if cumulative background time exceeded
    if (_cumulativeBackgroundTime.inSeconds >= _maxCumulativeBackgroundSeconds) {
      debugPrint('🚨 CRITICAL: Exceeded cumulative background time limit');
      await _terminateAppDueToViolation(
        'cumulative_background_exceeded',
        'Student exceeded maximum cumulative background time ($_maxCumulativeBackgroundSeconds seconds). '
        'Total background time: ${_cumulativeBackgroundTime.inSeconds} seconds across $_appSwitchCount switches.',
      );
      return;
    }
    
    // CRITICAL: Verify device state - detect cheating during switch
    final stateChanged = await _verifyDeviceStateAfterResume();
    if (stateChanged) {
      // State verification already handles termination
      return;
    }
    
    // If returned within grace period - just show warning modal
    if (backgroundDuration != null && backgroundDuration.inSeconds < _gracePeriodSeconds) {
      debugPrint('✅ Returned within grace period (${backgroundDuration.inSeconds}s < ${_gracePeriodSeconds}s)');
      
      // Record violation for tracking, but don't terminate
      recordViolation(
        'app_switch',
        'App switch #$_appSwitchCount - returned within ${backgroundDuration.inSeconds}s '
        '(Total background: ${_cumulativeBackgroundTime.inSeconds}s)',
      );
      
      // Show warning modal via existing violation system
      ref.read(violationProvider.notifier).recordViolation('app_switch');
      
    } else if (backgroundDuration != null) {
      // Stayed away too long - this is already handled by grace period timer
      // But if grace period timer didn't fire (edge case), handle here
      if (wasInGracePeriod) {
        debugPrint('🚨 CRITICAL: Exceeded grace period on resume check');
        await _terminateAppDueToViolation(
          'grace_period_exceeded',
          'Student stayed away from app for ${backgroundDuration.inSeconds} seconds '
          '(limit: $_gracePeriodSeconds seconds)',
        );
      }
    }
    
    _lastPausedTime = null;
  }

  /// Start 3-second grace period timer
  void _startGracePeriodTimer() {
    _gracePeriodTimer?.cancel();
    
    debugPrint('⏱️ Grace period started ($_gracePeriodSeconds seconds)');
    
    _gracePeriodTimer = Timer(Duration(seconds: _gracePeriodSeconds), () {
      if (!_isInGracePeriod) return;
      
      debugPrint('🚨 CRITICAL: Grace period expired - student still in background');
      
      final backgroundDuration = _lastPausedTime != null 
        ? DateTime.now().difference(_lastPausedTime!)
        : Duration.zero;
      
      // Terminate app - stayed away too long
      _terminateAppDueToViolation(
        'app_switch_exceeded_grace_period',
        'Student left app and did not return within $_gracePeriodSeconds seconds. '
        'Background duration: ${backgroundDuration.inSeconds} seconds. '
        'Switch #$_appSwitchCount.',
      );
    });
  }

  /// Start accumulating background time continuously
  void _startBackgroundAccumulation() {
    _backgroundAccumulationTimer?.cancel();
    
    _backgroundAccumulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lastPausedTime == null) {
        timer.cancel();
        return;
      }
      
      final elapsed = DateTime.now().difference(_lastPausedTime!);
      final total = _cumulativeBackgroundTime + elapsed;
      
      // Log every 5 seconds
      if (elapsed.inSeconds % 5 == 0) {
        debugPrint(
          '⏱️ Current background: ${elapsed.inSeconds}s | '
          'Total cumulative: ${total.inSeconds}s / $_maxCumulativeBackgroundSeconds | '
          'Switch #$_appSwitchCount',
        );
      }
    });
  }

  /// Stop accumulating background time
  void _stopBackgroundAccumulation() {
    _backgroundAccumulationTimer?.cancel();
    _backgroundAccumulationTimer = null;
  }

  /// Capture device state before app goes to background
  Future<void> _captureDeviceStateBeforePause() async {
    try {
      _internetStateBeforePause = await ExamService.checkInternetConnection();
      _screenRecordingBeforePause = await SecurityService.isScreenRecording();
      
      debugPrint(
        '📸 State captured before pause:\n'
        '   Internet: $_internetStateBeforePause\n'
        '   Recording: $_screenRecordingBeforePause',
      );
    } catch (e) {
      debugPrint('❌ Failed to capture state before pause: $e');
    }
  }

  /// Verify device state after app resumes - detect cheating during switch
  /// Returns true if state changed suspiciously (and triggers termination)
  Future<bool> _verifyDeviceStateAfterResume() async {
    try {
      final internetNow = await ExamService.checkInternetConnection();
      final recordingNow = await SecurityService.isScreenRecording();
      
      debugPrint(
        '🔍 State verification after resume:\n'
        '   Internet: $_internetStateBeforePause → $internetNow\n'
        '   Recording: $_screenRecordingBeforePause → $recordingNow',
      );
      
      // CRITICAL: Check if internet was enabled while in background
      if (_internetStateBeforePause == false && internetNow == true) {
        debugPrint(
          '🚨 CRITICAL VIOLATION: Internet was enabled while app was in background!\n'
          '   This indicates potential cheating attempt.',
        );
        
        await _terminateAppDueToViolation(
          'internet_enabled_during_switch',
          'Internet connection was enabled while app was in background. '
          'Before: $_internetStateBeforePause, After: $internetNow. '
          'Background duration: ${_lastPausedTime != null ? DateTime.now().difference(_lastPausedTime!).inSeconds : "unknown"}s. '
          'This is a critical security violation indicating potential cheating.',
        );
        return true;
      }
      
      // CRITICAL: Check if screen recording started while in background
      if (_screenRecordingBeforePause == false && recordingNow == true) {
        debugPrint(
          '🚨 CRITICAL VIOLATION: Screen recording started while app was in background!',
        );
        
        await _terminateAppDueToViolation(
          'recording_started_during_switch',
          'Screen recording was started while app was in background. '
          'Before: $_screenRecordingBeforePause, After: $recordingNow. '
          'This is a critical security violation.',
        );
        return true;
      }
      
      // If internet is still on (was on before, still on now), start continuous tracking
      if (internetNow) {
        debugPrint('⚠️ Internet detected on resume (was also on before)');
        if (!_isInInternetViolation) {
          _startInternetViolationTracking(
            'internet_on_resume',
            'Internet connection still active when app resumed',
          );
        }
      }
      
      return false; // No suspicious state changes
      
    } catch (e) {
      debugPrint('❌ State verification failed: $e');
      return false;
    }
  }

  /// Get cumulative background time for display/logging
  Duration getCumulativeBackgroundTime() => _cumulativeBackgroundTime;

  /// Get app switch count
  int getAppSwitchCount() => _appSwitchCount;

  /// Check if currently in grace period
  bool isInGracePeriod() => _isInGracePeriod;
  // -------------------------------- <<<<<<<<<<<

  /// Start tracking internet violation (mobile data or external internet)
  void _startInternetViolationTracking(String type, String description) {
    if (_isInInternetViolation) {
      debugPrint('⏭️ Internet violation tracking already active');
      return;
    }

    _isInInternetViolation = true;

    // Report initial violation
    recordViolation(type, description);

    // Start timer to record violation every 3 seconds
    _internetViolationTimer?.cancel();
    _internetViolationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isInInternetViolation) {
        debugPrint('🔄 Internet violation still active - recording again');
        recordViolation(type, '$description (continuous - +3s)');
      }
    });

    debugPrint('⏱️ Started internet violation tracking');
  }

  /// Stop tracking internet violation
  void _stopInternetViolationTracking() {
    if (!_isInInternetViolation) return;

    _isInInternetViolation = false;
    _internetViolationTimer?.cancel();
    _internetViolationTimer = null;

    debugPrint('✅ Stopped internet violation tracking');
  }

  /// Start tracking screen recording violation
  void _startScreenRecordingViolationTracking() {
    if (_isInScreenRecordingViolation) {
      debugPrint('⏭️ Screen recording violation tracking already active');
      return;
    }

    _isInScreenRecordingViolation = true;

    // Report initial violation (SecurityService already reported via callback)
    // Just track locally and start continuous counting
    if (state != null) {
      final violation = ViolationLog(
        type: 'screen_recording',
        timestamp: DateTime.now(),
        details: 'Screen recording detected',
      );
      state = state!.copyWith(violations: [...state!.violations, violation]);
      _checkAutoSubmitThreshold();
    }

    // Start timer to record violation every 3 seconds
    _screenRecordingViolationTimer?.cancel();
    _screenRecordingViolationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (_isInScreenRecordingViolation) {
          debugPrint('🔄 Screen recording still active - recording again');
          recordViolation(
            'screen_recording',
            'Screen recording active (continuous - +3s)',
          );
        }
      },
    );

    debugPrint('⏱️ Started screen recording violation tracking');
  }

  /// Stop tracking screen recording violation
  void _stopScreenRecordingViolationTracking() {
    if (!_isInScreenRecordingViolation) return;

    _isInScreenRecordingViolation = false;
    _screenRecordingViolationTimer?.cancel();
    _screenRecordingViolationTimer = null;

    debugPrint('✅ Stopped screen recording violation tracking');
  }

  /// Start tracking app switch violation
  void _startAppSwitchViolationTracking() {
    if (_isInAppSwitchViolation) {
      debugPrint('⏭️ App switch violation tracking already active');
      return;
    }

    _isInAppSwitchViolation = true;

    // Report initial violation (SecurityService already reported via callback)
    // Just track locally and start continuous counting
    if (state != null) {
      final violation = ViolationLog(
        type: 'app_switch',
        timestamp: DateTime.now(),
        details: 'User switched to another app',
      );
      state = state!.copyWith(violations: [...state!.violations, violation]);
      _checkAutoSubmitThreshold();
    }

    // Start timer to record violation every 3 seconds
    _appSwitchViolationTimer?.cancel();
    _appSwitchViolationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isInAppSwitchViolation) {
        debugPrint('🔄 App still in background - recording again');
        recordViolation('app_switch', 'App in background (continuous - +3s)');
      }
    });

    debugPrint('⏱️ Started app switch violation tracking');
  }

  /// Stop tracking app switch violation
  void _stopAppSwitchViolationTracking() {
    if (!_isInAppSwitchViolation) return;

    _isInAppSwitchViolation = false;
    _appSwitchViolationTimer?.cancel();
    _appSwitchViolationTimer = null;

    debugPrint('✅ Stopped app switch violation tracking');
  }

  // Map FreeRASP violation types to your violation system
  String _mapFreeRASPViolationType(ViolationType type) {
    switch (type) {
      case ViolationType.rootDetected:
      case ViolationType.jailbreakDetected:
        return 'root_detected';
      case ViolationType.debuggerAttached:
        return 'debugger';
      case ViolationType.emulatorDetected:
        return 'emulator';
      case ViolationType.screenRecording:
        return 'screen_recording';
      case ViolationType.tamperedApp:
        return 'app_tampering';
      case ViolationType.deviceMismatch:
        return 'device_mismatch';
      default:
        return 'security_violation';
    }
  }

  /// Parse question from API response
  Question _parseQuestion(Map<String, dynamic> json) {
    QuestionType type;
    switch (json['question_type']) {
      case 'mcq_single':
        type = QuestionType.singleChoice;
        break;
      case 'mcq_multiple':
        type = QuestionType.multipleChoice;
        break;
      case 'true_false':
        type = QuestionType.trueFalse;
        break;
      case 'fill_in_blank':
      case 'fill_blank':
        type = QuestionType.fillInBlank;
        break;
      default:
        type = QuestionType.singleChoice;
    }

    final options =
        json['options'] != null
            ? (json['options'] as List)
                .map(
                  (o) =>
                      QuestionOption(id: o['id'].toString(), text: o['text']),
                )
                .toList()
            : <QuestionOption>[];

    return Question(
      id: json['id'].toString(),
      text: json['question_text'],
      type: type,
      options: options,
      imageUrl: json['image_url']?.toString(), // ADD THIS LINE
    );
  }
    
  
  /// Save answer - LOCAL FIRST, then synced in background
  Future<void> saveAnswer({
    required String questionId,
    List<String>? selectedOptions,
    String? textAnswer,
  }) async {
    if (state == null) return;

    try {
      final answer = Answer(
        questionId: questionId,
        selectedOptions: selectedOptions ?? [],
        textAnswer: textAnswer,
        answeredAt: DateTime.now(),
      );

      state = state!.copyWith(answers: {...state!.answers, questionId: answer});

      debugPrint('💾 Answer saved locally: Question $questionId');

      await AnswerSyncService.saveAnswerLocally(
        attemptId: state!.id,
        questionId: questionId,
        selectedOptions: selectedOptions,
        textAnswer: textAnswer,
      );
    } catch (e) {
      debugPrint('[!! WARNING !!] Error saving answer locally: $e');
    }
  }

  /// Toggle flag - LOCAL FIRST, then synced in background
  Future<void> toggleFlag(String questionId) async {
    if (state == null) return;

    try {
      final flagged = state!.flaggedQuestions;
      final newFlagged =
          flagged.contains(questionId)
              ? flagged.where((id) => id != questionId).toList()
              : [...flagged, questionId];
      final isFlagged = newFlagged.contains(questionId);

      state = state!.copyWith(flaggedQuestions: newFlagged);

      debugPrint('💾 Flag toggled locally: Question $questionId = $isFlagged');

      await AnswerSyncService.saveFlagLocally(
        questionId: questionId,
        isFlagged: isFlagged,
      );
    } catch (e) {
      debugPrint('[!! WARNING !!] Error toggling flag locally: $e');
    }
  }

  /// Submit exam - force sync all pending data first
  Future<void> submitExam() async {
    if (state == null) return;

    try {
      debugPrint('📤 Submitting exam...');

      // CRITICAL: Stop all monitoring FIRST
      _stopAllMonitoring();


      // Disable kiosk mode
      debugPrint('🔓 Disabling kiosk mode...');
      await KioskService.disableKioskMode();

      // Force sync all pending answers
      ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
      await AnswerSyncService.forceSync((status) {
        ref.read(syncStatusProvider.notifier).state = status;
      });

      DateTime submittedAt;
      // Submit to backend
      try {
        final response = await ExamService.submitExam();
        debugPrint('✅ Exam submitted successfully to backend');
        submittedAt = DateTime.parse(response['submitted_at']);
      } catch (e) {
        debugPrint(
          '[!! WARNING !!] Could not parse submitted_at, using current time',
        );
        submittedAt = DateTime.now();
      }

      state = state!.copyWith(
        status: ExamStatus.submitted,
        submittedAt: submittedAt,
      );

      await AnswerSyncService.clearPendingData();

      debugPrint('✅ Exam submission complete');
    } catch (e) {
      debugPrint('[!! WARNING !!] Submission failed: $e');

      _stopAllMonitoring();

      state = state!.copyWith(
        status: ExamStatus.submitted,
        submittedAt: DateTime.now(),
      );

      rethrow;
    }
  }

  void _startViolationMonitoring() {
    _violationCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkForViolations(),
    );
  }

  // manage internet violation tracking
  Future<void> _checkForViolations() async {
    if (state == null) return;

    final hasInternet = await ExamService.checkInternetConnection();

    if (hasInternet) {
      // Start continuous tracking if not already tracking
      if (!_isInInternetViolation) {
        _startInternetViolationTracking(
          'internet',
          'Internet connection detected',
        );
        ref.read(violationProvider.notifier).recordViolation('internet');
      }
    } else {
      // Stop tracking if was tracking
      if (_isInInternetViolation) {
        _stopInternetViolationTracking();
        ref.read(violationProvider.notifier).clearInternetViolation();
      }
    }
  }


  // Terminate app due to violation
  Future<void> _terminateAppDueToViolation(
    String violationType,
    String violationDetails,
  ) async {
    if (_isTerminatingDueToViolation) {
      debugPrint('⏭️ Already terminating app, ignoring duplicate call');
      return;
    }

    _isTerminatingDueToViolation = true;

    try {
      debugPrint('🚨 CRITICAL: Terminating app due to violation: $violationType');

      // 1. Force sync all pending answers FIRST
      debugPrint('📤 Step 1/5: Force syncing all pending answers...');
      try {
        ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
        await AnswerSyncService.forceSync((status) {
          ref.read(syncStatusProvider.notifier).state = status;
        }).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('[!! WARNING !!] Force sync timed out during termination');
            return false;
          },
        );
        debugPrint('✅ Answers synced successfully');
      } catch (e) {
        debugPrint('[!! WARNING !!] Failed to sync answers: $e');
        // Continue anyway - we still need to terminate
      }

      // 2. Save violation status to storage
      debugPrint('💾 Step 2/5: Saving violation status to storage...');
      try {
        await StorageService.save(
          AppConstants.examViolationStatus,
          true,
        );
        
        // Save detailed violation info for later reference
        await StorageService.save(
          AppConstants.examViolationDetails,
          jsonEncode({
            'violation_type': violationType,
            'details': violationDetails,
            'terminated_at': DateTime.now().toIso8601String(),
            'exam_id': state?.examId,
            'attempt_id': state?.id,
            'total_violations': state?.violations.length ?? 0,
          }),
        );
        debugPrint('✅ Violation status saved');
      } catch (e) {
        debugPrint('❌ Failed to save violation status: $e');
      }

      // 3. Stop all monitoring
      debugPrint('🛑 Step 3/5: Stopping all monitoring...');
      _stopAllMonitoring();


      //---- Disable kiosk mode
      await KioskService.disableKioskMode();

      // 4. Report violation to backend
      debugPrint('📡 Step 4/5: Reporting violation to backend...');
      try {
        final violationTypeEnum = _mapStringToViolationType(violationType);
        final severity = ViolationSeverity.critical; // Always critical for termination
        
        await SecurityService.reportViolation(
          type: violationTypeEnum,
          severity: severity,
          description: '$violationDetails (APP TERMINATED)',
          metadata: {
            'termination_reason': violationType,
            'total_violations': state?.violations.length ?? 0,
            'terminated_at': DateTime.now().toIso8601String(),
          },
          questionIndex: _currentQuestionId,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('[!! WARNING !!] Violation reporting timed out');
          },
        );
        debugPrint('✅ Violation reported to backend');
      } catch (e) {
        debugPrint('[!! WARNING !!] Failed to report violation: $e');
      }

      // 5. Clear all local data and auth
      debugPrint('🗑️ Step 5/5: Clearing auth and logging out...');
      try {
        // Clear auth token
        await StorageService.remove(AppConstants.accessToken);
        await StorageService.remove(AppConstants.refreshToken);

        // Clear exam-related data
        await AnswerSyncService.clearPendingData();

        // Clear all stored data
        await StorageService.remove(AppConstants.accessCodeId);
        await StorageService.remove(AppConstants.accessToken);
        await StorageService.remove(AppConstants.studentData);
        await StorageService.remove(AppConstants.currentExamData);
        await StorageService.remove(AppConstants.examViolationStatus);
        // Clear security session data (but keep device registered)
        await SecurityService.clearExamAttempt();
        
        debugPrint('✅ Auth & Exam data cleared, user logged out');
      } catch (e) {
        debugPrint('❌ Failed to clear auth: $e');
      }

      // 6. Terminate the app
      debugPrint('💥 TERMINATING APP NOW...');
      
      // Small delay to ensure logs are printed
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Force exit the app
      exit(0);
      
    } catch (e) {
      debugPrint('❌ CRITICAL ERROR in termination flow: $e');
      // Still try to exit
      exit(1);
    }
  }

  // Update recordViolation to trigger termination
  void recordViolation(String type, String? details) {
    if (state == null) return;

    if (state!.status == ExamStatus.submitted ||
        state!.status == ExamStatus.autoSubmitted) {
      debugPrint('⏭️ Ignoring violation - exam already submitted');
      return;
    }

    // Ensure SecurityService has latest question index
    SecurityService.setCurrentQuestionId(_currentQuestionId);

    // Create violation log for local state
    final violation = ViolationLog(
      type: type,
      timestamp: DateTime.now(),
      details: details,
    );

    state = state!.copyWith(violations: [...state!.violations, violation]);

    debugPrint(
      '[!! WARNING !!] Violation recorded: $type (Total: ${state!.violations.length})',
    );

    // Check if this is a termination-triggering violation
    if (_shouldTerminateForViolation(type)) {
      debugPrint('🚨 CRITICAL VIOLATION: $type - Initiating app termination...');
      
      // Trigger termination (non-blocking)
      _terminateAppDueToViolation(type, details ?? type);
      
      return; // Don't continue with normal violation processing
    }

    // Normal violation reporting for non-critical violations
    final violationType = _mapStringToViolationType(type);
    final severity = _getViolationSeverity(type);

    SecurityService.reportViolation(
      type: violationType,
      severity: severity,
      description: details ?? type,
      questionIndex: _currentQuestionId,
    );

    _checkAutoSubmitThreshold();
  }


  bool _shouldTerminateForViolation(String type) {
    switch (type) {
      // Critical device security - immediate termination
      case 'root_detected':
      case 'emulator':
      case 'app_tampering':
      case 'device_mismatch':
        return true;
      
      // Screenshot/recording - immediate termination
      case 'screenshot':
      case 'screen_recording':
        return true;
      
      // CRITICAL: Background/state change violations - immediate termination
      case 'app_switch_exceeded_grace_period': // Stayed away > 3 seconds
      case 'cumulative_background_exceeded': // Total background time > 30 seconds
      case 'excessive_app_switches': // Too many switches
      case 'internet_enabled_during_switch': // Turned on internet while away
      case 'recording_started_during_switch': // Started recording while away
      case 'grace_period_exceeded':
        return true;
      
      // Quick app switches - DO NOT terminate, just warn      
      // Accidental app switch violations
      case 'app_switch':
        // Only terminate if they stayed away (grace period timer fired)
        // Quick returns don't count here
        return false; // Termination is handled by grace period timer
      
      // Internet violations - terminate after 2 violations (6 seconds)
      case 'internet':
      case 'mobile_data':
      case 'external_internet':
      case 'internet_on_resume':
        return state!.violations.where((v) => 
          v.type == 'internet' || 
          v.type == 'mobile_data' || 
          v.type == 'external_internet' ||
          v.type == 'internet_on_resume'
        ).length >= 2;
      
      default:
        return false;
    }
  }


  // Separate method to check auto-submit threshold
  void _checkAutoSubmitThreshold() {
    if (state == null || _isAutoSubmitting) return;

    if (state!.violations.length >= _maxViolationsCount) {
      debugPrint('🚨 Max violations reached! Auto-submitting exam...');
      _autoSubmitDueToViolations();
    }
  }

  /// Map string violation types to ViolationType enum
  ViolationType _mapStringToViolationType(String type) {
    switch (type) {
      case 'screenshot':
        return ViolationType.screenshot;
      case 'screen_recording':
        return ViolationType.screenRecording;
      case 'app_switch':
        return ViolationType.appSwitch;
      case 'internet':
        return ViolationType.internetConnection;
      case 'mobile_data':
        return ViolationType.mobileDataEnabled;
      case 'external_internet':
        return ViolationType.externalInternet;
      case 'root_detected':
        return ViolationType.rootDetected;
      case 'debugger':
        return ViolationType.debuggerAttached;
      case 'emulator':
        return ViolationType.emulatorDetected;
      case 'app_tampering':
        return ViolationType.tamperedApp;
      case 'device_mismatch':
        return ViolationType.deviceMismatch;
      default:
        return ViolationType.suspiciousBehavior;
    }
  }

  /// Get severity for violation type
  ViolationSeverity _getViolationSeverity(String type) {
    switch (type) {
      case 'root_detected':
      case 'emulator':
      case 'app_tampering':
      case 'screen_recording':
        return ViolationSeverity.critical;
      case 'screenshot':
      case 'debugger':
      case 'device_mismatch':
        return ViolationSeverity.high;
      case 'app_switch':
      case 'mobile_data':
      case 'external_internet':
      case 'internet':
        return ViolationSeverity.medium;
      default:
        return ViolationSeverity.low;
    }
  }

  Future<void> _autoSubmitDueToViolations() async {
    if (state == null || _isAutoSubmitting) return;

    _isAutoSubmitting = true;

    try {
      debugPrint('🚨 Starting auto-submit due to violations...');

      _stopAllMonitoring();

      state = state!.copyWith(
        status: ExamStatus.autoSubmitted,
        submittedAt: DateTime.now(),
      );

      ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
      await AnswerSyncService.forceSync((status) {
        ref.read(syncStatusProvider.notifier).state = status;
      });

      try {
        await ExamService.submitExam();
        debugPrint('✅ Auto-submit successful');
      } catch (e) {
        debugPrint('[!! WARNING !!] Auto-submit API failed: $e');
      }

      await AnswerSyncService.clearPendingData();

      ref.read(autoSubmitTriggerProvider.notifier).state = DateTime.now();

      debugPrint('✅ Auto-submit complete');
    } catch (e) {
      debugPrint('❌ Auto-submit error: $e');
      _isAutoSubmitting = false;
    } finally {
      _isAutoSubmitting = false;
    }
  }

  // Centralized method to stop all monitoring + clear security callbacks
  Future<void> _stopAllMonitoring() async {
    debugPrint('🛑 Stopping all monitoring services...');

    // Stop periodic violation check
    _violationCheckTimer?.cancel();
    _violationCheckTimer = null;

    // Stop continuous violation timers
    _stopInternetViolationTracking();
    _stopScreenRecordingViolationTracking();
    _stopAppSwitchViolationTracking();
    
    // NEW: Stop grace period and background accumulation timers
    _gracePeriodTimer?.cancel();
    _gracePeriodTimer = null;
    _stopBackgroundAccumulation();

    AnswerSyncService.stopBackgroundSync();
    NetworkMonitorService.dispose();
    SecurityService.disable();

    SecurityService.clearExamAttempt();

    // Clear all security callbacks
    SecurityService.onSecurityViolation = null;
    SecurityService.onDeviceBindingViolation = null;
    SecurityService.onScreenshotDetected = null;
    SecurityService.onScreenRecordingChanged = null;
    SecurityService.onAppSwitched = null;
    SecurityService.onAppResumed = null;

    // Clear question index for SecurityService
    SecurityService.setCurrentQuestionId(null);

    if (KioskService.isEnabled) {
      await KioskService.forceDisable();
    }

    debugPrint('✅ All monitoring stopped and callbacks cleared');
  }

  void setCurrentQuestionId(String questionId) {
    _currentQuestionId = questionId;

    // Sync with SecurityService
    SecurityService.setCurrentQuestionId(questionId);
  }

  @override
  void dispose() {
    _stopAllMonitoring();
    super.dispose();
  }
}

// ========== PROVIDERS ==========

final timeRemainingProvider = StateProvider<Duration?>((ref) => null);

final connectionStatusProvider = StateProvider<ConnectionStatus>((ref) {
  return ConnectionStatus(isConnected: true);
});

class ConnectionStatus {
  final bool isConnected;
  final DateTime? lastSyncTime;

  ConnectionStatus({required this.isConnected, this.lastSyncTime});
}

final violationProvider =
    StateNotifierProvider<ViolationNotifier, ViolationState>((ref) {
      return ViolationNotifier();
    });

class ViolationState {
  final int violationCount;
  final String? lastViolationType;
  final bool showAlert;
  final bool hasInternetViolation;
  final bool hasScreenRecordingViolation;
  final bool isModalShowing;

  ViolationState({
    this.violationCount = 0,
    this.lastViolationType,
    this.showAlert = false,
    this.hasInternetViolation = false,
    this.hasScreenRecordingViolation = false,
    this.isModalShowing = false,
  });

  ViolationState copyWith({
    int? violationCount,
    String? lastViolationType,
    bool? showAlert,
    bool? hasInternetViolation,
    bool? hasScreenRecordingViolation,
    bool? isModalShowing,
  }) {
    return ViolationState(
      violationCount: violationCount ?? this.violationCount,
      lastViolationType: lastViolationType ?? this.lastViolationType,
      showAlert: showAlert ?? this.showAlert,
      hasInternetViolation: hasInternetViolation ?? this.hasInternetViolation,
      hasScreenRecordingViolation:
          hasScreenRecordingViolation ?? this.hasScreenRecordingViolation,
      isModalShowing: isModalShowing ?? this.isModalShowing,
    );
  }
}

class ViolationNotifier extends StateNotifier<ViolationState> {
  DateTime? _lastViolationTime;
  String? _lastViolationType;
  final Map<String, DateTime> _violationDebounce = {};

  ViolationNotifier() : super(ViolationState());

  void recordViolation(String type) {
    final now = DateTime.now();

    if (_violationDebounce.containsKey(type)) {
      final lastTime = _violationDebounce[type]!;
      if (now.difference(lastTime).inSeconds < 5) {
        debugPrint(
          '⏭️ Debouncing $type violation (last: ${now.difference(lastTime).inSeconds}s ago)',
        );
        return;
      }
    }

    if (state.isModalShowing) {
      debugPrint('⏭️ Modal already showing, ignoring $type violation');
      return;
    }

    _violationDebounce[type] = now;
    _lastViolationTime = now;
    _lastViolationType = type;

    state = state.copyWith(
      violationCount: state.violationCount + 1,
      lastViolationType: type,
      showAlert: true,
      isModalShowing: false,
      hasInternetViolation:
          type == 'internet' ||
          type == 'external_internet' ||
          type == 'mobile_data',
      hasScreenRecordingViolation: type == 'screen_recording',
    );

    debugPrint('🚨 Violation recorded: $type (Count: ${state.violationCount})');
  }

  void dismissAlert() {
    state = state.copyWith(showAlert: false, isModalShowing: false);
    debugPrint('✅ Violation alert dismissed');
  }

  void markModalShowing() {
    state = state.copyWith(isModalShowing: true);
  }

  void clearInternetViolation() {
    state = state.copyWith(hasInternetViolation: false);
  }

  void clearScreenRecordingViolation() {
    state = state.copyWith(hasScreenRecordingViolation: false);
  }
}

final autoSubmitTriggerProvider = StateProvider<DateTime?>((ref) => null);
final serverDisconnectedProvider = StateProvider<bool>((ref) => false);
final serverReconnectedProvider = StateProvider<bool>((ref) => false);

// Providers for critical security violations
final criticalSecurityViolationProvider = StateProvider<SecurityViolation?>(
  (ref) => null,
);
final deviceMismatchProvider = StateProvider<bool>((ref) => false);
