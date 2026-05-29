import 'package:flutter/foundation.dart' show immutable;
import 'package:smashrite/features/viva/data/models/viva_question.dart';
import 'package:smashrite/features/viva/data/models/viva_section.dart';

// ════════════════════════════════════════════════════════════════════════════
// EXAMINER MESSAGES — engine outputs
// ════════════════════════════════════════════════════════════════════════════

sealed class ExaminerMessage {
  const ExaminerMessage();
}

// ── Informational ────────────────────────────────────────────────────────────

/// Opening greeting + orientation
class GroundingMessage extends ExaminerMessage {
  final String text;
  final int totalQuestions;
  final double totalMarks;
  final int remainingSeconds;
  const GroundingMessage({
    required this.text,
    required this.totalQuestions,
    required this.totalMarks,
    required this.remainingSeconds,
  });
}

/// Show all questions for student to read (and optionally select)
class ScanOverviewMessage extends ExaminerMessage {
  final String introText;
  final List<VivaQuestion> questions;
  final List<VivaQuestionGroup> groups;
  final bool isOptionalMode;
  final int? requiredCount;
  const ScanOverviewMessage({
    required this.introText,
    required this.questions,
    required this.groups,
    required this.isOptionalMode,
    this.requiredCount,
  });
}

/// Ask student which question to start with
class StartChoiceMessage extends ExaminerMessage {
  final String text;
  final List<VivaQuestion> availableQuestions;
  const StartChoiceMessage({
    required this.text,
    required this.availableQuestions,
  });
}

/// Opening a root question — shows the question body
class QuestionIntroMessage extends ExaminerMessage {
  final String text;
  final VivaQuestion question;
  final int partCount; // 1 for standalone, N for compound
  const QuestionIntroMessage({
    required this.text,
    required this.question,
    required this.partCount,
  });
}

/// Opening a sub-question (or a standalone leaf question)
class SubQuestionPromptMessage extends ExaminerMessage {
  final String text;
  final VivaQuestion subQuestion;
  final String? contextHint; // e.g. "Using your 1(a) answer: a = 3 m/s²"
  const SubQuestionPromptMessage({
    required this.text,
    required this.subQuestion,
    this.contextHint,
  });
}

/// Signal to the notifier: "I need a photo code from the API"
/// NOT added to chat history — intercepted by VivaNotifier
class PhotoCodeRequest extends ExaminerMessage {
  final int questionId;
  final String questionLabel;
  const PhotoCodeRequest({
    required this.questionId,
    required this.questionLabel,
  });
}

/// Show the photo code to the student
class PhotoCodePromptMessage extends ExaminerMessage {
  final String instructionText;
  final PhotoCodeData code;
  const PhotoCodePromptMessage({
    required this.instructionText,
    required this.code,
  });
}

/// Signal to notifier: "regenerate the photo code" (student aborted)
/// NOT added to chat history
class PhotoCodeRegenRequest extends ExaminerMessage {
  final int questionId;
  final String voidReason;
  const PhotoCodeRegenRequest({
    required this.questionId,
    required this.voidReason,
  });
}

/// Confirm photo received
class PhotoConfirmedMessage extends ExaminerMessage {
  final String text;
  const PhotoConfirmedMessage({required this.text});
}

/// Confirm essay received
class EssayReceivedMessage extends ExaminerMessage {
  final String text;
  final int wordCount;
  const EssayReceivedMessage({required this.text, required this.wordCount});
}

/// Confirm final answer saved
class FinalAnswerReceivedMessage extends ExaminerMessage {
  final String text;
  const FinalAnswerReceivedMessage({required this.text});
}

/// Summary of all parts of a completed question
class QuestionSummaryMessage extends ExaminerMessage {
  final String text;
  final VivaQuestion question;
  final List<CompletedSubSummary> completedParts;
  const QuestionSummaryMessage({
    required this.text,
    required this.question,
    required this.completedParts,
  });
}

/// Between-question transition — choose the next question
class BetweenQuestionsMessage extends ExaminerMessage {
  final String text;
  final List<VivaQuestion> remaining;
  const BetweenQuestionsMessage({
    required this.text,
    required this.remaining,
  });
}

/// Motivational drop — emitted at specific moments
class MotivationalDropMessage extends ExaminerMessage {
  final String text;
  const MotivationalDropMessage({required this.text});
}

/// Final submission confirmation prompt
class SubmitConfirmationMessage extends ExaminerMessage {
  final String text;
  final List<VivaQuestion> allQuestions;
  const SubmitConfirmationMessage({
    required this.text,
    required this.allQuestions,
  });
}

/// Exam complete
class ExamCompleteMessage extends ExaminerMessage {
  final String text;
  const ExamCompleteMessage({required this.text});
}

