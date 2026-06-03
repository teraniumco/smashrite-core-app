import 'package:flutter/services.dart';

class MdnsResolver {
  static const _channel = MethodChannel('com.smashrite.core/mdns');
  static final Map<String, String> _cache = {};

  /// Resolves a single .local hostname → IP, with in-memory cache.
  static Future<String> resolve(String hostname) async {
    if (_cache.containsKey(hostname)) return _cache[hostname]!;
    final ip = await _channel.invokeMethod<String>(
      'resolveHost', {'hostname': hostname},
    );
    if (ip == null) throw Exception('Could not resolve $hostname');
    _cache[hostname] = ip;
    return ip;
  }

  /// Pre-resolves all 20 server slots at session start.
  /// Returns a map of hostname → IP (null entries = unreachable).
  static Future<Map<String, String?>> resolveAll(List<String> hostnames) async {
    final raw = await _channel.invokeMapMethod<String, String?>(
      'resolveHosts', {'hostnames': hostnames},
    );
    raw?.forEach((host, ip) {
      if (ip != null) _cache[host] = ip;
    });
    return raw ?? {};
  }

  /// Rewrites any .local URI to use the resolved IP.
  static Future<Uri> resolveUri(Uri uri) async {
    if (!uri.host.endsWith('.local')) return uri;
    final ip = await resolve(uri.host);
    return uri.replace(host: ip);
  }

  /// Clears cache (call between exam sessions).
  static void clearCache() => _cache.clear();
}