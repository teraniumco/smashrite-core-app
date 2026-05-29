// VivaNotifier owns the ExaminerEngine and bridges it to the Flutter UI.
//
// Responsibilities:
//  - Load section from API (initSection)
//  - Translate ExaminerMessages → ChatMessages (chat history)
//  - Handle API calls the engine requests (photo codes, answer saves, step sync)
//  - Handle photo upload (receives Uint8List from camera, uploads, confirms to engine)
//  - Handle session resume after crash
//
// Follows the same StateNotifier<T?> pattern as ExamNotifier.

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smashrite/features/viva/data/models/viva_chat_message.dart';
import 'package:smashrite/features/viva/data/models/viva_engine_state.dart';
import 'package:smashrite/features/viva/data/models/viva_question.dart';
import 'package:smashrite/features/viva/data/models/viva_section.dart';
import 'package:smashrite/features/viva/data/services/viva_service.dart';
import 'package:smashrite/features/viva/engine/examiner_engine.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final vivaProvider =
    StateNotifierProvider<VivaNotifier, VivaEngineState?>((ref) {
  return VivaNotifier(ref);
});

/// Available sections for the active test — populated when exam starts.
final vivaSectionsProvider = StateProvider<List<VivaSection>>((ref) => []);

/// Whether the Viva section is currently active (student is on theory tab).
final vivaActiveProvider = StateProvider<bool>((ref) => false);

// ══════════════════════════════════════════════════════════════════════════════
// VIVA NOTIFIER
// ══════════════════════════════════════════════════════════════════════════════

class VivaNotifier extends StateNotifier<VivaEngineState?> {
  final Ref ref;
  final ExaminerEngine _engine;

  // The active section ID — needed for all API calls
  int? _sectionId;

  VivaNotifier(this.ref)
      : _engine = ExaminerEngine(),
        super(null);

  // ── Section discovery ─────────────────────────────────────────────────────

  /// Fetch sections for the active test.
  /// Called once after the exam starts to populate the section switcher.
  Future<void> loadSections() async {
    try {
      final data = await VivaService.getSections();
      final sections = (data['sections'] as List<dynamic>?)
              ?.map((s) => VivaSection.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];

      ref.read(vivaSectionsProvider.notifier).state = sections;
      debugPrint('[VivaNotifier] ${sections.length} sections loaded');
    } catch (e) {
      debugPrint('[VivaNotifier] loadSections failed: $e');
    }
  }

  // ── Section init / resume ─────────────────────────────────────────────────

  /// Called when student switches to the Viva (theory) section tab.
  Future<void> initSection(int sectionId) async {
    _sectionId = sectionId;

    state = (state ?? _emptyState()).copyWith(isLoading: true);

    try {
      final data = await VivaService.initSection(sectionId);

      if (data.isResuming) {
        await _resumeSession(data);
      } else {
        _startFreshSession(data);
      }

      ref.read(vivaActiveProvider.notifier).state = true;

      debugPrint('[VivaNotifier] Section $sectionId initialised '
          '(resuming: ${data.isResuming})');
    } catch (e) {
      debugPrint('[VivaNotifier] initSection failed: $e');
      state = (state ?? _emptyState()).copyWith(
        isLoading: false,
        errorMessage: () => e.toString(),
      );
    }
  }


  /// Toggle a question's selection for optional groups.
  /// Called from the scan overview bubble checkboxes.
  void toggleQuestionSelection(int questionId) {
    if (state == null) return;
    final current = Set<int>.from(state!.selectedQuestionIds);
    if (current.contains(questionId)) {
      current.remove(questionId);
    } else {
      current.add(questionId);
    }
    state = state!.copyWith(selectedQuestionIds: current);
  }

  void _startFreshSession(VivaInitData data) {
    final messages = _engine.init(data);
    final chatMessages = _translateAll(messages);

    state = VivaEngineState(
      section: data.section,
      questionGroups: data.questionGroups,
      standaloneQuestions: data.standaloneQuestions,
      currentStep: _engine.currentStep,
      currentQuestion: _engine.currentQuestion,
      questionsOrder: _engine.questionsOrder,
      questionsAnswered: _engine.questionsAnswered,
      questionsRemaining: _engine.questionsRemaining,
      dropsEmitted: _engine.dropsEmitted,
      chatHistory: chatMessages,
      inputMode: _engine.currentInputMode,
      isLoading: false,
    );

    // Sync grounding step to server (fire and forget)
    _syncStep();
  }

