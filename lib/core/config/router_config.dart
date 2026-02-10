import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/features/exam/presentation/exam_screen.dart';
import 'package:smashrite/features/exam/presentation/exam_submitted_screen.dart';
import 'package:smashrite/features/exam/presentation/feedback_survey_screen.dart';
import 'package:smashrite/features/pre_flight/presentation/screens/pre_flight_check_screen.dart';
import 'package:smashrite/features/splash/presentation/splash_screen.dart';
import 'package:smashrite/features/onboarding/presentation/onboarding_screen.dart';
import 'package:smashrite/features/server_connection/presentation/server_connection_screen.dart';
import 'package:smashrite/features/server_connection/presentation/qr_scanner_screen.dart';
import 'package:smashrite/features/server_connection/presentation/auto_discover_screen.dart';
import 'package:smashrite/features/server_connection/presentation/manual_entry_screen.dart';
import 'package:smashrite/features/auth/presentation/login_screen.dart';
import 'package:smashrite/features/exam/presentation/exam_lobby_screen.dart';
import 'package:smashrite/features/security/presentation/security_violation_screen.dart';
import 'package:smashrite/features/security/presentation/device_mismatch_screen.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/features/app_version/presentation/screens/app_version_check_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // Splash Screen
      GoRoute(
        path: '/',
        name: 'splash',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      ),

      // Onboarding Screen
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      ),

      // Login Screen
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        ),
      ),


      // Dashboard/Exam Lobby Screen
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ExamLobbyScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      ),

      GoRoute(
        path: '/exam',
        builder: (context, state) => const ExamScreen(),
      ),
            
      GoRoute(
        path: '/exam-submitted',
        builder: (context, state) => const ExamSubmittedScreen(),
      ),

      // Server Connection Main Screen
      GoRoute(
        path: '/server-connection',
        name: 'server-connection',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ServerConnectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      ),

      // QR Scanner Screen
      GoRoute(
        path: '/server-connection/qr-scanner',
        name: 'qr-scanner',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const QRScannerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        ),
      ),

      // Auto-Discover Screen
      GoRoute(
        path: '/server-connection/auto-discover',
        name: 'auto-discover',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AutoDiscoverScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        ),
      ),

      // Manual Entry Screen
      GoRoute(
        path: '/server-connection/manual-entry',
        name: 'manual-entry',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ManualEntryScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        ),
      ),

      GoRoute(
        path: '/security-violation',
        builder: (context, state) {
          final violation = state.extra as SecurityViolation?;
          if (violation == null) {
            return const Scaffold(
              body: Center(child: Text('No violation data')),
            );
          }
          return SecurityViolationScreen(violation: violation);
        },
      ),

      GoRoute(
        path: '/device-mismatch',
        builder: (context, state) => const DeviceMismatchScreen(),
      ),

      GoRoute(
        path: '/feedback-survey',
        builder: (context, state) => const FeedbackSurveyScreen(),
      ),

      GoRoute(
        path: '/pre-flight-check',
        builder: (context, state) => const PreFlightCheckScreen(),
      ),

      GoRoute(
        path: '/app-version-check',
        builder: (context, state) => AppVersionCheckScreen(
          requiredVersion: state.extra as String,
        ),
      ),

    ],

    // Error handling
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
