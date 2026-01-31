import 'package:flutter/material.dart';
import 'package:smashrite/core/theme/app_theme.dart';

class ViolationAlertModal extends StatelessWidget {
  final String? violationType;
  final int violationCount;
  final VoidCallback onDismiss;

  const ViolationAlertModal({
    super.key,
    required this.violationType,
    required this.violationCount,
    required this.onDismiss,
  });

  String _getViolationTitle() {
    switch (violationType) {
      case 'app_switch':
        return 'App Switch Detected';
      case 'screenshot':
        return 'Screenshot Detected'; 
      case 'screen_recording':
        return 'Screen Recording Detected';
      case 'internet':
        return 'Internet Connection Detected';
      case 'external_internet':
        return 'Internet Connection Detected';
      case 'paste':
        return 'Paste Attempt Detected';
      default:
        return 'Violation Alert';
    }
  }

  String _getViolationMessage() {
    switch (violationType) {
      case 'app_switch':
        return 'You switched to another app. This behaviour violates exam rules. Repeat actions may lead to auto submission.';
      case 'screenshot':
        return 'A screenshot was detected. This behaviour violates exam rules and has been logged. Repeat actions may lead to auto submission.'; 
      case 'screen_recording':
        return 'Screen recording was detected. This behaviour violates exam rules and has been logged. Repeat actions may lead to auto submission.';
      case 'internet':
        return 'Internet connection detected! You must turn off mobile data. This exam requires offline mode only. Repeat actions may lead to auto submission.';
      case 'external_internet':
        return 'Internet connection detected! You must turn off internet access on your WiFi to continue your exam. This exam requires offline mode only. Repeat actions may lead to auto submission.';
      case 'paste':
        return 'A paste attempt was detected. This behaviour violates exam rules. Repeat actions may lead to auto submission.';
      default:
        return 'A violation of exam rules was detected. Please follow exam rules to avoid auto submission.';
    }
  }

  IconData _getViolationIcon() {
    switch (violationType) {
      case 'app_switch':
        return Icons.apps;
      case 'screenshot':
        return Icons.screenshot;
      case 'screen_recording':
        return Icons.videocam_off;
      case 'internet':
        return Icons.wifi_off;
      case 'external_internet':
        return Icons.wifi_off;
      case 'paste':
        return Icons.content_paste_off;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getViolationColor() {
    // Internet violation is more critical (red)
    if (violationType == 'internet' || violationType == 'external_internet') {
      return Colors.red;
    }
    // Other violations are warnings (orange/yellow)
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getViolationColor();
    final bool isInternetViolation = violationType == 'internet' || violationType == 'external_internet';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getViolationIcon(),
                size: 48,
                color: color,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              _getViolationTitle(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              _getViolationMessage(),
              style: TextStyle(
                fontSize: 17,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // Violation count warning
            // if (violationCount >= 3 && !isInternetViolation) ...[
            if (violationCount >= 3) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Violation count: $violationCount. Further violations will result in auto-submission.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Dismiss button (only for non-internet violations)
            // if (!isInternetViolation)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'I Understand',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // For internet violation, no dismiss button
            // User must turn off internet first
            // if (isInternetViolation)
            //   Text(
            //     'This dialog will close automatically when internet is turned off.',
            //     style: TextStyle(
            //       fontSize: 13,
            //       color: AppColors.textPrimary,
            //       fontStyle: FontStyle.italic,
            //     ),
            //     textAlign: TextAlign.center,
            //   ),
          ],
        ),
      ),
    );
  }



}
