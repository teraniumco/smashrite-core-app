import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';

class ServerInfoModal extends StatelessWidget {
  final ExamServer server;
  final VoidCallback onDisconnect;

  const ServerInfoModal({
    super.key,
    required this.server,
    required this.onDisconnect,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected Server',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        server.name,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 18,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Connection Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Connection',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Server Details
            _InfoRow(
              icon: Icons.language_rounded,
              label: 'IP Address',
              value: server.ipAddress,
              onCopy: () => _copyToClipboard(context, server.ipAddress, 'IP Address'),
            ),
            const SizedBox(height: 16),

            _InfoRow(
              icon: Icons.cable_rounded,
              label: 'Port',
              value: server.port.toString(),
              onCopy: () => _copyToClipboard(context, server.port.toString(), 'Port'),
            ),
            const SizedBox(height: 16),

            if (server.signalStrength != null) ...[
              const SizedBox(height: 16),
              _InfoRow(
                icon: Icons.signal_wifi_4_bar_rounded,
                label: 'Signal Strength',
                value: '${server.signalStrength}%',
              ),
            ],

            const SizedBox(height: 32),

            // Disconnect Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDisconnect,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Disconnect from Server'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
       
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onPressed: onCopy,
            tooltip: 'Copy',
          ),
      ],
    );
  }
}