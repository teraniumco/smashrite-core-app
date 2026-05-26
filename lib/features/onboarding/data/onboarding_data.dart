import 'package:flutter/material.dart';

class OnboardingPage {
  final String title;
  final String body;
  final IconData icon;

  const OnboardingPage({
    required this.title,
    required this.body,
    required this.icon,
  });
}

class OnboardingData {
  static const List<OnboardingPage> pages = [
    OnboardingPage(
      icon: Icons.signal_wifi_off_rounded,
      title: 'Turn off mobile data',
      body:
          'This app works WITHOUT the internet. Turn off mobile data and connect only to the exam hotspot. Ask your digital exam administrator which one to connect to.',
    ),
    OnboardingPage(
      icon: Icons.battery_charging_full_rounded,
      title: 'Charge your phone',
      body:
          'Your battery must be at least 40% to start the exam. If your phone shuts down mid-exam, your session may be lost.',
    ),
    OnboardingPage(
      icon: Icons.security_rounded,
      title: 'Stay in the app',
      body:
          "Leaving/Switching the app during the exam is detected and it's a violation. Keep the app open until you submit.",
    ),
    OnboardingPage(
      icon: Icons.check_circle_rounded,
      title: "You're ready",
      body:
          "Follow the invigilator's instructions. Also report any app issue immediately, rather than trying to solve it yourself.",
    ),
  ];
}