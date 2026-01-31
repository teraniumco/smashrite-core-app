import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeApp();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: AppConstants.fadeInDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize storage service
      await StorageService.init();

      // Wait for splash duration
      await Future.delayed(AppConstants.splashDuration);

      if (!mounted) return;

      // Check first launch status
      final isFirstLaunch = StorageService.get<bool>(
        AppConstants.isFirstLaunch,
        defaultValue: true,
      );

      // Check if user has connected to any exam server
      final hasConnectedToServer = StorageService.get<bool>(
        AppConstants.hasConnectedToServer,
        defaultValue: false,
      );

      // Check authentication status
      final accessToken = StorageService.get<String>(AppConstants.accessToken);
      final isAuthenticated = accessToken != null && accessToken.isNotEmpty;

      // Navigation logic
      if (isFirstLaunch == true || !hasConnectedToServer!) {
        // First time user or never connected to server -> Onboarding
        context.go('/onboarding');
      } else if (!isAuthenticated) {
        // Not authenticated -> Login
        context.go('/login');
      } else {
        // Authenticated -> Dashboard
        context.go('/dashboard');
      }
    } catch (e) {
      // Handle initialization errors
      debugPrint('Splash screen error: $e');
      if (mounted) {
        // On error, go to onboarding as safe fallback
        context.go('/onboarding');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/smashrite-logomark.png',
                width: 100,
              ),
              const SizedBox(height: 15),
              // Tagline
              const Text(
                "Smashrite",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 5),
              // Tagline
              const Text(
                "Smarter testing for smarter institutions",
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
