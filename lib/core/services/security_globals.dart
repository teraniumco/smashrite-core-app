import 'package:flutter/foundation.dart';
import 'package:smashrite/core/services/security_service.dart';

/// Global security state management
/// This file stores early violations detected before the exam screen loads

// Global flag to track if early callbacks are set
bool _earlySecurityCallbacksInitialized = false;

// Global storage for early violations
SecurityViolation? _lastGlobalSecurityViolation;
bool _hasDeviceMismatchViolation = false;

/// Check if early security callbacks have been initialized
bool get earlySecurityCallbacksInitialized => _earlySecurityCallbacksInitialized;

/// Get the last global security violation (if any)
SecurityViolation? getLastGlobalSecurityViolation() => _lastGlobalSecurityViolation;

/// Check if there was a device mismatch violation
bool hasDeviceMismatchViolation() => _hasDeviceMismatchViolation;

/// Clear all global security violations
void clearGlobalSecurityViolations() {
  _lastGlobalSecurityViolation = null;
  _hasDeviceMismatchViolation = false;
}

/// Setup security callbacks before app starts
/// This should be called in main() before SecurityService.initialize()
Future<void> setupEarlySecurityCallbacks() async {
  if (_earlySecurityCallbacksInitialized) return;

  debugPrint('🔒 [GLOBALS] Setting up GLOBAL early security callbacks...');

  // FreeRASP critical violations - set BEFORE SecurityService.initialize()
  SecurityService.onSecurityViolation = (violation) {
    debugPrint(
      '🚨 [GLOBALS] FreeRASP violation detected EARLY: ${violation.type} (${violation.severity})',
    );

    // Store violation globally for later retrieval
    _lastGlobalSecurityViolation = violation;

    // Critical violations are handled by exam screen
    if (violation.severity == ViolationSeverity.critical) {
      debugPrint('🚨 [GLOBALS] CRITICAL violation stored for navigation');
    }
  };

  // Device binding/mismatch violations
  SecurityService.onDeviceBindingViolation = () {
    debugPrint('🚨 [GLOBALS] Device mismatch detected EARLY');
    _hasDeviceMismatchViolation = true;
  };

  _earlySecurityCallbacksInitialized = true;
  debugPrint('✅ [GLOBALS] Early security callbacks registered globally');
}