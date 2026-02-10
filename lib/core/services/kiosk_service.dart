import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class KioskService {
  static const MethodChannel _channel = MethodChannel('com.smashrite.core/kiosk');
  
  static bool _isEnabled = false;
  static bool get isEnabled => _isEnabled;

  /// Initialize kiosk service
  static Future<void> initialize() async {
    try {
      // Set up method call handler for callbacks from native
      _channel.setMethodCallHandler(_handleMethodCall);
      debugPrint('✅ Kiosk service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize kiosk service: $e');
    }
  }

  /// Handle method calls from native platforms
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onHomeButtonPressed':
        debugPrint('🚨 Home button pressed during exam!');
        // You can trigger a violation here if needed
        return null;
        
      case 'onRecentAppsPressed':
        debugPrint('🚨 Recent apps button pressed during exam!');
        // Trigger violation
        return null;
        
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  /// Enable kiosk mode - locks down the device
  static Future<bool> enableKioskMode() async {
    if (_isEnabled) {
      debugPrint('⏭️ Kiosk mode already enabled');
      return true;
    }

    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod<bool>('enableKioskMode');
        _isEnabled = result ?? false;
        
        if (_isEnabled) {
          debugPrint('🔒 Android Kiosk mode enabled');
        } else {
          debugPrint('⚠️ Android Kiosk mode failed to enable');
        }
        
        return _isEnabled;
      } else if (Platform.isIOS) {
        final result = await _channel.invokeMethod<bool>('enableKioskMode');
        _isEnabled = result ?? false;
        
        if (_isEnabled) {
          debugPrint('🔒 iOS Guided Access mode info sent');
        } else {
          debugPrint('⚠️ iOS Guided Access info failed');
        }
        
        return _isEnabled;
      }
      
      debugPrint('⚠️ Kiosk mode not supported on this platform');
      return false;
    } catch (e) {
      debugPrint('❌ Failed to enable kiosk mode: $e');
      return false;
    }
  }

  /// Disable kiosk mode - unlocks the device
  static Future<bool> disableKioskMode() async {
    if (!_isEnabled) {
      debugPrint('⏭️ Kiosk mode already disabled');
      return true;
    }

    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod<bool>('disableKioskMode');
        _isEnabled = !(result ?? true);
        
        if (!_isEnabled) {
          debugPrint('🔓 Android Kiosk mode disabled');
        } else {
          debugPrint('⚠️ Android Kiosk mode failed to disable');
        }
        
        return !_isEnabled;
      } else if (Platform.isIOS) {
        final result = await _channel.invokeMethod<bool>('disableKioskMode');
        _isEnabled = !(result ?? true);
        
        if (!_isEnabled) {
          debugPrint('🔓 iOS restrictions lifted');
        } else {
          debugPrint('⚠️ iOS restrictions failed to lift');
        }
        
        return !_isEnabled;
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Failed to disable kiosk mode: $e');
      return false;
    }
  }

  /// Force disable kiosk mode (for emergency exits)
  static Future<void> forceDisable() async {
    try {
      await disableKioskMode();
      _isEnabled = false;
      debugPrint('⚠️ Kiosk mode force disabled');
    } catch (e) {
      debugPrint('❌ Force disable failed: $e');
      _isEnabled = false; // Set to false anyway
    }
  }

  /// Check if device supports kiosk mode
  static Future<bool> isSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isKioskSupported');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Failed to check kiosk support: $e');
      return false;
    }
  }

  /// Get kiosk mode capabilities
  static Future<Map<String, dynamic>> getCapabilities() async {
    try {
      final result = await _channel.invokeMethod<Map>('getKioskCapabilities');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      debugPrint('❌ Failed to get capabilities: $e');
      return {};
    }
  }
}
