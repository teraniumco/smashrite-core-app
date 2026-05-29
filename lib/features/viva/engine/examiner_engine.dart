// The Smashrite Viva ExaminerEngine.
//
// Pure Dart — no Flutter, no HTTP, no async.
// All API calls are handled by VivaNotifier which feeds results back
// via StudentAction events (e.g. PhotoCodeProvided).
//
// The engine is the intellectual property of Smashrite Technologies.
// Every student gets identical examination logic. Fairness is guaranteed.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:smashrite/features/viva/data/models/viva_chat_message.dart';
import 'package:smashrite/features/viva/data/models/viva_engine_state.dart';
import 'package:smashrite/features/viva/data/models/viva_question.dart';
import 'package:smashrite/features/viva/data/models/viva_section.dart';
import 'package:smashrite/features/viva/engine/motivational_drop_engine.dart';
import 'package:smashrite/features/viva/engine/viva_dialogue.dart';

class ExaminerEngine {
  // ── Dependencies ──────────────────────────────────────────────────────────
  final VivaDialogue _dialogue;
  final MotivationalDropEngine _drops;

  // ── Section data ──────────────────────────────────────────────────────────
  VivaSection? _section;
  List<VivaQuestion> _allRootQuestions = [];
  List<VivaQuestionGroup> _questionGroups = [];

  // ── Current position ──────────────────────────────────────────────────────
  EngineStep _step = EngineStep.grounding;
  VivaQuestion? _currentQuestion;
  int _currentSubIndex = 0;

  // ── Progress ──────────────────────────────────────────────────────────────
  List<int> _questionsOrder = [];
  List<int> _questionsAnswered = [];
  List<int> _questionsRemaining = [];

  // ── Answer tracking (for context hints) ───────────────────────────────────
  final Map<int, String?> _finalAnswers = {};  // questionId → final answer
  final Map<int, String?> _workingNotes = {};  // questionId → working notes

  // ── Motivational drops ─────────────────────────────────────────────────────
  List<String> _dropsEmitted = [];

  // ── Struggle detection ─────────────────────────────────────────────────────
  DateTime? _subQuestionStartTime;
  static const _struggleThresholdSeconds = 90;

  // ── Active photo code ──────────────────────────────────────────────────────
  PhotoCodeData? _activePhotoCode;

  ExaminerEngine({VivaDialogue? dialogue})
      : _dialogue = dialogue ?? VivaDialogue(),
        _drops = MotivationalDropEngine(dialogue ?? VivaDialogue());

  // ════════════════════════════════════════════════════════════════════════════
  // STATE ACCESSORS — read by VivaNotifier to update VivaEngineState
  // ════════════════════════════════════════════════════════════════════════════

  EngineStep get currentStep         => _step;
  VivaQuestion? get currentQuestion  => _currentQuestion;
  List<int> get questionsOrder       => List.unmodifiable(_questionsOrder);
  List<int> get questionsAnswered    => List.unmodifiable(_questionsAnswered);
  List<int> get questionsRemaining   => List.unmodifiable(_questionsRemaining);
  List<String> get dropsEmitted      => List.unmodifiable(_dropsEmitted);
  PhotoCodeData? get activePhotoCode => _activePhotoCode;

  VivaQuestion? get currentSubQuestion {
    final q = _currentQuestion;
    if (q == null) return null;
    if (!q.isCompound) return null;
    if (_currentSubIndex >= q.subQuestions.length) return null;
    return q.subQuestions[_currentSubIndex];
  }

  // The leaf question being answered right now (compound → current sub, else root)
  VivaQuestion? get _activeLeaf {
    final q = _currentQuestion;
    if (q == null) return null;
    if (q.isCompound) return currentSubQuestion;
    return q;
  }

