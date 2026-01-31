import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for network connectivity validation
class NetworkService {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device is connected to WiFi
  static Future<bool> isConnectedToWiFi() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult.contains(ConnectivityResult.wifi);
    } catch (e) {
      debugPrint('Error checking WiFi connectivity: $e');
      return false;
    }
  }

  /// Check if device has actual internet access
  /// Uses HTTP request instead of DNS lookup for accuracy
  static Future<bool> hasInternetAccess() async {
    try {
      // Try to actually connect to a server with HEAD request
      final response = await http.head(
        Uri.parse('https://www.google.com'),
      ).timeout(
        const Duration(seconds: 5),
      );
      
      // If we get any response (even error codes), we have internet
      return response.statusCode >= 200 && response.statusCode < 500;
      
    } on SocketException catch (_) {
      // No internet connection
      return false;
    } on TimeoutException catch (_) {
      // Request timed out - no internet
      return false;
    } on http.ClientException catch (_) {
      // HTTP client error - no internet
      return false;
    } catch (e) {
      debugPrint('Error checking internet access: $e');
      return false;
    }
  }

  /// Alternative method using socket connection (no http package needed)
  static Future<bool> hasInternetAccessViaSocket() async {
    try {
      // Try to connect to Google's DNS server
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 5),
      );
      
      socket.destroy();
      return true;
      
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (e) {
      debugPrint('Error checking internet via socket: $e');
      return false;
    }
  }

  /// Check if IP address is a local/private IP
  static bool isLocalIP(String ip) {
    try {
      final parts = ip.split('.');
      if (parts.length != 4) return false;

      final first = int.parse(parts[0]);
      final second = int.parse(parts[1]);

      // Check for private IP ranges
      // 10.0.0.0 - 10.255.255.255
      if (first == 10) return true;

      // 172.16.0.0 - 172.31.255.255
      if (first == 172 && second >= 16 && second <= 31) return true;

      // 192.168.0.0 - 192.168.255.255
      if (first == 192 && second == 168) return true;

      // 127.0.0.0 - 127.255.255.255 (localhost)
      if (first == 127) return true;

      return false;
    } catch (e) {
      debugPrint('Error validating local IP: $e');
      return false;
    }
  }

  /// Validate network status for exam connection
  /// Returns null if valid, error message if invalid
  static Future<String?> validateNetworkForExam() async {
    // Check WiFi connection
    final isWiFi = await isConnectedToWiFi();
    if (!isWiFi) {
      return 'Please turn on your WiFi and connect to the exam local network.';
    }

    // Check internet access with retry
    bool hasInternet = false;
    
    // Try 2 times with short delay
    for (int i = 0; i < 2; i++) {
      hasInternet = await hasInternetAccessViaSocket();
      if (!hasInternet) break; // No internet detected - good!
      
      if (i < 1) await Future.delayed(const Duration(milliseconds: 300));
    }
    
    if (hasInternet) {
      return 'Please disconnect from the internet to continue. The exam runs on a local network only.';
    }

    return null; // Network is valid
  }

  /// Listen to connectivity changes
  static Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;
}