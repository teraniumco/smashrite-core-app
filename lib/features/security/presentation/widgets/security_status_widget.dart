import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/core/services/security_globals.dart';

class SecurityStatusWidget extends StatelessWidget {
  final bool compact;
  
  const SecurityStatusWidget({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!SecurityService.isInitialized) {
      return const SizedBox.shrink();
    }

    // Check both SecurityService and global violations
    final hasViolation = SecurityService.hasActiveViolation;
    final globalViolation = getLastGlobalSecurityViolation();
    final hasGlobalViolation = globalViolation != null;
    final hasAnyViolation = hasViolation || hasGlobalViolation;
    
    final isRegistered = SecurityService.isDeviceRegistered;
    final currentViolation = SecurityService.currentViolation ?? globalViolation;

    // Make widget tappable to show details
    return GestureDetector(
      onTap: () => _showSecurityDetails(context, currentViolation, isRegistered),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: hasAnyViolation
              ? AppColors.error.withOpacity(0.1)
              : isRegistered
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasAnyViolation
                ? AppColors.error
                : isRegistered
                    ? AppColors.success
                    : AppColors.warning,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAnyViolation
                  ? Icons.warning
                  : isRegistered
                      ? Icons.verified_user
                      : Icons.info,
              color: hasAnyViolation
                  ? AppColors.error
                  : isRegistered
                      ? AppColors.success
                      : AppColors.warning,
              size: 14,
            ),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                hasAnyViolation
                    ? 'Alert'
                    : isRegistered
                        ? 'Secure'
                        : 'Check',
                style: TextStyle(
                  color: hasAnyViolation
                      ? AppColors.error
                      : isRegistered
                          ? AppColors.success
                          : AppColors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Show detailed security information
  void _showSecurityDetails(
    BuildContext context,
    SecurityViolation? violation,
    bool isRegistered,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              violation != null
                  ? Icons.warning_amber
                  : isRegistered
                      ? Icons.verified_user
                      : Icons.info_outline,
              color: violation != null
                  ? AppColors.error
                  : isRegistered
                      ? AppColors.success
                      : AppColors.warning,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Security Status'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Registration Status
              _buildInfoSection(
                icon: isRegistered ? Icons.check_circle : Icons.error_outline,
                iconColor: isRegistered ? AppColors.success : AppColors.warning,
                title: 'Device Registration',
                content: isRegistered
                    ? 'This device is registered and authorized for exams'
                    : 'Device registration status unknown',
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Violation Status
              if (violation != null) ...[
                _buildInfoSection(
                  icon: Icons.warning,
                  iconColor: AppColors.error,
                  title: 'Active Violation',
                  content: '',
                ),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Type',
                        _formatViolationType(violation.type),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Severity',
                        violation.severity.name.toUpperCase(),
                        valueColor: _getSeverityColor(violation.severity),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Detected',
                        _formatDateTime(violation.detectedAt),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        violation.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildInfoSection(
                  icon: Icons.shield,
                  iconColor: AppColors.success,
                  title: 'No Violations Detected',
                  content: '',
                ),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Security Monitoring:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildSecurityChecks(),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Device Information (Enhanced)
              _buildInfoSection(
                icon: Icons.phone_android,
                iconColor: AppColors.primary,
                title: 'Device Information',
                content: '',
              ),
              const SizedBox(height: 12),
              
              if (SecurityService.deviceIdentity != null) ...[
                // Basic Device Info
                _buildDetailRow(
                  'Device Name',
                  SecurityService.deviceIdentity!.deviceName,
                ),
                const SizedBox(height: 6),
                _buildDetailRow(
                  'Model',
                  SecurityService.deviceIdentity!.deviceModel,
                ),
                const SizedBox(height: 6),
                _buildDetailRow(
                  'OS Version',
                  SecurityService.deviceIdentity!.osVersion,
                ),
                const SizedBox(height: 6),
                _buildDetailRow(
                  'App Version',
                  SecurityService.deviceIdentity!.appVersion,
                ),
                
                // Hardware Profile Info
                if (SecurityService.hardwareProfile != null) ...[
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    'Manufacturer',
                    SecurityService.hardwareProfile!.manufacturer,
                  ),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    'Brand',
                    SecurityService.hardwareProfile!.brand,
                  ),
                ],
                
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                
                // Security Identifiers
                Text(
                  'Security Identifiers',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Installation ID
                if (SecurityService.installationId != null)
                  _buildCopyableRow(
                    context,
                    'Installation ID',
                    _shortenId(SecurityService.installationId!),
                    SecurityService.installationId!,
                  ),
                  
                const SizedBox(height: 6),
                
                // Composite Fingerprint
                if (SecurityService.compositeFingerprint != null)
                  _buildCopyableRow(
                    context,
                    'Fingerprint',
                    '${SecurityService.compositeFingerprint!.substring(0, 16)}...',
                    SecurityService.compositeFingerprint!,
                  ),
              ] else ...[
                Text(
                  'Device information not available',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: valueColor != null ? FontWeight.bold : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableRow(
    BuildContext context,
    String label,
    String displayValue,
    String fullValue,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _copyToClipboard(context, fullValue, label),
                child: Icon(
                  Icons.copy,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSecurityChecks() {
    final checks = [
      '• Multi-Layer Device Fingerprinting',
      '• Root/Jailbreak Detection',
      '• Emulator Detection',
      '• Debugger Detection',
      '• App Tampering Detection',
      '• Device Consistency Monitoring',
      '• Screenshot Prevention',
      '• Screen Recording Detection',
      '• App Switch Monitoring',
      '• Internet Connection Monitoring',
      '• Device Binding Verification',
    ];

    return checks.map((check) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              check,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    )).toList();
  }

  String _formatViolationType(ViolationType type) {
    switch (type) {
      case ViolationType.rootDetected:
        return 'Root/Jailbreak Detected';
      case ViolationType.debuggerAttached:
        return 'Debugger Attached';
      case ViolationType.emulatorDetected:
        return 'Emulator Detected';
      case ViolationType.screenRecording:
        return 'Screen Recording';
      case ViolationType.tamperedApp:
        return 'App Tampering';
      case ViolationType.deviceMismatch:
        return 'Device Mismatch';
      case ViolationType.screenshot:
        return 'Screenshot Attempt';
      case ViolationType.appSwitch:
        return 'App Switched';
      case ViolationType.internetConnection:
      case ViolationType.mobileDataEnabled:
      case ViolationType.externalInternet:
        return 'Unauthorized Internet';
      default:
        return type.name.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color _getSeverityColor(ViolationSeverity severity) {
    switch (severity) {
      case ViolationSeverity.critical:
        return Colors.red.shade700;
      case ViolationSeverity.high:
        return Colors.orange.shade700;
      case ViolationSeverity.medium:
        return Colors.amber.shade700;
      case ViolationSeverity.low:
        return Colors.blue.shade700;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  String _shortenId(String id) {
    if (id.length <= 16) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 8)}';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}