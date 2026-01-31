import 'package:flutter/material.dart';

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final List<ChecklistItem>? checklist;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    this.checklist,
  });
}

class ChecklistItem {
  final IconData icon;
  final String title;
  final String description;

  const ChecklistItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class OnboardingData {
  static final List<OnboardingPage> pages = [
    const OnboardingPage(
      title: 'Take Your Exam on Your Device',
      description:
          'Smashrite lets you write exams securely on your phone or tablet without internet access.',
      icon: Icons.phone_android_rounded,
    ),
    const OnboardingPage(
      title: 'No Internet Needed',
      description:
          'Your exam runs on a secure local network. Answers are saved automatically even if connection drops.',
      icon: Icons.wifi_off_rounded,
    ),
    const OnboardingPage(
      title: 'Exam Rules Apply',
      description:
          'Switching apps, screenshots, or screen recording may be detected during the exam. This leads to violations and possible auto-submission.',
      icon: Icons.verified_user_rounded,
    ),
    OnboardingPage(
      title: 'You\'re Almost Ready',
      description: 'Please ensure you have the following ready before starting:',
      icon: Icons.celebration_rounded,
      checklist: [
        const ChecklistItem(
          icon: Icons.battery_charging_full_rounded,
          title: 'Battery charged:',
          description:
              'Please ensure your device is at least 80% charged to avoid interruptions.',
        ),
        const ChecklistItem(
          icon: Icons.vpn_key_rounded,
          title: 'Access code ready:',
          description: 'Have your access code available as you\'ll need it to login.',
        ),
        const ChecklistItem(
          icon: Icons.wifi_off_rounded, 
          title: 'No internet connection:',
          description: 'Make sure this device is NOT connected to the internet.',
        ),
      ],
    ),
  ];
}
