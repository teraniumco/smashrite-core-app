import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NetworkMonitorService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  // Callbacks
  static Function(bool isConnected)?
  onServerConnectionChanged; // Server-specific
  static Function()? onMobileDataEnabled;
  static Function()? onExternalInternetDetected;
  static Function()? onServerDisconnected;
  static Function()? onServerReconnected;

  static bool _isInitialized = false;
  static bool _lastServerConnectionState = true; // Assume connected initially
  static Timer? _internetCheckTimer;
  static Timer? _serverCheckTimer; // Check server reachability
  static String? _serverUrl; // Store server URL

  /// Initialize network monitoring with server URL
  static Future<void> initialize({String? serverUrl}) async {
    if (_isInitialized) return;

    _serverUrl = serverUrl;

    // Get initial state
    final initialResult = await _connectivity.checkConnectivity();
    debugPrint('📡 Initial connectivity: $initialResult');

    // NEW: Perform initial server check immediately
    if (_serverUrl != null) {
      final isServerReachable = await _checkServerReachabilitySync();
      _lastServerConnectionState = isServerReachable;
      debugPrint(
        '📡 Initial server state: ${isServerReachable ? "✅ Connected" : "❌ Disconnected"}',
      );

      // Trigger callback with initial state
      onServerConnectionChanged?.call(isServerReachable);
    }

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _handleConnectivityChange(results);
    });

    // Start periodic internet check (every 5 seconds) for WiFi connections
    _startInternetCheck();

    // Start periodic server reachability check
    if (_serverUrl != null) {
      _startServerCheck();
    }

    _isInitialized = true;
  }

  // Synchronous version for initial check
  static Future<bool> _checkServerReachabilitySync() async {
    if (_serverUrl == null) return false;

    try {
      final results = await _connectivity.checkConnectivity();

      // Can't reach server if no network
      if (results.contains(ConnectivityResult.none)) {
        return false;
      }

      // Try to ping the exam server
      return await _pingServer();
    } catch (e) {
      debugPrint('❌ Error checking server: $e');
      return false;
    }
  }

  static void _handleConnectivityChange(List<ConnectivityResult> results) {
    debugPrint('📡 Network changed: $results');

    // Check for mobile data specifically
    if (results.contains(ConnectivityResult.mobile)) {
      debugPrint('[!! WARNING !!] Mobile data detected!');
      onMobileDataEnabled?.call();
    }

    // If no connectivity at all, server is unreachable
    if (results.contains(ConnectivityResult.none)) {
      debugPrint('[!! WARNING !!] No network connection!');
      _updateServerConnectionState(false);
    }
  }

  /// Start periodic check for external internet access on WiFi
  static void _startInternetCheck() {
    _internetCheckTimer?.cancel();
    _internetCheckTimer = Timer.periodic(const Duration(seconds: 10), (
      _,
    ) async {
      await _checkExternalInternet();
    });
  }

  /// Start periodic server reachability check
  static void _startServerCheck() {
    _serverCheckTimer?.cancel();
    _serverCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _checkServerReachability();
    });
  }

  /// Check if exam server is reachable
  static Future<void> _checkServerReachability() async {
    if (_serverUrl == null) return;

    try {
      final results = await _connectivity.checkConnectivity();

      // Can't reach server if no network
      if (results.contains(ConnectivityResult.none)) {
        _updateServerConnectionState(false);
        return;
      }

      // Try to ping the exam server
      final isReachable = await _pingServer();
      _updateServerConnectionState(isReachable);
    } catch (e) {
      debugPrint('❌ Error checking server: $e');
      _updateServerConnectionState(false);
    }
  }

  /// Ping the exam server using an existing endpoint
  static Future<bool> _pingServer() async {
    if (_serverUrl == null) return false;

    try {
      // Use a lightweight existing endpoint instead of /health
      // Option 1: Try the base URL
      final response = await http
          .head(Uri.parse(_serverUrl!))
          .timeout(const Duration(seconds: 5));

      // Any response (even 404) means server is reachable
      return response.statusCode < 500;
    } catch (e) {
      // Try alternative: Use the /exam/progress endpoint (GET request)
      try {
        final altResponse = await http
            .get(
              Uri.parse('$_serverUrl/exam/progress'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 5));

        // Server is reachable if we get any response
        return altResponse.statusCode < 500;
      } catch (altError) {
        debugPrint('[!! WARNING !!] Server unreachable: $altError');
        return false;
      }
    }
  }

  /// Update server connection state and trigger callbacks
  static void _updateServerConnectionState(bool isConnected) {
    if (isConnected != _lastServerConnectionState) {
      final wasDisconnected = !_lastServerConnectionState;
      _lastServerConnectionState = isConnected;

      debugPrint(
        '📡 Server connection: ${isConnected ? "✅ Connected" : "❌ Disconnected"}',
      );

      onServerConnectionChanged?.call(isConnected);

      if (!isConnected) {
        onServerDisconnected?.call();
      } else if (wasDisconnected) {
        // Connection restored
        onServerReconnected?.call();
      }
    }
  }

  /// Check if WiFi has external internet access (not just local network)
  static Future<void> _checkExternalInternet() async {
    try {
      final results = await _connectivity.checkConnectivity();

      // Only check if on WiFi (not mobile data)
      if (results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.mobile)) {
        // Try to ping external site
        final hasInternet = await _pingExternalSite();

        if (hasInternet) {
          debugPrint('[!! WARNING !!] External internet detected on WiFi!');
          onExternalInternetDetected?.call();
        }
      }
    } catch (e) {
      debugPrint('Error checking external internet: $e');
    }
  }

  /// Ping external site to check for internet
  static Future<bool> _pingExternalSite() async {
    try {
      final result = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));

      return result.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Check current connectivity status
  static Future<bool> hasMobileData() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.mobile);
  }

  /// Get current server connection status
  static bool isServerConnected() {
    return _lastServerConnectionState;
  }

  /// Dispose
  static void dispose() {
    debugPrint('📡 Disposing network monitor...');
    _subscription?.cancel();
    _subscription = null;
    _internetCheckTimer?.cancel();
    _internetCheckTimer = null;
    _serverCheckTimer?.cancel();
    _serverCheckTimer = null;
    _isInitialized = false;
  }
}
