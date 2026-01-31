import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/exam/data/providers/exam_provider.dart';
import 'package:smashrite/features/exam/data/services/answer_sync_service.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    
    // Don't show anything when idle
    if (syncStatus == SyncStatus.idle) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _getBackgroundColor(syncStatus),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _getIcon(syncStatus),
            const SizedBox(width: 8),
            Text(
              _getLabel(syncStatus),
              style: TextStyle(
                color: _getTextColor(syncStatus),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getBackgroundColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue.shade50;
      case SyncStatus.synced:
        return Colors.green.shade50;
      case SyncStatus.failed:
        return Colors.orange.shade50;
      default:
        return Colors.grey.shade50;
    }
  }
  
  Color _getTextColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue.shade700;
      case SyncStatus.synced:
        return Colors.green.shade700;
      case SyncStatus.failed:
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
  
  Widget _getIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
          ),
        );
      case SyncStatus.synced:
        return Icon(Icons.check_circle, size: 16, color: Colors.green.shade700);
      case SyncStatus.failed:
        return Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700);
      default:
        return const SizedBox.shrink();
    }
  }
  
  String _getLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing answers...';
      case SyncStatus.synced:
        return 'All answers synced';
      case SyncStatus.failed:
        return 'Sync pending (will retry)';
      default:
        return '';
    }
  }
}