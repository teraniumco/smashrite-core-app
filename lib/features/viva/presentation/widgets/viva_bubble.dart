import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/viva/data/models/viva_chat_message.dart';
import 'package:smashrite/features/viva/data/models/viva_question.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _deepBlue = Color(0xFF0F2B6D);
const _orange   = Color(0xFFFF7A00);
const _surface  = Color(0xFFF3F5F9);

// ── Typography ────────────────────────────────────────────────────────────────
//
// Central text style definitions for the Viva (theory exam) chat UI.
// Every bubble class references these constants instead of inline TextStyle(...)
// so changing a font size or weight here updates the entire screen at once.
//
abstract class VivaTypography {

  // ── Viva (examiner) outgoing messages ─────────────────────────────────────

  /// The opening welcome/grounding message Viva sends when the student first
  /// enters the theory section. White text on the dark blue gradient card.
  static const groundingBody = TextStyle(
      color: Colors.white, fontSize: 15, height: 1.7,
      fontWeight: FontWeight.bold);

  /// General Viva messages that don't fit a specific type — e.g. short
  /// one-liners, between-question prompts, or fallback bubble content.
  static const standardBody = TextStyle(
      color: Color(0xFF1A1A2E), fontSize: 14, height: 1.5,);

  /// The actual question text bubble shown when a student starts answering.
  /// Slightly larger and medium-weight to give the question visual priority.
  static const questionBody = TextStyle(
      color: Color(0xFF1A1A2E), fontSize: 15, height: 1.55,
      fontWeight: FontWeight.w500);

  /// Short acknowledgement messages ("Got it", "Noted", word count confirms).
  /// Muted purple-grey to signal these are system feedback, not questions.
  static const confirmationBody = TextStyle(
      color: Color(0xFF666688), fontSize: 13, height: 1.5,
      fontWeight: FontWeight.bold);

  /// Supplementary hints shown below a question — e.g. word limit reminders,
  /// "show your working" notes, "draw on paper" guidance. Italic to distinguish
  /// them visually from the primary question text.
  static const contextHintBody = TextStyle(
      color: AppColors.textPrimary, fontSize: 13, height: 1.5,
      fontStyle: FontStyle.italic, fontWeight: FontWeight.w600);

  /// Motivational drop messages (the orange encouragement bubbles that appear
  /// after completing a question or at the midpoint). Orange matches the
  /// Smashrite brand's secondary colour (#FF7A00 family).
  static const motivationalBody = TextStyle(
      color: Color(0xFFE65100), fontSize: 13.5, height: 1.55,
      fontWeight: FontWeight.w600);

  /// The intro text at the top of the scan overview bubble — the instruction
  /// paragraph that tells students how many questions they must answer and
  /// whether any are optional.
  static const instructionsBody = TextStyle(
      color: Color(0xFF1A1A2E), fontSize: 14, height: 1.5, fontWeight: FontWeight.bold);

  /// The final "Section complete" or "All done" message inside the dark
  /// blue completion card at the end of the theory section.
  static const completionBody = TextStyle(
      color: Colors.white, fontSize: 14, height: 1.5,
      fontWeight: FontWeight.w600);

  // ── Summary bubble ─────────────────────────────────────────────────────────

  /// Header line of the green summary card shown after each question is
  /// completed — e.g. "Question 1 done ✓". Dark green matches the card colour.
  static const summaryTitle = TextStyle(
      color: Color(0xFF1A4820), fontSize: 14, fontWeight: FontWeight.w700);

