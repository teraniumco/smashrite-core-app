import 'package:flutter/material.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/exam/data/models/exam_session.dart';

class QuestionNavigatorModal extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // FIX #2: Count answered questions more accurately
    final answeredCount = examSession.answers.values
        .where((answer) => 
          (answer.selectedOptions?.isNotEmpty ?? false) || 
          (answer.textAnswer?.isNotEmpty ?? false)
        )
        .length;
    
    final flaggedCount = examSession.flaggedQuestions.length;
    final totalQuestions = examSession.questions.length;
    final unansweredCount = totalQuestions - answeredCount;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Questions Navigator',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Answered',
                  value: answeredCount.toString().padLeft(2, '0'),
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  label: 'Flagged',
                  value: flaggedCount.toString().padLeft(2, '0'),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  label: 'Left',
                  value: unansweredCount.toString().padLeft(2, '0'),
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Question number grid
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: totalQuestions,
              itemBuilder: (context, index) {
                final question = examSession.questions[index];
                
                // Check if question is answered (has valid answer data)
                final answer = examSession.answers[question.id];
                final isAnswered = answer != null && (
                  (answer.selectedOptions?.isNotEmpty ?? false) || 
                  (answer.textAnswer?.isNotEmpty ?? false)
                );
                
                final isFlagged = examSession.flaggedQuestions.contains(question.id);
                final isCurrent = index == currentQuestionIndex;

                return _buildQuestionButton(
                  number: index + 1,
                  isAnswered: isAnswered,
                  isFlagged: isFlagged,
                  isCurrent: isCurrent,
                  onTap: () => onQuestionSelected(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionButton({
    required int number,
    required bool isAnswered,
    required bool isFlagged,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    Color backgroundColor;
    Color textColor;
    
    if (isCurrent) {
      // Current question - dark blue (AppColors.primary)
      backgroundColor = AppColors.primary;
      textColor = Colors.white;
    } else if (isAnswered) {
      // Answered question - light blue (AppColors.primaryLight)
      backgroundColor = AppColors.primaryLight;
      textColor = AppColors.primary;
    } else {
      // Unanswered question - white
      backgroundColor = Colors.white;
      textColor = Colors.black87;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? AppColors.primary : Colors.grey.shade300,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Number
            Center(
              child: Text(
                number.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            
            // Flag indicator
            if (isFlagged)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.flag,
                  size: 14,
                  color: Colors.orange.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
