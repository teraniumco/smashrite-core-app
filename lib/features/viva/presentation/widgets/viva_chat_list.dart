// lib/features/viva/presentation/widgets/viva_chat_list.dart

import 'package:flutter/material.dart';
import 'package:smashrite/features/viva/data/models/viva_chat_message.dart';
import 'package:smashrite/features/viva/presentation/widgets/viva_bubble.dart';

class VivaChatList extends StatefulWidget {
  final List<ChatMessage> messages;
  final List<int> questionsAnswered;
  final List<int> questionsInOrder;
  final Set<int> selectedQuestionIds;
  final void Function(int)? onToggleSelection;
  final bool isLoading;
  final void Function(int questionId) onQuestionSelected;
  final VoidCallback onReadyToBegin;
  final VoidCallback onSubmitConfirmed;

  const VivaChatList({
    super.key,
    required this.messages,
    required this.questionsAnswered,
    required this.questionsInOrder,
    this.selectedQuestionIds = const {},
    this.onToggleSelection,
    required this.isLoading,
    required this.onQuestionSelected,
    required this.onReadyToBegin,
    required this.onSubmitConfirmed,
  });

  @override
  State<VivaChatList> createState() => _VivaChatListState();
}

class _VivaChatListState extends State<VivaChatList> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(VivaChatList old) {
    super.didUpdateWidget(old);
    if (widget.messages.length != old.messages.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      itemCount: widget.messages.length + (widget.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading indicator appended at the end
        if (index == widget.messages.length) {
          return const _VivaTypingIndicator();
        }

        final msg = widget.messages[index];

        return switch (msg) {
          VivaChatMessage() => VivaBubble(
            message: msg,
            questionsAnswered: widget.questionsAnswered,
            questionsInOrder: widget.questionsInOrder,
            selectedQuestionIds: widget.selectedQuestionIds,
            onToggleSelection: widget.onToggleSelection,
            onQuestionSelected: widget.onQuestionSelected,
            onReadyToBegin: widget.onReadyToBegin,
            onSubmitConfirmed: widget.onSubmitConfirmed,
          ),
          StudentChatMessage() => StudentBubble(message: msg),
        };
      },
    );
  }
}

// ── Typing indicator — shown when engine is loading ────────────────────────

class _VivaTypingIndicator extends StatefulWidget {
  const _VivaTypingIndicator();

  @override
  State<_VivaTypingIndicator> createState() => _VivaTypingIndicatorState();
}

class _VivaTypingIndicatorState extends State<_VivaTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _VivaAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i * 0.3;
                  final value = ((_controller.value - delay) % 1.0)
                      .clamp(0.0, 1.0);
                  final opacity = value < 0.5
                      ? value * 2
                      : (1 - value) * 2;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: opacity.clamp(0.2, 1.0),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0F2B6D),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Viva avatar widget ─────────────────────────────────────────────────

class _VivaAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF0F2B6D),
      ),
      child: const Text(
        'V',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
