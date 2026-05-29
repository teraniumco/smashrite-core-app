// lib/features/viva/presentation/screens/viva_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/exam/data/providers/exam_provider.dart';
import 'package:smashrite/features/viva/data/models/viva_chat_message.dart';
import 'package:smashrite/features/viva/data/models/viva_engine_state.dart';
import 'package:smashrite/features/viva/data/providers/viva_provider.dart';
import 'package:smashrite/features/viva/presentation/widgets/viva_chat_list.dart';
import 'package:smashrite/features/viva/presentation/widgets/viva_input_bar.dart';

class VivaScreen extends ConsumerStatefulWidget {
  /// The subjective section ID to initialise or resume.
  final int sectionId;

  const VivaScreen({super.key, required this.sectionId});

  @override
  ConsumerState<VivaScreen> createState() => _VivaScreenState();
}

class _VivaScreenState extends ConsumerState<VivaScreen> {
  static const _deepBlue = Color(0xFF0F2B6D);
  static const _orange   = Color(0xFFFF7A00);
  static const _surface  = Color(0xFFF3F5F9);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initViva());
  }

  Future<void> _initViva() async {
    if (!mounted) return;

    final current = ref.read(vivaProvider);

    // Already loaded successfully for this section — skip
    if (current != null &&
        current.section?.id == widget.sectionId &&
        current.errorMessage == null &&
        !current.isLoading) {
      return;
    }

    // A request is already in flight — don't double-fire
    if (current?.isLoading == true) return;

    await ref.read(vivaProvider.notifier).initSection(widget.sectionId);
  }

  Future<bool> _onWillPop() async {
    final state = ref.read(vivaProvider);
    if (state?.isSubmitted == true) {
      if (mounted) context.pop();
      return false;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFF0F2B6D)),
            SizedBox(width: 8),
            Text('Return to Objective?'),
          ],
        ),
        content: const Text(
          'Your subjective progress is saved. You can return to this section at any time.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay here'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _deepBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Return to Objective'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.pop();
    }
    return false;
  }

  void _returnToObjective() => _onWillPop();

  @override
  Widget build(BuildContext context) {
    final vivaState = ref.watch(vivaProvider);
    final examSession = ref.watch(examProvider);
    final timeRemaining = ref.watch(timeRemainingProvider);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: _buildAppBar(vivaState, timeRemaining),
        body: vivaState == null
            ? _buildInitialLoading()
            : vivaState.errorMessage != null
                ? _buildError(vivaState.errorMessage!)
                : _buildBody(vivaState),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    VivaEngineState? state,
    Duration? timeRemaining,
  ) {
    return AppBar(
      backgroundColor: _deepBlue,
      elevation: 0,
      leading: _BackToObjectiveButton(onTap: _returnToObjective),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state?.section?.title ?? 'Subjective',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (state != null && !state.isSubmitted)
            _buildProgressSubtitle(state),
        ],
      ),
      actions: [
        if (timeRemaining != null) _buildTimer(timeRemaining),
        const SizedBox(width: 12),
      ],
      bottom: state != null && (state.isLoading || state.isUploading)
          ? PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withOpacity(0.2),
                color: _orange,
              ),
            )
          : null,
    );
  }

  Widget _buildProgressSubtitle(VivaEngineState state) {
    final answered = state.questionsAnswered.length;
    // questionsOrder + questionsRemaining = all questions in this session
    // regardless of whether any have been started, answered, or are still pending
    final total = state.questionsOrder.length + state.questionsRemaining.length;

    if (total == 0) return const SizedBox.shrink();

    return Text(
      '$answered of $total question${total > 1 ? 's' : ''} answered',
      style: TextStyle(
        color: Colors.white.withOpacity(0.65),
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTimer(Duration remaining) {
    final isWarning = remaining.inMinutes <= 5;
    final mm = remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isWarning
            ? Colors.red.withOpacity(0.2)
            : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_rounded,
            color: isWarning ? Colors.red.shade200 : Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$mm:$ss',
            style: TextStyle(
              color: isWarning ? Colors.red.shade200 : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(VivaEngineState state) {
    return Column(
      children: [
        // Upload status banner
        if (state.isUploading) _buildUploadBanner(),

        // Chat history
        Expanded(
          child: VivaChatList(
            messages: state.chatHistory,
            questionsAnswered: state.questionsAnswered,
            questionsInOrder: state.questionsOrder,
            // Pass selection only while in selection mode — null locks the checkboxes
            selectedQuestionIds: state.selectedQuestionIds,
            onToggleSelection: state.inputMode == InputMode.selection
                ? (id) => ref.read(vivaProvider.notifier).toggleQuestionSelection(id)
                : null,
            isLoading: state.isLoading,
            onQuestionSelected: (id) => ref
                .read(vivaProvider.notifier)
                .onAction(QuestionSelected(id)),
            onReadyToBegin: () => ref
                .read(vivaProvider.notifier)
                .onAction(const ReadyToBegin()),
            onSubmitConfirmed: () => ref
                .read(vivaProvider.notifier)
                .onAction(const SubmitConfirmed()),
          ),
        ),

        // Dynamic input bar
        VivaInputBar(
          state: state,
          onAction: (action) =>
              ref.read(vivaProvider.notifier).onAction(action),
          onPhotoCaptured: (bytes) =>
              ref.read(vivaProvider.notifier).onPhotoCaptured(bytes),
          onPhotoAborted: (reason) =>
              ref.read(vivaProvider.notifier).onPhotoAborted(reason: reason),
          onToggleSelection: (id) =>
              ref.read(vivaProvider.notifier).toggleQuestionSelection(id),
        ),
      ],
    );
  }

  Widget _buildUploadBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _orange.withOpacity(0.1),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _orange,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Uploading photo to exam server…',
            style: TextStyle(
              fontSize: 12.5,
              color: _orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _deepBlue),
          const SizedBox(height: 20),
          Text(
            'Loading subjective section…',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 52, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text(
              'Could not load subjective section',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _deepBlue),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(vivaProvider.notifier).clearError();
                _initViva();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _deepBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Back to Objective button ──────────────────────────────────────────────────

class _BackToObjectiveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackToObjectiveButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ),
      ),
    );
  }
}



