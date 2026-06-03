import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// mDNS is handled at the HttpClient level in SmashriteSslContext.
/// This interceptor only adds a debug header so logs stay readable.
class MdnsInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final host = options.uri.host;
    if (host.endsWith('.local')) {
      options.headers['X-Smashrite-Host'] = host;
      debugPrint('[mDNS] .local host detected: $host (resolved at socket layer)');
    }
    handler.next(options);
  }
}