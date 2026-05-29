// lib/features/viva/presentation/widgets/viva_input_bar.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/viva/data/models/viva_chat_message.dart';
import 'package:smashrite/features/viva/data/models/viva_engine_state.dart';
import 'package:smashrite/features/viva/presentation/screens/viva_camera_screen.dart';

const _deepBlue = Color(0xFF0F2B6D);
const _orange   = Color(0xFFFF7A00);
const _surface  = Color(0xFFF3F5F9);

class VivaInputBar extends StatefulWidget {
  final VivaEngineState state;
  final void Function(StudentAction) onAction;
  final void Function(Uint8List bytes) onPhotoCaptured;
  final void Function(String reason) onPhotoAborted;
  final void Function(int questionId) onToggleSelection;

  const VivaInputBar({
    super.key,
    required this.state,
    required this.onAction,
    required this.onPhotoCaptured,
    required this.onPhotoAborted,
    required this.onToggleSelection,
  });

  @override
  State<VivaInputBar> createState() => _VivaInputBarState();
}

class _VivaInputBarState extends State<VivaInputBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _textController.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    if (words != _wordCount) setState(() => _wordCount = words);
  }

  void _clearText() {
    _textController.clear();
    setState(() => _wordCount = 0);
  }

  @override
  void didUpdateWidget(VivaInputBar old) {
    super.didUpdateWidget(old);
    // Clear text when input mode changes (new question/step)
    if (old.state.inputMode != widget.state.inputMode) {
      _clearText();
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.state.inputMode;

    if (mode == InputMode.none || widget.state.isSubmitted) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: _buildContent(mode),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(InputMode mode) {
    return switch (mode) {
      InputMode.readOnly      => _buildReadyButton(),
      InputMode.choiceButtons => _buildChoiceButtons(),
      InputMode.essayText     => _buildEssayInput(),
      InputMode.workingNotes  => _buildWorkingNotesInput(),
      InputMode.finalAnswer   => _buildFinalAnswerInput(),
      InputMode.cameraCapture => _buildCameraButton(),
      InputMode.submitConfirm => _buildSubmitButton(),
      InputMode.selection     => _buildSelectionFooter(),
      _                       => const SizedBox.shrink(),
    };
  }

  // ── Ready to begin ────────────────────────────────────────────────────────

  Widget _buildReadyButton() {
    return SizedBox(
      width: double.infinity,
      child: _PrimaryButton(
        label: "I'm ready — Let's begin",
        icon: Icons.play_arrow_rounded,
        onTap: () => widget.onAction(const ReadyToBegin()),
      ),
    );
  }

  // ── Question choice buttons ───────────────────────────────────────────────

  Widget _buildChoiceButtons() {
    final choices = widget.state.allRootQuestions
        .where((q) => widget.state.questionsRemaining.contains(q.id))
        .toList();

    if (choices.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...choices.map((q) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => widget.onAction(QuestionSelected(q.id)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _deepBlue,
                side: BorderSide(color: _deepBlue.withOpacity(0.35)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                children: [
                  Text(
                    'Question ${q.questionLabel}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${q.marks} marks',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: _deepBlue),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  // ── Essay input ───────────────────────────────────────────────────────────

  Widget _buildEssayInput() {
    final q = widget.state.currentSubQuestion ?? widget.state.currentQuestion;
    final minWords = q?.minWords;
    final maxWords = q?.maxWords;
    final meetsMin = minWords == null || _wordCount >= minWords;
    final overMax  = maxWords != null && _wordCount > maxWords;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Word count row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              minWords != null
                  ? 'Min $minWords words'
                  : 'No minimum words',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '$_wordCount${maxWords != null ? ' / $maxWords' : ''} words',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: overMax
                    ? Colors.red.shade500
                    : meetsMin && _wordCount > 0
                        ? Colors.green.shade600
                        : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Text field
        Container(
          constraints: const BoxConstraints(minHeight: 100, maxHeight: 200),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: overMax
                  ? Colors.red.shade300
                  : Colors.grey.shade200,
            ),
          ),
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Type your response here…',
              hintStyle: TextStyle(color: AppColors.textPrimary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Submit row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (overMax)
              Text(
                'Over word limit',
                style: TextStyle(
                  color: Colors.red.shade500,
                  fontSize: 12,
                ),
              ),
            const Spacer(),
            _PrimaryButton(
              label: 'Send Response',
              icon: Icons.send_rounded,
              enabled: _wordCount > 0 && !overMax,
              onTap: () {
                final text = _textController.text.trim();
                if (text.isEmpty) return;
                widget.onAction(EssaySubmitted(text));
                _clearText();
              },
            ),
          ],
        ),
      ],
    );
  }

  // ── Working notes input (optional) ───────────────────────────────────────

  Widget _buildWorkingNotesInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 72, maxHeight: 120),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Working notes (optional)…',
              hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton(
              onPressed: () => widget.onAction(const WorkingNotesSkipped()),
              child: Text(
                'Skip notes',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            _PrimaryButton(
              label: 'Save Notes →',
              icon: Icons.edit_note_rounded,
              enabled: _wordCount > 0,
              onTap: () {
                final text = _textController.text.trim();
                widget.onAction(WorkingNotesSubmitted(text));
                _clearText();
              },
            ),
          ],
        ),
      ],
    );
  }

  // ── Final answer input ────────────────────────────────────────────────────

  Widget _buildFinalAnswerInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: 1,
            decoration: const InputDecoration(
              hintText: 'Final answer with units…',
              hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              if (value.trim().isEmpty) return;
              widget.onAction(FinalAnswerSubmitted(value.trim()));
              _clearText();
            },
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: _PrimaryButton(
            label: 'Submit Answer',
            icon: Icons.check_rounded,
            enabled: _wordCount > 0,
            onTap: () {
              final text = _textController.text.trim();
              if (text.isEmpty) return;
              widget.onAction(FinalAnswerSubmitted(text));
              _clearText();
            },
          ),
        ),
      ],
    );
  }

  // ── Camera capture button ─────────────────────────────────────────────────

  Widget _buildCameraButton() {
    final code   = widget.state.activePhotoCode;
    final isLoading = widget.state.isLoading || widget.state.isUploading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (code != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _deepBlue.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _deepBlue.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: _deepBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Code on paper: ${code.displayText}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _deepBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading || code == null
                ? null
                : () => _openCamera(code),
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : const Icon(Icons.camera_alt_rounded, size: 20),
            label: Text(
              isLoading ? 'Processing…' : 'Open Camera',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _deepBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),

        if (code != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                widget.onPhotoAborted('student_aborted'),
            child: Text(
              'Generate new code',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openCamera(dynamic code) async {
    final bytes = await VivaCameraScreen.capture(
      context,
      questionLabel: code.questionLabel as String,
      displayCode: code.displayText as String,
      code: code.code as String,
    );

    if (bytes != null) {
      widget.onPhotoCaptured(bytes);
    } else {
      // Student cancelled — abort and regenerate code
      widget.onPhotoAborted('student_cancelled_camera');
    }
  }

  // ── Submit confirmation ───────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'All questions answered. Submit when ready.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => widget.onAction(const SubmitConfirmed()),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text(
              'Submit Theory Section',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _deepBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ── Optional selection footer ─────────────────────────────────────────────
  Widget _buildSelectionFooter() {
    final selected = widget.state.selectedQuestionIds;
    final group    = widget.state.questionGroups
        .where((g) => g.isOptional)
        .firstOrNull;

    if (group == null) return const SizedBox.shrink();

    final required  = group.requiredCount ?? 1;
    final isReady   = selected.length >= required;
    final remaining = required - selected.length;

    return SizedBox(
      width: double.infinity,
      child: _PrimaryButton(
        label: isReady
            ? 'Lock Selection & Begin'
            : 'Select $remaining more question${remaining > 1 ? 's' : ''} above ↑',
        icon: isReady ? Icons.lock_rounded : Icons.touch_app_rounded,
        enabled: isReady,
        onTap: () => widget.onAction(QuestionsLocked(
          groupId: group.id,
          selectedQuestionIds: selected.toList(),
        )),
      ),
    );
  }


}

// ── Shared button widget ──────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _deepBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade200,
        disabledForegroundColor: Colors.grey.shade400,
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 11),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}