  /// The question label inside each summary row — e.g. "1a", "1b". Deep blue
  /// to link visually to the Smashrite primary brand colour.
  static const summaryRowLabel = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F2B6D));

  /// Small pill chips inside each summary row ("Essay ✓", "Photo ✓",
  /// "Answer ✓"). Colour is applied via .copyWith() at the call site.
  static const summaryChipLabel = TextStyle(
      fontSize: 10.5, fontWeight: FontWeight.w600);

  // ── Photo code bubble ──────────────────────────────────────────────────────

  /// The large bold code the student must write on their paper before
  /// photographing — e.g. "ENG/2023/044 · Q1a · 9H2K". Letter-spacing
  /// makes each character easy to read and transcribe.
  static const photoCodePrimary = TextStyle(
      color: Color(0xFF0F2B6D), fontSize: 14.5,
      fontWeight: FontWeight.w800, letterSpacing: 0.5);

  /// The instruction paragraph above the code card — explains what the
  /// student needs to do before taking the photo.
  static const photoCodeSubtext = TextStyle(
      color: AppColors.textPrimary, fontSize: 13, height: 1.5, fontWeight: FontWeight.w600);

  // ── Scan overview question cards ───────────────────────────────────────────

  /// The "Question N" label at the top of each expandable question card in
  /// the scan overview bubble. Deep blue, bold, prominent.
  static const scanCardLabel = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F2B6D));

  /// The secondary meta line ("10 marks · Essay") below the question label.
  /// Small and light; colour applied via .copyWith() at the call site.
  static const scanCardMeta = TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.bold);

  /// The full question text shown when a scan card is expanded. Normal weight,
  /// relaxed line-height for readability in a small card space.
  static const scanCardText = TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.bold);

  // ── Selection hint strip ───────────────────────────────────────────────────

  /// The small status strip at the bottom of the scan overview bubble that
  /// tracks optional-question selection progress — "Select 1 more",
  /// "Selection complete — press Lock & Begin". Colour is applied via
  /// .copyWith() depending on the progress state (orange → green).
  static const selectionHintText = TextStyle(
      fontSize: 12, fontWeight: FontWeight.bold);

  // ── Transition / between-questions bubble ──────────────────────────────────

  /// Viva's text when transitioning between questions — e.g.
  /// "Great work! Which question would you like to answer next?".
  /// Plain body style; question buttons are on the input bar, not here.
  static const transitionBody = TextStyle(
      color: AppColors.textPrimary, fontSize: 15, height: 1.5, fontWeight: FontWeight.w500);

  // ── Student outgoing messages ──────────────────────────────────────────────

  /// The student's typed essay responses and choice selections shown
  /// in the right-aligned student bubbles.
  static const studentBody = TextStyle(
      color: Color(0xFF1A1A2E), fontSize: 14, height: 1.5, fontWeight: FontWeight.bold);

  /// The label inside the photo-captured student bubble —
  /// e.g. "Q3 • photo submitted". Deep blue to match the camera icon.
  static const studentPhoto = TextStyle(
      color: Color(0xFF0F2B6D), fontSize: 13, fontWeight: FontWeight.w600);
}
// ════════════════════════════════════════════════════════════════════════════
// EXAMINER (VIVA) BUBBLE
// ════════════════════════════════════════════════════════════════════════════

class VivaBubble extends StatelessWidget {
  final VivaChatMessage message;
  final List<int> questionsAnswered;
  final List<int> questionsInOrder;
  final Set<int> selectedQuestionIds;
  final void Function(int)? onToggleSelection;
  final void Function(int questionId) onQuestionSelected;
  final VoidCallback onReadyToBegin;
  final VoidCallback onSubmitConfirmed;

  const VivaBubble({
    super.key,
    required this.message,
    required this.questionsAnswered,
    required this.questionsInOrder,
    this.selectedQuestionIds = const {},
    this.onToggleSelection,
    required this.onQuestionSelected,
    required this.onReadyToBegin,
    required this.onSubmitConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _VivaAvatarSmall(variant: message.variant),
          const SizedBox(width: 8),
          Flexible(child: _buildContent(context)),
          const SizedBox(width: 48), // right margin
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (message.variant) {
      VivaMessageVariant.grounding     => _GroundingBubble(message),
      VivaMessageVariant.photoCode     => _PhotoCodeBubble(message),
      VivaMessageVariant.summary       => _SummaryBubble(message),
      VivaMessageVariant.motivational  => _MotivationalBubble(message),
      VivaMessageVariant.completion    => _CompletionBubble(message),
      VivaMessageVariant.transition    => _TransitionBubble(
          message,
          questionsAnswered: questionsAnswered,
          questionsInOrder: questionsInOrder,
          onQuestionSelected: onQuestionSelected,
          onReadyToBegin: onReadyToBegin,
          onSubmitConfirmed: onSubmitConfirmed,
        ),
      VivaMessageVariant.instructions  => _ScanOverviewBubble(
        message,
        selectedQuestionIds: selectedQuestionIds,
        onToggleSelection: onToggleSelection,
      ),
      _                                => _StandardBubble(message),
    };
  }
}

// ── Standard bubble (question text, confirmations, context hints) ─────────────

class _StandardBubble extends StatelessWidget {
  final VivaChatMessage message;
  const _StandardBubble(this.message);