// ════════════════════════════════════════════════════════════════════════════
// STUDENT ACTIONS — engine inputs
// ════════════════════════════════════════════════════════════════════════════

sealed class StudentAction {
  const StudentAction();
}

class ReadyToBegin extends StudentAction {
  const ReadyToBegin();
}

class QuestionSelected extends StudentAction {
  final int questionId;
  const QuestionSelected(this.questionId);
}

/// For optional groups — locks question selection
class QuestionsLocked extends StudentAction {
  final int groupId;
  final List<int> selectedQuestionIds;
  const QuestionsLocked({
    required this.groupId,
    required this.selectedQuestionIds,
  });
}

class WorkingNotesSubmitted extends StudentAction {
  final String text;
  const WorkingNotesSubmitted(this.text);
}

class WorkingNotesSkipped extends StudentAction {
  const WorkingNotesSkipped();
}

class FinalAnswerSubmitted extends StudentAction {
  final String answer;
  const FinalAnswerSubmitted(this.answer);
}

/// Photo code has been received from API — feed into engine
class PhotoCodeProvided extends StudentAction {
  final PhotoCodeData code;
  const PhotoCodeProvided(this.code);
}

/// Photo captured successfully — bytes handled by notifier before this action
class PhotoCaptured extends StudentAction {
  const PhotoCaptured();
}

/// Student aborted capture (or code expired)
class PhotoAborted extends StudentAction {
  final String reason;
  const PhotoAborted({this.reason = 'student_aborted'});
}

class EssaySubmitted extends StudentAction {
  final String text;
  const EssaySubmitted(this.text);
}

class ReviewRequested extends StudentAction {
  final String questionLabel;
  const ReviewRequested(this.questionLabel);
}

class SubmitConfirmed extends StudentAction {
  const SubmitConfirmed();
}

// ════════════════════════════════════════════════════════════════════════════
// CHAT MESSAGE — UI rendering model
// ════════════════════════════════════════════════════════════════════════════

enum ChatSender { viva, student }

/// Input mode — determines what the bottom input bar shows
enum InputMode {
  none,          // Viva is speaking, no input
  readOnly,      // Scan overview — read-only question cards
  choiceButtons, // Action buttons (Begin, Select Question)
  essayText,     // Multi-line text area
  workingNotes,  // Optional notes text field
  finalAnswer,   // Final answer field
  cameraCapture, // Camera button only (photo capture)
  submitConfirm, // Final submit confirmation
  selection,     // Optional group question selection
}

sealed class ChatMessage {
  final String id;
  final DateTime timestamp;
  const ChatMessage({required this.id, required this.timestamp});
}

/// A message from Viva (examiner)
@immutable
class VivaChatMessage extends ChatMessage {
  final String text;
  final VivaMessageVariant variant;

  /// Optional structured data for rendering special bubbles
  final PhotoCodeData? photoCode;
  final List<VivaQuestion>? questionChoices;
  final List<String>? checklist;
  final List<CompletedSubSummary>? completedParts;

  final List<VivaQuestionGroup>? questionGroups;

  const VivaChatMessage({
    required super.id,
    required super.timestamp,
    required this.text,
    required this.variant,
    this.questionGroups,  
    this.photoCode,
    this.questionChoices,
    this.checklist,
    this.completedParts,
  });
}

/// A message from the student (typed text, photo thumbnail, or choice)
@immutable
class StudentChatMessage extends ChatMessage {
  final String text;
  final bool isPhoto;
  final bool isChoice;

  const StudentChatMessage({
    required super.id,
    required super.timestamp,
    required this.text,
    this.isPhoto = false,
    this.isChoice = false,
  });
}

/// Types of Viva messages — drives bubble styling in Phase 6
enum VivaMessageVariant {
  grounding,       // Opening message — distinct style
  question,        // Question body text
  subQuestion,     // Sub-question prompt
  contextHint,     // Carry-forward hint ("Using 1(a): 3 m/s²")
  photoCode,       // Code display with countdown
  confirmation,    // "Received" / "Noted" responses
  summary,         // Question completion summary
  transition,      // Between-question choices
  motivational,    // Motivational drop — subtle highlight
  completion,      // Exam done
  instructions,    // Essay/diagram instructions
}

/// Summary of one completed sub-question (for QuestionSummaryMessage)
@immutable
class CompletedSubSummary {
  final String label;
  final VivaQuestionType type;
  final bool hasText;
  final bool hasFinalAnswer;
  final bool hasPhoto;
  const CompletedSubSummary({
    required this.label,
    required this.type,
    required this.hasText,
    required this.hasFinalAnswer,
    required this.hasPhoto,
  });
}
