import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/onboarding/data/onboarding_data.dart';
import 'package:smashrite/features/onboarding/widgets/onboarding_page_widget.dart';
import 'package:smashrite/features/onboarding/widgets/page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _skipOnboarding() async {
    // Mark onboarding as completed
    await StorageService.save(AppConstants.isFirstLaunch, false);

    if (!mounted) return;

    // Navigate to server connection screen
    context.go('/server-connection');
  }

  Future<void> _continueToConnect() async {
    // Mark onboarding as completed
    await StorageService.save(AppConstants.isFirstLaunch, false);

    if (!mounted) return;

    // Navigate to server connection screen
    context.go('/server-connection');
  }

  void _nextPage() {
    if (_currentPage < OnboardingData.pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == OnboardingData.pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            if (!isLastPage)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      'Skip',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 20
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 56), // Match height when Skip is shown
            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PageIndicator(
                currentPage: _currentPage,
                pageCount: OnboardingData.pages.length,
              ),
            ),

            const SizedBox(height: 40),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: OnboardingData.pages.length,
                itemBuilder: (context, index) {
                  return OnboardingPageWidget(
                    page: OnboardingData.pages[index],
                    isLastPage: index == OnboardingData.pages.length - 1,
                  );
                },
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLastPage ? _continueToConnect : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A), // Dark blue
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isLastPage ? 'Connect to Server' : 'Next',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