  Future<void> _resumeSession(VivaInitData data) async {
    // If conversation_log is empty, the session was created but no messages
    // were exchanged before the crash. Treat it as a fresh start so the
    // student sees the grounding + scan overview properly.
    if (data.conversationLog.isEmpty) {
      _startFreshSession(data);
      return;
    }

    _engine.resume(data, data.vivaState);

    final chatHistory = _rebuildChatHistory(data.conversationLog);

    state = VivaEngineState(
      section: data.section,
      questionGroups: data.questionGroups,
      standaloneQuestions: data.standaloneQuestions,
      currentStep: _engine.currentStep,
      currentQuestion: _engine.currentQuestion,
      currentSubQuestion: _engine.currentSubQuestion,
      questionsOrder: _engine.questionsOrder,
      questionsAnswered: _engine.questionsAnswered,
      questionsRemaining: _engine.questionsRemaining,
      dropsEmitted: _engine.dropsEmitted,
      chatHistory: [
        ...chatHistory,
        _vivaMessage(
          "Welcome back. You were on ${_engine.currentSubQuestion?.questionLabel ?? _engine.currentQuestion?.questionLabel ?? 'your question'}. Let's continue.",
          VivaMessageVariant.grounding,
        ),
      ],
      inputMode: _engine.currentInputMode,
      isLoading: false,
    );
  }

  // ── Student action entry point ─────────────────────────────────────────────
  Future<void> onAction(StudentAction action) async {
    if (state == null) return;

    _appendStudentBubbleIfNeeded(action);

    final messages = _engine.processAction(action);

    for (final message in messages) {
      await _handleEngineMessage(message);
    }

    _updateStateFromEngine();

    // When student confirms submission, flush any in-flight saves then
    // call the submission endpoint. This was never wired up before.
    if (action is SubmitConfirmed) {
      await Future.delayed(const Duration(milliseconds: 600)); // let saves land
      await submitSection();
    }
  }

  // ── Photo capture ─────────────────────────────────────────────────────────

  /// Called by the camera widget after a successful capture.
  /// Handles upload before confirming to the engine.
  Future<void> onPhotoCaptured(Uint8List bytes) async {
    if (state == null || _sectionId == null) return;

    final photoCode = _engine.activePhotoCode;
    if (photoCode == null) {
      debugPrint('[VivaNotifier] onPhotoCaptured: no active photo code');
      return;
    }

    final leaf = _engine.currentSubQuestion ?? _engine.currentQuestion;
    if (leaf == null) return;

    state = state!.copyWith(isUploading: true);

    try {
      await VivaService.uploadPhoto(
        sectionId: _sectionId!,
        questionId: leaf.id,
        photoCodeId: photoCode.photoCodeId,
        photoBytes: bytes,
      );

      debugPrint('[VivaNotifier] Photo uploaded for Q${leaf.questionLabel}');

      // Add photo thumbnail bubble to chat
      _appendMessage(StudentChatMessage(
        id: _uid(),
        timestamp: DateTime.now(),
        text: 'Q${leaf.questionLabel} • photo submitted',
        isPhoto: true,
      ));

      state = state!.copyWith(isUploading: false);

      // Now confirm to engine
      await onAction(const PhotoCaptured());
    } catch (e) {
      debugPrint('[VivaNotifier] Photo upload failed: $e');
      state = state!.copyWith(
        isUploading: false,
        errorMessage: () => 'Photo upload failed. Please try again.',
      );
    }
  }

  /// Called when student aborts capture or code expires.
  Future<void> onPhotoAborted({String reason = 'student_aborted'}) async {
    await onAction(PhotoAborted(reason: reason));
  }

  // ── Dismiss error ─────────────────────────────────────────────────────────

