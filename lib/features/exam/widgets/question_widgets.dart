import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/exam/data/models/question.dart';
import 'package:smashrite/features/exam/data/providers/exam_provider.dart';

/// Single Choice Question (Radio buttons - only one answer)
class SingleChoiceQuestion extends ConsumerWidget {
  final Question question;

  const SingleChoiceQuestion({
    super.key,
    required this.question,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedAnswer = ref.watch(
      examProvider.select((session) => 
        session?.answers[question.id]?.selectedOptions.firstOrNull
      ),
    );

    return Column(
      children: question.options.map((option) {
        final isSelected = selectedAnswer == option.id;
        
        return GestureDetector(
          onTap: () {
            ref.read(examProvider.notifier).saveAnswer(
              questionId: question.id,
              selectedOptions: [option.id],
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
            ),
            child: Row(
              children: [
                // Custom circular radio button with check icon
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.primary : Colors.white,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Option text
                Expanded(
                  child: Text(
                    option.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      // fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Multiple Choice Question (Checkboxes - multiple answers allowed)
class MultipleChoiceQuestion extends ConsumerWidget {
  final Question question;

  const MultipleChoiceQuestion({
    super.key,
    required this.question,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedAnswers = ref.watch(
      examProvider.select((session) => 
        session?.answers[question.id]?.selectedOptions ?? []
      ),
    );

    return Column(
      children: question.options.map((option) {
        final isSelected = selectedAnswers.contains(option.id);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (bool? checked) {
              if (checked == true) {
                // Add to selected
                ref.read(examProvider.notifier).saveAnswer(
                  questionId: question.id,
                  selectedOptions: [...selectedAnswers, option.id],
                );
              } else {
                // Remove from selected
                ref.read(examProvider.notifier).saveAnswer(
                  questionId: question.id,
                  selectedOptions: selectedAnswers.where((id) => id != option.id).toList(),
                );
              }
            },
            title: Text(
              option.text,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                // fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                fontWeight: FontWeight.bold,
              ),
            ),
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      }).toList(),
    );
  }
}

/// True/False Question (Two radio options)
class TrueFalseQuestion extends ConsumerWidget {
  final Question question;

  const TrueFalseQuestion({
    super.key,
    required this.question,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedAnswer = ref.watch(
      examProvider.select((session) => 
        session?.answers[question.id]?.selectedOptions.firstOrNull
      ),
    );

    // Get True and False options from the question options
    // Backend provides options like: [{id: '9', text: 'True'}, {id: '10', text: 'False'}]
    final trueOption = question.options.firstWhere(
      (opt) => opt.text.toLowerCase() == 'true',
      orElse: () => question.options.first,
    );
    
    final falseOption = question.options.firstWhere(
      (opt) => opt.text.toLowerCase() == 'false',
      orElse: () => question.options.last,
    );

    return Column(
      children: [
        _buildOption(
          ref: ref,
          value: trueOption.id,
          label: trueOption.text,
          isSelected: selectedAnswer == trueOption.id,
        ),
        const SizedBox(height: 12),
        _buildOption(
          ref: ref,
          value: falseOption.id,
          label: falseOption.text,
          isSelected: selectedAnswer == falseOption.id,
        ),
      ],
    );
  }

  Widget _buildOption({
    required WidgetRef ref,
    required String value,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(examProvider.notifier).saveAnswer(
          questionId: question.id,
          selectedOptions: [value],
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          children: [
            // Custom circular radio button with check icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.white,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Option text
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                // fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fill-in-the-Blank Question (Text input with debouncing)
class FillInBlankQuestion extends ConsumerStatefulWidget {
  final Question question;

  const FillInBlankQuestion({
    super.key,
    required this.question,
  });

  @override
  ConsumerState<FillInBlankQuestion> createState() => _FillInBlankQuestionState();
}

class _FillInBlankQuestionState extends ConsumerState<FillInBlankQuestion> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    
    // Load existing answer if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existingAnswer = ref.read(
        examProvider.select((session) => 
          session?.answers[widget.question.id]?.textAnswer
        ),
      );
      if (existingAnswer != null) {
        _controller.text = existingAnswer;
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Start new timer (wait 500ms after user stops typing)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      // Save answer after debounce
      ref.read(examProvider.notifier).saveAnswer(
        questionId: widget.question.id,
        textAnswer: value,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: TextField(
        controller: _controller,
        maxLines: 1,
        decoration: InputDecoration(
          hintText: 'Type your answer here...',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
        ),
        onChanged: _onTextChanged, // Use debounced handler
      ),
    );
  }
}

