import 'package:flutter/material.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/exam/data/models/exam_session.dart';

class QuestionNavigatorModal extends StatefulWidget {
  final ExamSession examSession;
  final int currentQuestionIndex;
  final Function(int) onQuestionSelected;

  const QuestionNavigatorModal({
    super.key,
    required this.examSession,
    required this.currentQuestionIndex,
    required this.onQuestionSelected,
  });

  @override
  State<QuestionNavigatorModal> createState() => _QuestionNavigatorModalState();
}

class _QuestionNavigatorModalState extends State<QuestionNavigatorModal> {
  static const _deepBlue = Color(0xFF0F2B6D);
  static const _orange   = Color(0xFFFF7A00);

  bool _showFlaggedOnly = false;

  @override
  Widget build(BuildContext context) {
    final answeredCount = widget.examSession.answers.values
        .where((a) =>
            (a.selectedOptions?.isNotEmpty ?? false) ||
            (a.textAnswer?.isNotEmpty ?? false))
        .length;
    final flaggedCount    = widget.examSession.flaggedQuestions.length;
    final totalQuestions  = widget.examSession.questions.length;
    final unansweredCount = totalQuestions - answeredCount;

    // Build indexed list so original question numbers are preserved when filtering
    final allEntries = widget.examSession.questions.asMap().entries.toList();
    final displayEntries = _showFlaggedOnly
        ? allEntries
            .where((e) =>
                widget.examSession.flaggedQuestions.contains(e.value.id))
            .toList()
        : allEntries;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF3F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _deepBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.grid_view_rounded,
                    color: _deepBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Question Navigator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                      size: 17, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),

          // ── Stat cards ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Answered',
                    value: answeredCount,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 10),
                // Flagged card is the filter trigger
                Expanded(
                  child: _StatCard(
                    label: 'Flagged',
                    value: flaggedCount,
                    color: _orange,
                    isFilterActive: _showFlaggedOnly,
                    isFilterable: flaggedCount > 0,
                    onTap: flaggedCount > 0
                        ? () => setState(
                            () => _showFlaggedOnly = !_showFlaggedOnly)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Unanswered',
                    value: unansweredCount,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // ── Active filter banner ──────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _showFlaggedOnly
                ? Padding(
                    key: const ValueKey('filter_banner'),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flag_rounded,
                                size: 13, color: _orange),
                              const SizedBox(width: 5),
                              Text(
                                'Showing $flaggedCount flagged '
                                '${flaggedCount == 1 ? 'question' : 'questions'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showFlaggedOnly = false),
                          child: Text(
                            'Show all questions',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no_banner')),
          ),

          // ── Grid card ─────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: displayEntries.isEmpty
                ? _buildEmptyState()
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.44,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: displayEntries.length,
                        itemBuilder: (context, i) {
                          final entry         = displayEntries[i];
                          final question      = entry.value;
                          final originalIndex = entry.key;
                          final answer = widget.examSession.answers[question.id];
                          final isAnswered = answer != null &&
                              ((answer.selectedOptions?.isNotEmpty ?? false) ||
                                  (answer.textAnswer?.isNotEmpty ?? false));
                          final isFlagged = widget.examSession
                              .flaggedQuestions
                              .contains(question.id);
                          final isCurrent =
                              originalIndex == widget.currentQuestionIndex;

                          return _QuestionCell(
                            number: originalIndex + 1,
                            isAnswered: isAnswered,
                            isFlagged: isFlagged,
                            isCurrent: isCurrent,
                            onTap: () =>
                                widget.onQuestionSelected(originalIndex),
                          );
                        },
                      ),
                    ),
                  ),
          ),

          SafeArea(top: false, child: const SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.flag_outlined, size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No flagged questions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use the flag button on any question to mark it for review.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool isFilterable;
  final bool isFilterActive;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.isFilterable  = false,
    this.isFilterActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isFilterActive ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFilterActive
                ? color.withOpacity(0.4)
                : Colors.grey.shade200,
            width: isFilterActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 6, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (isFilterable) ...[
                  const SizedBox(width: 3),
                  Icon(
                    isFilterActive
                        ? Icons.filter_alt_rounded
                        : Icons.filter_alt_outlined,
                    size: 11,
                    color: isFilterActive ? color : Colors.grey.shade400,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Question cell ─────────────────────────────────────────────────────────────

class _QuestionCell extends StatelessWidget {
  final int number;
  final bool isAnswered;
  final bool isFlagged;
  final bool isCurrent;
  final VoidCallback onTap;

  static const _deepBlue = Color(0xFF0F2B6D);

  const _QuestionCell({
    required this.number,
    required this.isAnswered,
    required this.isFlagged,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final Color borderColor;

    if (isCurrent) {
      bgColor     = _deepBlue;
      textColor   = Colors.white;
      borderColor = _deepBlue;
    } else if (isAnswered) {
      bgColor     = _deepBlue.withOpacity(0.08);
      textColor   = _deepBlue;
      borderColor = _deepBlue.withOpacity(0.2);
    } else {
      bgColor     = Colors.white;
      textColor   = Colors.grey.shade700;
      borderColor = Colors.grey.shade200;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor, width: isCurrent ? 2 : 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                number.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            if (isFlagged)
              Positioned(
                top: 3, right: 3,
                child: Icon(Icons.flag_rounded,
                  size: 11, color: Colors.orange.shade600),
              ),
          ],
        ),
      ),
    );
  }
}