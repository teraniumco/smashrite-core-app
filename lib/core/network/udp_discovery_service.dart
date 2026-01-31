import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Model for discovered server from UDP broadcast
class DiscoveredServer {
  final String type;
  final String version;
  final String serverName;
  final String serverId;
  final String serverIp;
  final int port;
  final String protocol;
  final bool requiresAuth;
  final int timestamp;

  DiscoveredServer({
    required this.type,
    required this.version,
    required this.serverName,
    required this.serverId,
    required this.serverIp,
    required this.port,
    required this.protocol,
    required this.requiresAuth,
    required this.timestamp,
  });

  factory DiscoveredServer.fromJson(Map<String, dynamic> json) {
    return DiscoveredServer(
      type: json['type'] as String? ?? '',
      version: json['version'] as String? ?? '',
      serverName: json['server_name'] as String? ?? 'Unknown Server',
      serverId: json['server_id'] as String? ?? '',
      serverIp: json['server_ip'] as String? ?? '',
      port: json['port'] as int? ?? 80,
      protocol: json['protocol'] as String? ?? 'http',
      requiresAuth: json['requires_auth'] as bool? ?? true,
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }

  String get url => '$protocol://$serverIp:$port';

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'version': version,
      'server_name': serverName,
      'server_id': serverId,
      'server_ip': serverIp,
      'port': port,
      'protocol': protocol,
      'requires_auth': requiresAuth,
      'timestamp': timestamp,
    };
  }
}

/// Service for discovering Smashrite servers via UDP broadcast
class UdpDiscoveryService {
  static const int discoveryPort = 8888; // Must match backend port
  static const int discoveryTimeout = 8; // Seconds to listen

  final Map<String, DiscoveredServer> _discoveredServers = {};
  RawDatagramSocket? _socket;
  StreamSubscription? _socketSubscription;
  bool _isDiscovering = false;

  /// Discover servers on local network (non-blocking)
  Future<List<DiscoveredServer>> discoverServers() async {
    if (_isDiscovering) {
      debugPrint('[!! WARNING !!]  Discovery already in progress');
      return _discoveredServers.values.toList();
    }

    _isDiscovering = true;
    _discoveredServers.clear();

    try {
      debugPrint('🔍 UDP Discovery: Starting...');

      // Bind to UDP socket on discovery port
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          throw Exception('Failed to bind to UDP port $discoveryPort');
        },
      );

      debugPrint('✅ UDP Discovery: Bound to port $discoveryPort');

      // Create completer for async operation
      final completer = Completer<List<DiscoveredServer>>();

      // Listen for broadcasts (non-blocking)
      _socketSubscription = _socket!.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket!.receive();
            if (datagram != null) {
              _handleBroadcast(datagram);
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Socket error: $error');
        },
        cancelOnError: false,
      );

      debugPrint('👂 UDP Discovery: Listening for broadcasts...');

      // Set timeout and complete
      Future.delayed(const Duration(seconds: discoveryTimeout), () {
        if (!completer.isCompleted) {
          debugPrint('⏱️  UDP Discovery: Timeout reached');
          debugPrint('📡 Found ${_discoveredServers.length} server(s)');
          _cleanup();
          completer.complete(_discoveredServers.values.toList());
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('❌ UDP Discovery Error: $e');
      _cleanup();
      _isDiscovering = false;
      return [];
    } finally {
      _isDiscovering = false;
    }
  }

  /// Handle received UDP broadcast
  void _handleBroadcast(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final json = jsonDecode(message) as Map<String, dynamic>;

      // Verify it's a Smashrite discovery message
      if (json['type'] != 'smashrite_discovery') {
        return;
      }

      final server = DiscoveredServer.fromJson(json);

      // Use server IP from datagram if not in message (more reliable)
      final serverIp =
          server.serverIp.isNotEmpty
              ? server.serverIp
              : datagram.address.address;

      // Create updated server with correct IP
      final updatedServer = DiscoveredServer(
        type: server.type,
        version: server.version,
        serverName: server.serverName,
        serverId: server.serverId,
        serverIp: serverIp,
        port: server.port,
        protocol: server.protocol,
        requiresAuth: server.requiresAuth,
        timestamp: server.timestamp,
      );

      // Add to discovered servers (use IP as key to avoid duplicates)
      if (!_discoveredServers.containsKey(serverIp)) {
        _discoveredServers[serverIp] = updatedServer;
        debugPrint(
          '✅ Discovered: ${server.serverName} at $serverIp:${server.port}',
        );
      }
    } catch (e) {
      debugPrint('[!! WARNING !!]  Failed to parse broadcast: $e');
    }
  }

  /// Clean up resources
  void _cleanup() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
  }

  /// Stop discovery manually
  void stop() {
    debugPrint('🛑 UDP Discovery: Stopped manually');
    _cleanup();
    _isDiscovering = false;
  }
}