  void clearError() {
    state = state?.copyWith(errorMessage: () => null);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ENGINE MESSAGE HANDLER
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _handleEngineMessage(ExaminerMessage message) async {
    switch (message) {

      // ── API triggers (not chat bubbles) ────────────────────────────────────

      case PhotoCodeRequest(:final questionId):
        // Small delay so the question bubble renders before loading spinner
        await Future.delayed(const Duration(milliseconds: 400));
        await _handlePhotoCodeRequest(questionId);

      case PhotoCodeRequest(:final questionId):
        await _handlePhotoCodeRequest(questionId);

      case PhotoCodeRegenRequest(:final questionId, :final voidReason):
        await _handlePhotoCodeRegen(questionId, voidReason);

      // ── Regular chat bubbles ───────────────────────────────────────────────

      case FinalAnswerReceivedMessage():
        _appendMessage(_translateMessage(message));
        // Saving final answer to API — triggered from the action handler below
        // (we need the answer value — see _appendStudentBubbleIfNeeded)

      default:
        final chatMsg = _translateMessage(message);
        _appendMessage(chatMsg);
    }
  }

  Future<void> _handlePhotoCodeRequest(int questionId) async {
    if (_sectionId == null) return;

    state = state!.copyWith(isLoading: true);

    try {
      final code = await VivaService.generatePhotoCode(
        sectionId: _sectionId!,
        questionId: questionId,
      );

      state = state!.copyWith(
        isLoading: false,
        activePhotoCode: () => code,
      );

      // Feed code back to engine
      await onAction(PhotoCodeProvided(code));
    } catch (e) {
      debugPrint('[VivaNotifier] generatePhotoCode failed: $e');
      state = state!.copyWith(
        isLoading: false,
        errorMessage: () => 'Could not generate photo code. Check network.',
      );
    }
  }

  Future<void> _handlePhotoCodeRegen(int questionId, String voidReason) async {
    if (_sectionId == null) return;

    state = state!.copyWith(isLoading: true);

    try {
      final code = await VivaService.regeneratePhotoCode(
        sectionId: _sectionId!,
        questionId: questionId,
        voidReason: voidReason,
      );

      state = state!.copyWith(
        isLoading: false,
        activePhotoCode: () => code,
      );

      await onAction(PhotoCodeProvided(code));
    } catch (e) {
      debugPrint('[VivaNotifier] regeneratePhotoCode failed: $e');
      state = state!.copyWith(
        isLoading: false,
        errorMessage: () => 'Could not regenerate code. Check network.',
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // API SAVE CALLS — triggered from action handling
  // ════════════════════════════════════════════════════════════════════════════

  void _saveAnswerFromAction(StudentAction action) {
    if (_sectionId == null) return;
    final leaf = _engine.currentSubQuestion ?? _engine.currentQuestion;
    if (leaf == null) return;

    switch (action) {
      case EssaySubmitted(:final text):
        VivaService.saveTextAnswer(
          sectionId: _sectionId!,
          questionId: leaf.id,
          text: text,
          isWorkingNotes: false,
        ).catchError((e) =>
          debugPrint('[VivaNotifier] saveTextAnswer failed: $e'));

      case WorkingNotesSubmitted(:final text):
        VivaService.saveTextAnswer(
          sectionId: _sectionId!,
          questionId: leaf.id,
          text: text,
          isWorkingNotes: true,
        ).catchError((e) =>
          debugPrint('[VivaNotifier] saveWorkingNotes failed: $e'));

      case FinalAnswerSubmitted(:final answer):
        VivaService.saveFinalAnswer(
          sectionId: _sectionId!,
          questionId: leaf.id,
          finalAnswer: answer,
        ).catchError((e) =>
          debugPrint('[VivaNotifier] saveFinalAnswer failed: $e'));

      case QuestionsLocked(:final groupId, :final selectedQuestionIds):
        VivaService.lockSelection(
          sectionId: _sectionId!,
          groupId: groupId,
          questionIds: selectedQuestionIds,
        ).catchError((e) =>
          debugPrint('[VivaNotifier] lockSelection failed: $e'));

      default:
        break;
    }
  }

  // ── Submit section ────────────────────────────────────────────────────────

  Future<void> submitSection() async {
    if (_sectionId == null || state == null) return;

    state = state!.copyWith(isLoading: true);

    try {
      await VivaService.submitSection(_sectionId!);
      state = state!.copyWith(isLoading: false, isSubmitted: true);
      debugPrint('[VivaNotifier] Viva section submitted');
    } catch (e) {
      debugPrint('[VivaNotifier] submitSection failed: $e');
      state = state!.copyWith(
        isLoading: false,
        errorMessage: () => 'Submission failed. Please try again.',
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STATE SYNC
  // ════════════════════════════════════════════════════════════════════════════

  void _updateStateFromEngine() {
    if (state == null) return;
    state = state!.copyWith(
      currentStep: _engine.currentStep,
      currentQuestion: () => _engine.currentQuestion,
      currentSubQuestion: () => _engine.currentSubQuestion,
      questionsOrder: _engine.questionsOrder,
      questionsAnswered: _engine.questionsAnswered,
      questionsRemaining: _engine.questionsRemaining,
      dropsEmitted: _engine.dropsEmitted,
      inputMode: _engine.currentInputMode,
      activePhotoCode: () => _engine.activePhotoCode,
    );

    // Fire-and-forget step sync to server
    _syncStep();
  }

  void _syncStep() {
    if (_sectionId == null || state == null) return;

    VivaService.advanceStep(
      sectionId: _sectionId!,
      step: _engine.stepToString(_engine.currentStep),
      currentQuestionId: _engine.currentQuestion?.id,
      currentSubQuestionId: _engine.currentSubQuestion?.id,
      questionsOrder: _engine.questionsOrder,
      questionsAnswered: _engine.questionsAnswered,
      questionsRemaining: _engine.questionsRemaining,
    ).catchError((e) =>
      debugPrint('[VivaNotifier] syncStep failed (non-fatal): $e'));
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHAT HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  void _appendStudentBubbleIfNeeded(StudentAction action) {
    switch (action) {
      case EssaySubmitted(:final text):
        _appendMessage(StudentChatMessage(
          id: _uid(), timestamp: DateTime.now(), text: text));
        _saveAnswerFromAction(action);

      case WorkingNotesSubmitted(:final text):
        _appendMessage(StudentChatMessage(
          id: _uid(), timestamp: DateTime.now(), text: text));
        _saveAnswerFromAction(action);

      case FinalAnswerSubmitted(:final answer):
        _appendMessage(StudentChatMessage(
          id: _uid(), timestamp: DateTime.now(), text: answer));
        _saveAnswerFromAction(action);

      case QuestionSelected(:final questionId):
        final q = _engine.currentQuestion ??
            state?.allRootQuestions.firstWhere(
              (r) => r.id == questionId,
              orElse: () => state!.allRootQuestions.first,
            );
        _appendMessage(StudentChatMessage(
          id: _uid(),
          timestamp: DateTime.now(),
          text: 'Question ${q?.questionLabel ?? questionId}',
          isChoice: true,
        ));

      case QuestionsLocked(:final groupId, :final selectedQuestionIds):
        final allGroupQs = (state?.questionGroups ?? [])
            .expand((g) => g.questions)
            .toList();
        final labels = selectedQuestionIds.map((id) {
          final q = allGroupQs.where((q) => q.id == id).firstOrNull;
          return q != null ? 'Question ${q.questionLabel}' : 'Q#$id';
        }).join(' & ');
        _appendMessage(StudentChatMessage(
          id: _uid(),
          timestamp: DateTime.now(),
          text: "I'll answer $labels",
          isChoice: true,
        ));
        _saveAnswerFromAction(action);

      case ReadyToBegin():
        _appendMessage(StudentChatMessage(
          id: _uid(),
          timestamp: DateTime.now(),
          text: "Ready to begin",
          isChoice: true,
        ));

      case SubmitConfirmed():
        _appendMessage(StudentChatMessage(
          id: _uid(),
          timestamp: DateTime.now(),
          text: "Submit exam",
          isChoice: true,
        ));

      default:
        break;
    }
  }

  void _appendMessage(ChatMessage message) {
    if (state == null) return;
    state = state!.copyWith(
      chatHistory: [...state!.chatHistory, message],
    );
  }

  List<ChatMessage> _translateAll(List<ExaminerMessage> messages) {
    // Filter out API triggers — they're not chat bubbles
    return messages
        .where((m) => m is! PhotoCodeRequest && m is! PhotoCodeRegenRequest)
        .map(_translateMessage)
        .toList();
  }

  VivaChatMessage _translateMessage(ExaminerMessage message) {
    return switch (message) {
      GroundingMessage(:final text) => _vivaMessage(text, VivaMessageVariant.grounding),

      ScanOverviewMessage(:final introText, :final questions, :final groups) =>
        VivaChatMessage(
          id: _uid(),
          timestamp: DateTime.now(),
          text: introText,
          variant: VivaMessageVariant.instructions,
          questionChoices: questions,
          questionGroups: groups,
        ),

      StartChoiceMessage(:final text, :final availableQuestions) =>
        VivaChatMessage(
          id: _uid(),
          timestamp: DateTime.now(),
          text: text,
          variant: VivaMessageVariant.transition,
          questionChoices: availableQuestions,
        ),

      QuestionIntroMessage(:final text) =>
        _vivaMessage(text, VivaMessageVariant.question),

      SubQuestionPromptMessage(:final text, :final subQuestion, :final contextHint) =>
        VivaChatMessage(
          id: _uid(),
          timestamp: DateTime.now(),
          text: contextHint != null ? '$contextHint\n\n$text' : text,
          variant: VivaMessageVariant.subQuestion,
        ),

      PhotoCodePromptMessage(:final instructionText, :final code) =>
        VivaChatMessage(
          id: _uid(),
          timestamp: DateTime.now(),
          text: instructionText,
          variant: VivaMessageVariant.photoCode,
          photoCode: code,
        ),

      PhotoConfirmedMessage(:final text) =>
        _vivaMessage(text, VivaMessageVariant.confirmation),

      EssayReceivedMessage(:final text) =>
        _vivaMessage(text, VivaMessageVariant.confirmation),

      FinalAnswerReceivedMessage(:final text) =>
        _vivaMessage(text, VivaMessageVariant.confirmation),

      QuestionSummaryMessage(:final text, :final completedParts) =>
        VivaChatMessage(
          id: _uid(),
          timestamp: DateTime.now(),
          text: text,
          variant: VivaMessageVariant.summary,
          completedParts: completedParts,
        ),

      BetweenQuestionsMessage(:final text, :final remaining) =>
        VivaChatMessage(
          id: _uid(),
          timestamp: DateTime.now(),
          text: text,
          variant: VivaMessageVariant.transition,
          questionChoices: remaining,
        ),

      MotivationalDropMessage(:final text) =>
        _vivaMessage(text, VivaMessageVariant.motivational),

      SubmitConfirmationMessage(:final text) =>
        _vivaMessage(text, VivaMessageVariant.completion),

      ExamCompleteMessage(:final text) =>
        _vivaMessage(text, VivaMessageVariant.completion),

      // These are API triggers — should not reach here after filtering
      PhotoCodeRequest()    => _vivaMessage('', VivaMessageVariant.confirmation),
      PhotoCodeRegenRequest() => _vivaMessage('', VivaMessageVariant.confirmation),
    };
  }

  VivaChatMessage _vivaMessage(String text, VivaMessageVariant variant) {
    return VivaChatMessage(
      id: _uid(),
      timestamp: DateTime.now(),
      text: text,
      variant: variant,
    );
  }

  /// Rebuild chat history from the server's conversation_log JSON.
  /// Used for crash recovery resume.
  List<ChatMessage> _rebuildChatHistory(
      List<Map<String, dynamic>> log) {
    return log.map((entry) {
      final type = entry['type'] as String?;
      final payload = entry['payload'] as Map<String, dynamic>? ?? {};
      final ts = DateTime.tryParse(entry['timestamp'] as String? ?? '') ??
          DateTime.now();

      if (type == 'student') {
        return StudentChatMessage(
          id: entry['id'] as String? ?? _uid(),
          timestamp: ts,
          text: payload['text'] as String? ??
              payload['answer'] as String? ?? '',
          isPhoto: entry['action_type'] == 'PhotoCaptured',
          isChoice: entry['action_type']?.toString().contains('Selected') == true,
        );
      }

      return VivaChatMessage(
        id: entry['id'] as String? ?? _uid(),
        timestamp: ts,
        text: payload['text'] as String? ?? '',
        variant: VivaMessageVariant.grounding,
      );
    }).toList();
  }

  VivaEngineState _emptyState() => const VivaEngineState();

  int _uidCounter = 0;
  String _uid() => 'msg_${DateTime.now().millisecondsSinceEpoch}_${_uidCounter++}';

  @override
  void dispose() {
    debugPrint('[VivaNotifier] disposed');
    super.dispose();
  }
}