  @override
  Widget build(BuildContext context) {
    return _BubbleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.variant == VivaMessageVariant.subQuestion ||
              message.variant == VivaMessageVariant.question)
            Text(
              message.text,
              style: VivaTypography.questionBody,
            )
          else
            Text(
              message.text,
              style: switch (message.variant) {
                VivaMessageVariant.confirmation => VivaTypography.confirmationBody,
                VivaMessageVariant.contextHint  => VivaTypography.contextHintBody,
                _                               => VivaTypography.standardBody,
              },
            ),
         
        ],
      ),
    );
  }
}

// ── Grounding bubble — opening message, slightly larger ──────────────────────

class _GroundingBubble extends StatelessWidget {
  final VivaChatMessage message;
  const _GroundingBubble(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2B6D), Color(0xFF1A3F9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: _deepBlue.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        message.text,
        style: VivaTypography.groundingBody,
      ),
    );
  }
}

// ── Motivational drop bubble ─────────────────────────────────────────────────

class _MotivationalBubble extends StatelessWidget {
  final VivaChatMessage message;
  const _MotivationalBubble(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: _orange.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('· ', style: TextStyle(color: _orange, fontSize: 18)),
          Expanded(
            child: Text(
              message.text,
              style: VivaTypography.motivationalBody,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo code bubble with countdown ─────────────────────────────────────────

class _PhotoCodeBubble extends StatefulWidget {
  final VivaChatMessage message;
  const _PhotoCodeBubble(this.message);

  @override
  State<_PhotoCodeBubble> createState() => _PhotoCodeBubbleState();
}

class _PhotoCodeBubbleState extends State<_PhotoCodeBubble> {
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    final code = widget.message.photoCode;
    if (code != null) {
      _secondsLeft = code.displaySeconds;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _secondsLeft = (_secondsLeft - 1).clamp(0, code.displaySeconds);
        });
        if (_secondsLeft <= 0) _timer?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.message.photoCode;
    final expired = _secondsLeft <= 0;

    return _BubbleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.text,
            style: VivaTypography.photoCodeSubtext,
          ),
          const SizedBox(height: 14),

          if (code != null) ...[
            // Code display card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _deepBlue.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: expired
                      ? Colors.red.shade300
                      : _deepBlue.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    code.displayText,
                    style: VivaTypography.photoCodePrimary,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        expired
                            ? Icons.timer_off_rounded
                            : Icons.timer_rounded,
                        size: 14,
                        color: expired
                            ? Colors.red.shade400
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        expired
                            ? 'Code visible — take your photo'
                            : '0:${_secondsLeft.toString().padLeft(2, '0')}',
                        style: VivaTypography.selectionHintText.copyWith(
                          color: expired ? Colors.red.shade500 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Text(
              'Write exactly the above on your paper, then photograph it.',
              style: VivaTypography.contextHintBody.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Scan overview bubble ────────────────────────────
class _ScanOverviewBubble extends StatelessWidget {
  final VivaChatMessage message;
  final Set<int> selectedQuestionIds;
  final void Function(int)? onToggleSelection;

  const _ScanOverviewBubble(
    this.message, {
    required this.selectedQuestionIds,
    this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final questions = message.questionChoices ?? [];
    final groups    = message.questionGroups  ?? [];

    final groupedIds = groups.expand((g) => g.questions.map((q) => q.id)).toSet();
    final required   = questions.where((q) => !groupedIds.contains(q.id)).toList();
    final optGroups  = groups.where((g) => g.isOptional).toList();

    return _BubbleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.text,
              style: VivaTypography.instructionsBody
          ),

          // ── Compulsory standalone questions (always answer) ──────────
          if (required.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionLabel('Compulsory — answer all'),
            const SizedBox(height: 6),
            ...required.map((q) => _QuestionScanCard(question: q)),
          ],

          // ── Optional groups (selectable checkboxes) ──────────────────
          for (final group in optGroups) ...[
            const SizedBox(height: 14),
            _SectionLabel(required.isEmpty
                ? 'Choose ${group.requiredCount} of ${group.questions.length} questions to answer'
                : 'Optional — choose ${group.requiredCount} of ${group.questions.length}'),
            const SizedBox(height: 6),
            ...group.questions.map((q) => _QuestionScanCard(
              question: q,
              isSelectable: onToggleSelection != null,
              isSelected: selectedQuestionIds.contains(q.id),
              onToggle: onToggleSelection,
            )),
          ],

          // ── Selection progress hint ───────────────────────────────────
          if (optGroups.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SelectionHint(
              group: optGroups.first,
              selectedCount: selectedQuestionIds.length,
              isLocked: onToggleSelection == null,
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionHint extends StatelessWidget {
  final VivaQuestionGroup group;
  final int selectedCount;
  final bool isLocked;

  const _SelectionHint({
    required this.group,
    required this.selectedCount,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final required  = group.requiredCount ?? 1;
    final remaining = required - selectedCount;
    final done      = selectedCount >= required;

    final (color, bgColor, borderColor, icon, text) = isLocked
        ? (
            Colors.grey.shade600,
            Colors.grey.shade50,
            Colors.grey.shade200,
            Icons.lock_rounded,
            'Selection locked',
          )
        : done
            ? (
                Colors.green.shade700,
                Colors.green.shade50,
                Colors.green.shade200,
                Icons.check_circle_rounded,
                'Selection complete — press "Lock & Begin" below',
              )
            : (
                Colors.orange.shade800,
                Colors.orange.shade50,
                Colors.orange.shade200,
                Icons.touch_app_rounded,
                remaining == required
                    ? 'Tap a question above to select it'
                    : 'Select $remaining more question${remaining > 1 ? 's' : ''}',
              );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: VivaTypography.selectionHintText.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}


//_QuestionScanCard StatefulWidget

class _QuestionScanCard extends StatefulWidget {
  final VivaQuestion question;
  final bool isSelectable;
  final bool isSelected;
  final void Function(int)? onToggle;

  const _QuestionScanCard({
    required this.question,
    this.isSelectable = false,
    this.isSelected   = false,
    this.onToggle,
  });

  @override
  State<_QuestionScanCard> createState() => _QuestionScanCardState();
}

class _QuestionScanCardState extends State<_QuestionScanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? _deepBlue.withOpacity(0.05)
            : _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isSelected ? _deepBlue : Colors.grey.shade200,
          width: widget.isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Checkbox (optional questions only)
                  if (widget.isSelectable) ...[
                    GestureDetector(
                      onTap: () => widget.onToggle?.call(q.id),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          widget.isSelected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: widget.isSelected
                              ? _deepBlue
                              : Colors.grey.shade400,
                          size: 22,
                        ),
                      ),
                    ),
                  ],

                  _TypeIcon(type: q.type),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Question ${q.questionLabel}',
                          style: VivaTypography.scanCardLabel.copyWith(
                                  color: widget.isSelected ? _deepBlue : const Color(0xFF1A1A2E)
                                  ),
                        ),
                        Text(
                          '${q.marks.toInt()} marks · ${_typeLabel(q.type)}',
                          style: VivaTypography.scanCardMeta.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),

                  // Expand/collapse chevron
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded question text ───────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                q.questionText,
                style: VivaTypography.scanCardText.copyWith(color: Colors.grey.shade700),
              ),
            ),
        ],
      ),
    );
  }

  String _typeLabel(VivaQuestionType type) => switch (type) {
    VivaQuestionType.essay       => 'Essay',
    VivaQuestionType.calculation => 'Calculation',
    VivaQuestionType.diagram     => 'Diagram',
    VivaQuestionType.compound    => 'Mixed',
  };
}


// ── Transition bubble (question choice buttons) ───────────────────────────────
class _TransitionBubble extends StatelessWidget {
  final VivaChatMessage message;
  final List<int> questionsAnswered;
  final List<int> questionsInOrder;
  final void Function(int) onQuestionSelected;
  final VoidCallback onReadyToBegin;
  final VoidCallback onSubmitConfirmed;

  const _TransitionBubble(
    this.message, {
    required this.questionsAnswered,
    required this.questionsInOrder,
    required this.onQuestionSelected,
    required this.onReadyToBegin,
    required this.onSubmitConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return _BubbleCard(
      child: Text(
        message.text,
        style: VivaTypography.transitionBody,
      ),
    );
  }
}


// ── Summary bubble (question completion) ─────────────────────────────────────
class _SummaryBubble extends StatelessWidget {
  final VivaChatMessage message;
  const _SummaryBubble(this.message);

  @override
  Widget build(BuildContext context) {
    final parts = message.completedParts ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade600, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.text,
                  style: VivaTypography.summaryTitle.copyWith(color: Colors.green.shade800),
                ),
              ),
            ],
          ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...parts.map((part) => _SummaryRow(part: part)),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final CompletedSubSummary part;
  const _SummaryRow({required this.part});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Wrap(                              // ← was Row
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            part.label,
            style: VivaTypography.summaryRowLabel,
          ),
          if (part.hasText || _isEssay)    _SummaryChip('Essay ✓'),
          if (part.hasFinalAnswer)         _SummaryChip('Answer ✓'),
          if (part.hasPhoto)               _SummaryChip('Photo ✓'),
        ],
      ),
    );
  }

  bool get _isEssay => part.type == VivaQuestionType.essay;
}

