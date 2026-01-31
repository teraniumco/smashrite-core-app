import 'package:flutter/material.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/onboarding/data/onboarding_data.dart';

class OnboardingPageWidget extends StatelessWidget {
  final OnboardingPage page;
  final bool isLastPage;

  const OnboardingPageWidget({
    super.key,
    required this.page,
    required this.isLastPage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 60),

          // Icon circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6), // Light blue-gray
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 80, color: AppColors.textPrimary),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
              fontSize: 17
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Checklist (only for last page)
          if (isLastPage && page.checklist != null)
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7), // Light yellow
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFCD34D), // Yellow border
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children:
                        page.checklist!
                            .map((item) => _buildChecklistItem(context, item))
                            .toList(),
                  ),
                ),
              ),
            ),

          if (!isLastPage) const Spacer(),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(BuildContext context, ChecklistItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: const Color(0xFFD97706), // Amber
            ),
          ),

          const SizedBox(width: 12),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
