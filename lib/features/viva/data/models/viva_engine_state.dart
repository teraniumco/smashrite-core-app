// lib/features/viva/data/models/viva_engine_state.dart

import 'package:smashrite/features/viva/data/models/viva_chat_message.dart';
import 'package:smashrite/features/viva/data/models/viva_question.dart';
import 'package:smashrite/features/viva/data/models/viva_section.dart';

/// Engine steps — must match VivaSessionState::STEP_* constants on Laravel.
enum EngineStep {
  grounding,
  scanOverview,
  selection,
  startChoice,
  questionIntro,
  awaitingNotes,
  awaitingFinalAnswer,
  awaitingEssay,
  awaitingPhoto,
  questionSummary,
  betweenQuestions,
  awaitingSubmit,
  submitted,
}

/// The full state exposed to the Flutter UI via VivaProvider.
/// Immutable — updated via copyWith.
class VivaEngineState {
  // ── Section & questions ─────────────────────────────────────────────────
  final VivaSection? section;
  final List<VivaQuestionGroup> questionGroups;
  final List<VivaQuestion> standaloneQuestions;

  // ── Engine position ──────────────────────────────────────────────────────
  final EngineStep currentStep;
  final VivaQuestion? currentQuestion;
  final VivaQuestion? currentSubQuestion;
  final int currentSubIndex; // index within compound sub-questions

  // ── Progress ─────────────────────────────────────────────────────────────
  final List<int> questionsOrder;
  final List<int> questionsAnswered;
  final List<int> questionsRemaining;

  // ── Chat ─────────────────────────────────────────────────────────────────
  final List<ChatMessage> chatHistory;

  // ── Input bar ────────────────────────────────────────────────────────────
  final InputMode inputMode;

  // ── Active photo code ────────────────────────────────────────────────────
  final PhotoCodeData? activePhotoCode;

  // ── Optional group selection ─────────────────────────────────────────────
  final Set<int> selectedQuestionIds;
  final bool selectionLocked;

  // ── Motivational drops ────────────────────────────────────────────────────
  final List<String> dropsEmitted;

  // ── Async status ─────────────────────────────────────────────────────────
  final bool isLoading;
  final bool isUploading; // photo upload in progress
  final String? errorMessage;

  // ── Completion ───────────────────────────────────────────────────────────
  final bool isSubmitted;

  const VivaEngineState({
    this.section,
    this.questionGroups = const [],
    this.standaloneQuestions = const [],
    this.currentStep = EngineStep.grounding,
    this.currentQuestion,
    this.currentSubQuestion,
    this.currentSubIndex = 0,
    this.questionsOrder = const [],
    this.questionsAnswered = const [],
    this.questionsRemaining = const [],
    this.chatHistory = const [],
    this.inputMode = InputMode.none,
    this.activePhotoCode,
    this.selectedQuestionIds = const {},
    this.selectionLocked = false,
    this.dropsEmitted = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.errorMessage,
    this.isSubmitted = false,
  });

  VivaEngineState copyWith({
    VivaSection? section,
    List<VivaQuestionGroup>? questionGroups,
    List<VivaQuestion>? standaloneQuestions,
    EngineStep? currentStep,
    VivaQuestion? Function()? currentQuestion,
    VivaQuestion? Function()? currentSubQuestion,
    int? currentSubIndex,
    List<int>? questionsOrder,
    List<int>? questionsAnswered,
    List<int>? questionsRemaining,
    List<ChatMessage>? chatHistory,
    InputMode? inputMode,
    PhotoCodeData? Function()? activePhotoCode,
    Set<int>? selectedQuestionIds,
    bool? selectionLocked,
    List<String>? dropsEmitted,
    bool? isLoading,
    bool? isUploading,
    String? Function()? errorMessage,
    bool? isSubmitted,
  }) {
    return VivaEngineState(
      section: section ?? this.section,
      questionGroups: questionGroups ?? this.questionGroups,
      standaloneQuestions: standaloneQuestions ?? this.standaloneQuestions,
      currentStep: currentStep ?? this.currentStep,
      currentQuestion:
          currentQuestion != null ? currentQuestion() : this.currentQuestion,
      currentSubQuestion: currentSubQuestion != null
          ? currentSubQuestion()
          : this.currentSubQuestion,
      currentSubIndex: currentSubIndex ?? this.currentSubIndex,
      questionsOrder: questionsOrder ?? this.questionsOrder,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      questionsRemaining: questionsRemaining ?? this.questionsRemaining,
      chatHistory: chatHistory ?? this.chatHistory,
      inputMode: inputMode ?? this.inputMode,
      activePhotoCode:
          activePhotoCode != null ? activePhotoCode() : this.activePhotoCode,
      selectedQuestionIds: selectedQuestionIds ?? this.selectedQuestionIds,
      selectionLocked: selectionLocked ?? this.selectionLocked,
      dropsEmitted: dropsEmitted ?? this.dropsEmitted,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }

  // ── Computed helpers ──────────────────────────────────────────────────────

  double get progressPercent {
    if (questionsOrder.isEmpty) return 0;
    return (questionsAnswered.length / questionsOrder.length * 100)
        .clamp(0, 100);
  }

  bool get hasMultipleSections => section != null;

  List<VivaQuestion> get allRootQuestions {
    final fromGroups =
        questionGroups.expand((g) => g.questions).toList();
    return [...fromGroups, ...standaloneQuestions];
  }

  VivaQuestion? questionById(int id) {
    for (final q in allRootQuestions) {
      if (q.id == id) return q;
      for (final sub in q.subQuestions) {
        if (sub.id == id) return sub;
      }
    }
    return null;
  }

  bool isQuestionAnswered(int questionId) =>
      questionsAnswered.contains(questionId);

  @override
  String toString() =>
      'VivaEngineState(step: $currentStep, answered: ${questionsAnswered.length}/${questionsOrder.length})';
}