  InputMode get currentInputMode {
    return switch (_step) {
      EngineStep.grounding        => InputMode.none,
      EngineStep.scanOverview     => InputMode.readOnly,
      EngineStep.selection        => InputMode.selection,
      EngineStep.startChoice      => InputMode.choiceButtons,
      EngineStep.questionIntro    => InputMode.none,
      EngineStep.awaitingNotes    => InputMode.workingNotes,
      EngineStep.awaitingFinalAnswer => InputMode.finalAnswer,
      EngineStep.awaitingEssay    => InputMode.essayText,
      EngineStep.awaitingPhoto    => InputMode.cameraCapture,
      EngineStep.questionSummary  => InputMode.none,
      EngineStep.betweenQuestions => InputMode.choiceButtons,
      EngineStep.awaitingSubmit   => InputMode.submitConfirm,
      EngineStep.submitted        => InputMode.none,
    };
  }

  // ════════════════════════════════════════════════════════════════════════════
  // INIT — fresh session
  // ════════════════════════════════════════════════════════════════════════════

  List<ExaminerMessage> init(VivaInitData data) {
    _section = data.section;
    _questionGroups = data.questionGroups;
    _allRootQuestions = data.allRootQuestions;
    _questionsRemaining = _allRootQuestions.map((q) => q.id).toList();

    final messages = <ExaminerMessage>[];

    // Grounding message
    final groundingDrop = _drops.evaluateGrounding(_dropsEmitted);
    if (groundingDrop != null) {
      _dropsEmitted.add(DropKeys.grounding);
    }

    messages.add(GroundingMessage(
      text: groundingDrop ?? _dialogue.grounding,
      totalQuestions: _allRootQuestions.length,
      totalMarks: _allRootQuestions.fold(0, (sum, q) => sum + q.marks),
      remainingSeconds: data.remainingSeconds,
    ));

    // Scan overview
    final hasOptional = _questionGroups.any((g) => g.isOptional);
    if (hasOptional) {
      final group = _questionGroups.firstWhere((g) => g.isOptional);
      messages.add(ScanOverviewMessage(
        introText: _dialogue.scanOptional(
          group.requiredCount ?? 1,
          _allRootQuestions.length,  // total questions in the section
          optionalCount: group.totalCount,
        ),
        questions: _allRootQuestions,
        groups: _questionGroups,
        isOptionalMode: true,
        requiredCount: group.requiredCount,
      ));
      _step = EngineStep.selection;
    } else {
      messages.add(ScanOverviewMessage(
        introText: _dialogue.scanRequired(_allRootQuestions.length),
        questions: _allRootQuestions,
        groups: _questionGroups,
        isOptionalMode: false,
      ));
      _step = EngineStep.scanOverview;
    }

    debugPrint('[ExaminerEngine] Initialized: ${_allRootQuestions.length} questions');
    return messages;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // RESUME — restore from server state after crash
  // ════════════════════════════════════════════════════════════════════════════

  void resume(VivaInitData data, VivaServerState serverState) {
    _section = data.section;
    _questionGroups = data.questionGroups;
    _allRootQuestions = data.allRootQuestions;

    _questionsOrder    = List.from(serverState.questionsOrder);
    _questionsAnswered = List.from(serverState.questionsAnswered);
    _questionsRemaining = List.from(serverState.questionsRemaining);
    _dropsEmitted      = List.from(serverState.dropsEmitted);

    _step = _parseStep(serverState.currentStep);

    // Restore current question
    if (serverState.currentQuestionId != null) {
      _currentQuestion = _questionById(serverState.currentQuestionId!);
    }

    // Restore sub-question index
    if (serverState.currentSubQuestionId != null &&
        _currentQuestion?.isCompound == true) {
      _currentSubIndex = _currentQuestion!.subQuestions
          .indexWhere((s) => s.id == serverState.currentSubQuestionId);
      if (_currentSubIndex < 0) _currentSubIndex = 0;
    }

    debugPrint('[ExaminerEngine] Resumed at step: $_step');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PROCESS ACTION — the main entry point
  // ════════════════════════════════════════════════════════════════════════════

  List<ExaminerMessage> processAction(StudentAction action) {
    debugPrint('[ExaminerEngine] Action: ${action.runtimeType}, step: $_step');

    return switch (action) {
      ReadyToBegin()            => _handleReadyToBegin(),
      QuestionSelected(:final questionId) => _handleQuestionSelected(questionId),
      QuestionsLocked(:final groupId, :final selectedQuestionIds)
                                => _handleQuestionsLocked(groupId, selectedQuestionIds),
      WorkingNotesSubmitted(:final text) => _handleWorkingNotesSubmitted(text),
      WorkingNotesSkipped()     => _handleWorkingNotesSkipped(),
      FinalAnswerSubmitted(:final answer) => _handleFinalAnswerSubmitted(answer),
      PhotoCodeProvided(:final code) => _handlePhotoCodeProvided(code),
      PhotoCaptured()           => _handlePhotoCaptured(),
      PhotoAborted(:final reason) => _handlePhotoAborted(reason),
      EssaySubmitted(:final text) => _handleEssaySubmitted(text),
      ReviewRequested()         => [], // handled by UI — no engine change
      SubmitConfirmed()         => _handleSubmitConfirmed(),
    };
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ACTION HANDLERS
  // ════════════════════════════════════════════════════════════════════════════

  List<ExaminerMessage> _handleReadyToBegin() {
    if (_step != EngineStep.scanOverview &&
        _step != EngineStep.grounding &&
        _step != EngineStep.selection) {
      return [];
    }

    _step = EngineStep.startChoice;

    return [
      StartChoiceMessage(
        text: _dialogue.startChoice,
        availableQuestions: _questionsRemaining
            .map(_questionById)
            .whereType<VivaQuestion>()
            .toList(),
      ),
    ];
  }

  List<ExaminerMessage> _handleQuestionsLocked(
    int groupId, List<int> selectedIds) {

    // Filter allRootQuestions to only the selected ones + non-optional groups
    final optionalGroup = _questionGroups.firstWhere(
      (g) => g.id == groupId, orElse: () => _questionGroups.first);

    final selectedQuestions = optionalGroup.questions
        .where((q) => selectedIds.contains(q.id))
        .toList();

    final nonOptionalQuestions = _allRootQuestions
        .where((q) => !optionalGroup.questions.any((og) => og.id == q.id))
        .toList();

    _allRootQuestions = [...nonOptionalQuestions, ...selectedQuestions];
    _questionsRemaining = _allRootQuestions.map((q) => q.id).toList();

    _step = EngineStep.startChoice;

    return [
      StartChoiceMessage(
        text: _dialogue.startChoice,
        availableQuestions: _questionsRemaining
            .map(_questionById)
            .whereType<VivaQuestion>()
            .toList(),
      ),
    ];
  }

  List<ExaminerMessage> _handleQuestionSelected(int questionId) {
    final question = _questionById(questionId);
    if (question == null) {
      debugPrint('[ExaminerEngine] ERROR: question $questionId not found');
      return [];
    }

    _currentQuestion = question;
    _currentSubIndex = 0;

    // Track question order
    if (!_questionsOrder.contains(questionId)) {
      _questionsOrder.add(questionId);
    }
    _questionsRemaining.remove(questionId);

    _step = EngineStep.questionIntro;

    final messages = <ExaminerMessage>[];

    // Question intro
    messages.add(QuestionIntroMessage(
      text: question.isCompound
          ? _dialogue.questionIntroCompound(question.subQuestions.length)
          : _dialogue.questionIntroSingle,
      question: question,
      partCount: question.isCompound ? question.subQuestions.length : 1,
    ));

    // Open first leaf question
    messages.addAll(_openLeafQuestion(
      question.isCompound ? question.subQuestions[0] : question,
    ));

    return messages;
  }

  List<ExaminerMessage> _handleWorkingNotesSubmitted(String text) {
    final leaf = _activeLeaf;
    if (leaf != null) _workingNotes[leaf.id] = text;

    // No Viva message — student's notes appear as their own chat bubble
    // Engine just advances the step
    _step = EngineStep.awaitingFinalAnswer;
    return [];
  }

  List<ExaminerMessage> _handleWorkingNotesSkipped() {
    _step = EngineStep.awaitingFinalAnswer;
    return [];
  }

  List<ExaminerMessage> _handleFinalAnswerSubmitted(String answer) {
    final leaf = _activeLeaf;
    if (leaf == null) return [];

    _finalAnswers[leaf.id] = answer;

    // Need photo code from API — signal to notifier
    return [
      PhotoCodeRequest(
        questionId: leaf.id,
        questionLabel: leaf.questionLabel,
      ),
    ];
  }

  List<ExaminerMessage> _handlePhotoCodeProvided(PhotoCodeData code) {
    _activePhotoCode = code;
    _step = EngineStep.awaitingPhoto;
    _subQuestionStartTime = DateTime.now();

    final leaf = _activeLeaf!;

    return [
      PhotoCodePromptMessage(
        instructionText: _dialogue.photoCodeInstruction(leaf.questionLabel),
        code: code,
      ),
    ];
  }

  List<ExaminerMessage> _handlePhotoCaptured() {
    _activePhotoCode = null;

    final messages = <ExaminerMessage>[];

    // Confirmation
    messages.add(PhotoConfirmedMessage(text: _dialogue.photoConfirmed));

    // Check for struggle drop
    final wasLongStruggle = _subQuestionStartTime != null &&
        DateTime.now().difference(_subQuestionStartTime!).inSeconds >=
            _struggleThresholdSeconds;
    final struggleDrop =
        _drops.evaluateAfterStruggle(_dropsEmitted, wasLongStruggle: wasLongStruggle);
    if (struggleDrop != null) {
      _dropsEmitted.add(DropKeys.struggle);
      messages.add(MotivationalDropMessage(text: struggleDrop));
    }

    _subQuestionStartTime = null;
    messages.addAll(_advanceSubOrQuestion());
    return messages;
  }

  List<ExaminerMessage> _handlePhotoAborted(String reason) {
    _activePhotoCode = null;
    _step = EngineStep.awaitingPhoto;
    final leaf = _activeLeaf;
    if (leaf == null) return [];

    // Signal notifier to regenerate — NOT a chat bubble
    return [
      PhotoCodeRegenRequest(
        questionId: leaf.id,
        voidReason: reason,
      ),
    ];
  }

  List<ExaminerMessage> _handleEssaySubmitted(String text) {
    final leaf = _activeLeaf;
    if (leaf == null) return [];

    final wordCount = _countWords(text);

    final messages = <ExaminerMessage>[
      EssayReceivedMessage(
        text: _dialogue.essayConfirmed(wordCount),
        wordCount: wordCount,
      ),
    ];

    // Check for struggle drop
    final wasLongStruggle = _subQuestionStartTime != null &&
        DateTime.now().difference(_subQuestionStartTime!).inSeconds >=
            _struggleThresholdSeconds;
    final struggleDrop =
        _drops.evaluateAfterStruggle(_dropsEmitted, wasLongStruggle: wasLongStruggle);
    if (struggleDrop != null) {
      _dropsEmitted.add(DropKeys.struggle);
      messages.add(MotivationalDropMessage(text: struggleDrop));
    }

    _subQuestionStartTime = null;
    messages.addAll(_advanceSubOrQuestion());
    return messages;
  }

  List<ExaminerMessage> _handleSubmitConfirmed() {
    _step = EngineStep.submitted;
    return [ExamCompleteMessage(text: _dialogue.examComplete)];
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  /// Opens a leaf question — emits the prompt and sets up the correct input mode.
  List<ExaminerMessage> _openLeafQuestion(
    VivaQuestion leaf, {
    String? contextHint,
  }) {
    _subQuestionStartTime = DateTime.now();
    final messages = <ExaminerMessage>[];

    final prompt = SubQuestionPromptMessage(
      text: _buildSubQuestionText(leaf), // always the question text
      subQuestion: leaf,
      contextHint: contextHint,
    );
    messages.add(prompt);

    // Diagram: request photo code — but yield a render frame first
    if (leaf.isDiagram) {
      _step = EngineStep.awaitingPhoto;
      // Return just the prompt now; notifier will request the photo code
      // after the next frame so the question text is visible first
      messages.add(PhotoCodeRequest(
        questionId: leaf.id,
        questionLabel: leaf.questionLabel,
      ));
      return messages;
    }

    // Essay
    if (leaf.isEssay) {
      _step = EngineStep.awaitingEssay;
      return messages;
    }

    // Calculation
    if (leaf.isCalculation) {
      if (leaf.showWorkingNotes) {
        _step = EngineStep.awaitingNotes;
      } else {
        _step = EngineStep.awaitingFinalAnswer;
      }
      return messages;
    }

    return messages;
  }

  /// Advance to the next sub-question or complete the current root question.
  List<ExaminerMessage> _advanceSubOrQuestion() {
    final q = _currentQuestion!;
    final messages = <ExaminerMessage>[];

    final isCompound = q.isCompound;
    final hasMoreSubs = isCompound &&
        _currentSubIndex < q.subQuestions.length - 1;

    if (hasMoreSubs) {
      // ── More sub-questions ──────────────────────────────────────────────
      _currentSubIndex++;
      final nextSub = q.subQuestions[_currentSubIndex];

      // Context hint from previous sub
      final prevSub = q.subQuestions[_currentSubIndex - 1];
      final hint = _buildContextHint(prevSub);

      // Motivational drop after first sub completes
      final firstSubDrop = _drops.evaluateFirstSub(
        _dropsEmitted,
        isFirstCompound: _currentSubIndex == 1,
      );
      if (firstSubDrop != null) {
        _dropsEmitted.add(DropKeys.firstSub);
        messages.add(MotivationalDropMessage(text: firstSubDrop));
      }

      messages.addAll(_openLeafQuestion(nextSub, contextHint: hint));

    } else {
      // ── Root question complete ──────────────────────────────────────────
      _questionsAnswered.add(q.id);

      // Build summary
      messages.add(_buildQuestionSummary(q));

      // Evaluate drops at question completion
      final percent = _questionsOrder.isEmpty
          ? 0.0
          : _questionsAnswered.length / _allRootQuestions.length * 100;

      // Heaviest / final question drop
      final questionDrop = _drops.evaluateQuestionComplete(
        _dropsEmitted,
        completedQuestion: q,
        allQuestions: _allRootQuestions,
        answeredIds: _questionsAnswered,
      );
      if (questionDrop != null) {
        final (dropText, dropKey) = questionDrop; // destructure the record
        _dropsEmitted.add(dropKey);
        messages.add(MotivationalDropMessage(text: dropText));
      }

      // Midpoint drop
      final midDrop = _drops.evaluateMidpoint(_dropsEmitted, percentComplete: percent);
      if (midDrop != null) {
        _dropsEmitted.add(DropKeys.midpoint);
        messages.add(MotivationalDropMessage(text: midDrop));
      }

      // Navigate
      if (_questionsRemaining.isEmpty) {
        _step = EngineStep.awaitingSubmit;
        messages.add(SubmitConfirmationMessage(
          text: _dialogue.submitPrompt,
          allQuestions: _allRootQuestions,
        ));
      } else {
        _step = EngineStep.betweenQuestions;
        messages.add(BetweenQuestionsMessage(
          text: _dialogue.nextQuestionChoice,
          remaining: _questionsRemaining
              .map(_questionById)
              .whereType<VivaQuestion>()
              .toList(),
        ));
      }
    }

    return messages;
  }

  QuestionSummaryMessage _buildQuestionSummary(VivaQuestion q) {
    final leaves = q.leafQuestions;
    final parts = leaves.map((leaf) {
      return CompletedSubSummary(
        label: leaf.questionLabel,
        type: leaf.type,
        hasText: leaf.isEssay,
        hasFinalAnswer: leaf.isCalculation && _finalAnswers[leaf.id] != null,
        hasPhoto: (leaf.isCalculation || leaf.isDiagram),
      );
    }).toList();

    return QuestionSummaryMessage(
      text: _dialogue.questionComplete(q.questionLabel),
      question: q,
      completedParts: parts,
    );
  }

  String _buildSubQuestionText(VivaQuestion leaf) {
    // ALWAYS start with the actual question text.
    final base = leaf.questionText;

    if (leaf.isEssay) {
      final parts = <String>[];
      if (leaf.minWords != null) parts.add('min ${leaf.minWords} words');
      if (leaf.maxWords != null) parts.add('max ${leaf.maxWords} words');
      return parts.isNotEmpty ? '$base\n\n📝 ${parts.join(' · ')}' : base;
    }

    if (leaf.isDiagram) {
      return '$base\n\n📐 Draw your answer on paper. You\'ll photograph it when done.';
    }

    if (leaf.isCalculation && leaf.showWorkingNotes) {
      return '$base\n\n🧮 Show your working before giving your final answer.';
    }

    return base;
  }

  String? _buildContextHint(VivaQuestion prevSub) {
    if (!prevSub.isCalculation) return null;
    final answer = _finalAnswers[prevSub.id];
    if (answer == null) return null;
    return _dialogue.contextHint(prevSub.questionLabel, answer);
  }

  VivaQuestion? _questionById(int id) {
    for (final q in _allRootQuestions) {
      if (q.id == id) return q;
      for (final sub in q.subQuestions) {
        if (sub.id == id) return sub;
        for (final subsub in sub.subQuestions) {
          if (subsub.id == id) return subsub;
        }
      }
    }
    return null;
  }

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  EngineStep _parseStep(String step) {
    return switch (step) {
      'grounding'              => EngineStep.grounding,
      'scan_overview'          => EngineStep.scanOverview,
      'selection'              => EngineStep.selection,
      'start_choice'           => EngineStep.startChoice,
      'question_intro'         => EngineStep.questionIntro,
      'awaiting_notes'         => EngineStep.awaitingNotes,
      'awaiting_final_answer'  => EngineStep.awaitingFinalAnswer,
      'awaiting_essay'         => EngineStep.awaitingEssay,
      'awaiting_photo'         => EngineStep.awaitingPhoto,
      'question_summary'       => EngineStep.questionSummary,
      'between_questions'      => EngineStep.betweenQuestions,
      'awaiting_submit'        => EngineStep.awaitingSubmit,
      'submitted'              => EngineStep.submitted,
      _                        => EngineStep.grounding,
    };
  }

  String stepToString(EngineStep step) {
    return switch (step) {
      EngineStep.grounding           => 'grounding',
      EngineStep.scanOverview        => 'scan_overview',
      EngineStep.selection           => 'selection',
      EngineStep.startChoice         => 'start_choice',
      EngineStep.questionIntro       => 'question_intro',
      EngineStep.awaitingNotes       => 'awaiting_notes',
      EngineStep.awaitingFinalAnswer => 'awaiting_final_answer',
      EngineStep.awaitingEssay       => 'awaiting_essay',
      EngineStep.awaitingPhoto       => 'awaiting_photo',
      EngineStep.questionSummary     => 'question_summary',
      EngineStep.betweenQuestions    => 'between_questions',
      EngineStep.awaitingSubmit      => 'awaiting_submit',
      EngineStep.submitted           => 'submitted',
    };
  }
}
