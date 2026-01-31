import 'package:flutter/material.dart';
import 'package:smashrite/core/theme/app_theme.dart';

class ConnectionStatusBadge extends StatelessWidget {
  final bool isConnected;
  final bool compact;

  const ConnectionStatusBadge({
    super.key,
    required this.isConnected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isConnected 
            ? AppColors.success.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected 
              ? AppColors.success.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            color: isConnected ? AppColors.success : Colors.orange,
            size: 14,
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              isConnected ? 'Connected' : 'Offline',
              style: TextStyle(
                color: isConnected ? AppColors.success : Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}