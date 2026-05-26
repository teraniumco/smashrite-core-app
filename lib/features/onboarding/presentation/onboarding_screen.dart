import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/onboarding/data/onboarding_data.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Brand colours
  static const _deepBlue = Color(0xFF0F2B6D);
  static const _orange = Color(0xFFFF7A00);

  // Per-slide accent tints  [bg circle, icon colour]
  static const _palette = [
    [Color(0xFFE3EDF9), Color(0xFF1565C0)], // battery – blue
    [Color(0xFFE3EDF9), Color(0xFF1565C0)], // wifi – green
    [Color(0xFFE3EDF9), Color(0xFF1565C0)], // shield – deep orange
    [Color(0xFFE3EDF9), Color(0xFF1565C0)], // tick – dark green
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) => setState(() => _currentPage = page);

  void _advance() {
    final pages = OnboardingData.pages;
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    if (!mounted) return;
    context.go('/wifi-connect');
  }

  @override
  Widget build(BuildContext context) {
    final pages = OnboardingData.pages;
    final isLast = _currentPage == pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentPage + 1} of ${pages.length}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!isLast)
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: _deepBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40), // keep layout balanced
                ],
              ),
            ),

            // ── Progress dots ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          i == _currentPage ? _deepBlue : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // ── Slides ───────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingSlide(
                    page: pages[index],
                    bgColor: _palette[index][0],
                    iconColor: _palette[index][1],
                  );
                },
              ),
            ),

            // ── CTA button ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _advance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLast ? _orange : _deepBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isLast ? "I'm Ready" : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private slide widget ──────────────────────────────────────────────────────

class _OnboardingSlide extends StatelessWidget {
  final OnboardingPage page;
  final Color bgColor;
  final Color iconColor;

  const _OnboardingSlide({
    required this.page,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon bubble
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(page.icon, size: 76, color: iconColor),
          ),

          const SizedBox(height: 44),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F2B6D),
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          // Body
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: AppColors.textPrimary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}