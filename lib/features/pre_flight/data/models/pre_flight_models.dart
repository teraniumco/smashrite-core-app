// lib/features/pre_flight/data/models/pre_flight_models.dart

import 'package:flutter/material.dart';

/// Overall pre-flight check result
class PreFlightResult {
  final bool canProceed;
  final List<CheckResult> checks;
  final DateTime completedAt;
  
  PreFlightResult({
    required this.canProceed,
    required this.checks,
    required this.completedAt,
  });
  
  /// Get all failed checks
  List<CheckResult> get failures => 
      checks.where((c) => c.status == CheckStatus.failed).toList();
  
  /// Get all warnings
  List<CheckResult> get warnings => 
      checks.where((c) => c.status == CheckStatus.warning).toList();
  
  /// Get all passed checks
  List<CheckResult> get passed => 
      checks.where((c) => c.status == CheckStatus.passed).toList();
  
  /// Get all pending checks
  List<CheckResult> get pending => 
      checks.where((c) => c.status == CheckStatus.pending).toList();
}

/// Individual check result
class CheckResult {
  final CheckType type;
  final CheckStatus status;
  final String message;
  final String? details;
  final CheckAction? action;
  final DateTime? checkedAt;
  
  CheckResult({
    required this.type,
    required this.status,
    required this.message,
    this.details,
    this.action,
    this.checkedAt,
  });
  
  CheckResult copyWith({
    CheckType? type,
    CheckStatus? status,
    String? message,
    String? details,
    CheckAction? action,
    DateTime? checkedAt,
  }) {
    return CheckResult(
      type: type ?? this.type,
      status: status ?? this.status,
      message: message ?? this.message,
      details: details ?? this.details,
      action: action ?? this.action,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }
  
  /// Icon for this check type
  IconData get icon {
    switch (type) {
      case CheckType.deviceSecurity:
        return Icons.security;
      case CheckType.networkConnectivity:
        return Icons.wifi;
      case CheckType.permissions:
        return Icons.admin_panel_settings;
      case CheckType.systemRequirements:
        return Icons.phone_android;
      case CheckType.kioskCompatibility:
        return Icons.fullscreen;
      case CheckType.previousSession:
        return Icons.history;
      case CheckType.serverAvailability:
        return Icons.cloud;
      case CheckType.storageSpace:
        return Icons.storage;
      case CheckType.batteryLevel:
        return Icons.battery_full;
      case CheckType.appVersion:
        return Icons.system_update_alt;
    }
  }
  
  /// Color for this status
  Color get statusColor {
    switch (status) {
      case CheckStatus.pending:
        return Colors.grey;
      case CheckStatus.checking:
        return Colors.blue;
      case CheckStatus.passed:
        return Colors.green;
      case CheckStatus.warning:
        return Colors.orange;
      case CheckStatus.failed:
        return Colors.red;
    }
  }
  
  /// Icon for this status
  IconData get statusIcon {
    switch (status) {
      case CheckStatus.pending:
        return Icons.radio_button_unchecked;
      case CheckStatus.checking:
        return Icons.hourglass_empty;
      case CheckStatus.passed:
        return Icons.check_circle;
      case CheckStatus.warning:
        return Icons.warning;
      case CheckStatus.failed:
        return Icons.error;
    }
  }
}

/// Type of check
enum CheckType {
  deviceSecurity,
  networkConnectivity,
  permissions,
  systemRequirements,
  kioskCompatibility,
  previousSession,
  serverAvailability,
  storageSpace,
  batteryLevel,
  appVersion
}

/// Status of check
enum CheckStatus {
  pending,    // Not started yet
  checking,   // Currently running
  passed,     // Check passed
  warning,    // Check passed with warnings
  failed,     // Check failed - cannot proceed
}

/// Action user can take to fix issue
class CheckAction {
  final String label;
  final Function()? onTap;
  final CheckActionType type;
  
  CheckAction({
    required this.label,
    this.onTap,
    this.type = CheckActionType.button,
  });
}

enum CheckActionType {
  button,      // Show as button
  instruction, // Show as instruction text
  link,        // Show as clickable link
}

/// Helper to get check name
extension CheckTypeExtension on CheckType {
  String get name {
    switch (this) {
      case CheckType.deviceSecurity:
        return 'Device Security';
      case CheckType.networkConnectivity:
        return 'Network Connection';
      case CheckType.permissions:
        return 'App Permissions';
      case CheckType.systemRequirements:
        return 'System Requirements';
      case CheckType.kioskCompatibility:
        return 'Kiosk Mode';
      case CheckType.previousSession:
        return 'Previous Session';
      case CheckType.serverAvailability:
        return 'Server Status';
      case CheckType.storageSpace:
        return 'Storage Space';
      case CheckType.batteryLevel:
        return 'Battery Level';
      case CheckType.appVersion:
        return 'App Version';
    }
  }
  
  String get description {
    switch (this) {
      case CheckType.deviceSecurity:
        return 'Checking device integrity...';
      case CheckType.networkConnectivity:
        return 'Verifying network setup...';
      case CheckType.permissions:
        return 'Checking app permissions...';
      case CheckType.systemRequirements:
        return 'Checking device compatibility...';
      case CheckType.kioskCompatibility:
        return 'Testing kiosk mode support...';
      case CheckType.previousSession:
        return 'Looking for unsaved data...';
      case CheckType.serverAvailability:
        return 'Connecting to exam server...';
      case CheckType.storageSpace:
        return 'Checking available storage...';
      case CheckType.batteryLevel:
        return 'Checking battery status...';
      case CheckType.appVersion:
        return 'Verifying app version...';
    }
  }
  
  /// Priority order (lower = higher priority)
  int get priority {
    switch (this) {
      case CheckType.deviceSecurity:
        return 1;
      case CheckType.networkConnectivity:
        return 2;
      case CheckType.permissions:
        return 3;
      case CheckType.systemRequirements:
        return 4;
      case CheckType.kioskCompatibility:
        return 5;
      case CheckType.previousSession:
        return 6;
      case CheckType.serverAvailability:
        return 7;
      case CheckType.storageSpace:
        return 8;
      case CheckType.batteryLevel:
        return 9;
      case CheckType.appVersion:
        return 10;
    }
  }
}