class _SummaryChip extends StatelessWidget {
  final String label;
  const _SummaryChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: VivaTypography.summaryChipLabel.copyWith(color: Colors.green.shade800),
      ),
    );
  }
}

// ── Completion bubble ─────────────────────────────────────────────────────────

class _CompletionBubble extends StatelessWidget {
  final VivaChatMessage message;
  const _CompletionBubble(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_deepBlue, const Color(0xFF1A3F9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.text,
              style: VivaTypography.completionBody,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// STUDENT BUBBLE
// ════════════════════════════════════════════════════════════════════════════

class StudentBubble extends StatelessWidget {
  final StudentChatMessage message;
  const StudentBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: message.isPhoto
                ? _buildPhotoBubble()
                : _buildTextBubble(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: message.isChoice
            ? const Color(0xFFE8EDF8)
            : const Color(0xFFDDE4F3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Text(
        message.text,
        style: VivaTypography.studentBody,
      ),
    );
  }



  Widget _buildPhotoBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFDDE4F3),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _deepBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.photo_camera_rounded,
              color: _deepBlue,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            message.text, // "Q3 • photo submitted"
            style: VivaTypography.studentPhoto,
          ),
        ],
      ),
    );
  }





}

// ════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _BubbleCard extends StatelessWidget {
  final Widget child;
  const _BubbleCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _VivaAvatarSmall extends StatelessWidget {
  final VivaMessageVariant variant;
  const _VivaAvatarSmall({required this.variant});

  @override
  Widget build(BuildContext context) {
    if (variant == VivaMessageVariant.motivational) {
      return Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _orange.withOpacity(0.15),
          border: Border.all(color: _orange.withOpacity(0.4)),
        ),
        child: const Text('V',
            style: TextStyle(
                color: _orange,
                fontSize: 11,
                fontWeight: FontWeight.w900)),
      );
    }
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _deepBlue,
      ),
      child: const Text('V',
          style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900)),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final VivaQuestionType type;
  final double size;
  const _TypeIcon({required this.type, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      VivaQuestionType.essay       => (Icons.edit_note_rounded, Colors.blue.shade600),
      VivaQuestionType.calculation => (Icons.calculate_rounded, Colors.purple.shade600),
      VivaQuestionType.diagram     => (Icons.draw_rounded, Colors.teal.shade600),
      VivaQuestionType.compound    => (Icons.layers_rounded, Colors.orange.shade600),
    };

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}



class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2B6D).withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F2B6D),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
