import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';

class SecurityViolationScreen extends StatelessWidget {
  final SecurityViolation violation;

  const SecurityViolationScreen({super.key, required this.violation});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: AppColors.error,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Warning Icon
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, double scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getViolationIcon(violation.type),
                      size: 64,
                      color: AppColors.error,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'Security Violation Detected',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Violation Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getViolationTypeLabel(violation.type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Description Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.error,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        violation.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Severity Indicator
                      _buildSeverityIndicator(violation.severity),

                      const SizedBox(height: 16),

                      // Timestamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Detected: ${_formatDateTime(violation.detectedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Action Required Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '[!! WARNING !!] Action Required',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getActionMessage(violation.type, violation.severity),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Action Buttons
                if (_canRetry(violation.severity)) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        SecurityService.clearViolation();
                        context.go('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Return to Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                // else ...[
                //   SizedBox(
                //     width: double.infinity,
                //     child: ElevatedButton(
                //       onPressed: () {
                //         // Exit app or show contact support
                //         _showContactSupport(context);
                //       },
                //       style: ElevatedButton.styleFrom(
                //         backgroundColor: Colors.white,
                //         foregroundColor: AppColors.error,
                //         padding: const EdgeInsets.symmetric(vertical: 16),
                //         shape: RoundedRectangleBorder(
                //           borderRadius: BorderRadius.circular(12),
                //         ),
                //       ),
                //       child: const Text(
                //         'Contact Support',
                //         style: TextStyle(
                //           fontSize: 16,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //     ),
                //   ),
                // ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getViolationIcon(ViolationType type) {
    switch (type) {
      case ViolationType.rootDetected:
      case ViolationType.jailbreakDetected:
        return Icons.admin_panel_settings;
      case ViolationType.debuggerAttached:
        return Icons.bug_report;
      case ViolationType.emulatorDetected:
        return Icons.computer;
      case ViolationType.screenRecording:
        return Icons.videocam;
      case ViolationType.tamperedApp:
        return Icons.shield_outlined;
      case ViolationType.deviceMismatch:
        return Icons.phonelink_erase;
      default:
        return Icons.warning;
    }
  }

  String _getViolationTypeLabel(ViolationType type) {
    return type.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .trim()
        .toUpperCase();
  }

  Widget _buildSeverityIndicator(ViolationSeverity severity) {
    Color color;
    String label;

    switch (severity) {
      case ViolationSeverity.critical:
        color = AppColors.error;
        label = 'CRITICAL';
        break;
      case ViolationSeverity.high:
        color = Colors.orange;
        label = 'HIGH';
        break;
      case ViolationSeverity.medium:
        color = AppColors.warning;
        label = 'MEDIUM';
        break;
      case ViolationSeverity.low:
        color = AppColors.info;
        label = 'LOW';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.priority_high, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            'SEVERITY: $label',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getActionMessage(ViolationType type, ViolationSeverity severity) {
    if (severity == ViolationSeverity.critical) {
      return 'This is a critical security violation. You cannot proceed with the exam. Please contact your administrator.';
    }

    switch (type) {
      case ViolationType.rootDetected:
      case ViolationType.jailbreakDetected:
        return 'Please use a non-rooted/jailbroken device to take exams.';
      case ViolationType.debuggerAttached:
        return 'Close all debugging tools and restart the app.';
      case ViolationType.emulatorDetected:
        return 'Exams must be taken on physical devices only.';
      case ViolationType.tamperedApp:
        return 'Reinstall the official Smashrite app from the store.';
      case ViolationType.deviceMismatch:
        return 'This device is not registered. Contact administrator to register it.';
      default:
        return 'Please resolve the security issue and try again.';
    }
  }

  bool _canRetry(ViolationSeverity severity) {
    return severity != ViolationSeverity.critical;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showContactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Contact Support'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Please contact your administrator or Smashrite support:'),
                SizedBox(height: 16),
                Text(
                  '📞 Phone: +234 801 123 4567',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '📧 Email: support@smashrite.com',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
