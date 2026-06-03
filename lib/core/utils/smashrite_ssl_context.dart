// smashrite_ssl_context.dart — final clean version
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:smashrite/core/services/mdns_resolver.dart';

class SmashriteSslContext {
  static Future<void> applyTo(Dio dio) async {
    final certBytes = await rootBundle.load('assets/certs/smashrite_ca.crt');
    final caCert = certBytes.buffer.asUint8List();

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final ctx = SecurityContext(withTrustedRoots: false);
        ctx.setTrustedCertificatesBytes(caCert);
        final client = HttpClient(context: ctx);

        client.connectionFactory =
            (Uri uri, String? proxyHost, int? proxyPort) async {
          final host = uri.host;
          final port = uri.port > 0 ? uri.port : 443;
          String connectHost = host;

          if (host.endsWith('.local')) {
            try {
              connectHost = await MdnsResolver.resolve(host);
              debugPrint('[SSL/mDNS] TCP→$connectHost  SNI=$host');
            } catch (e) {
              debugPrint('[SSL/mDNS] Resolve failed: $e');
            }
          }

          // Step 1: plain TCP to the resolved IP
          final tcpSocket = await Socket.connect(connectHost, port);

          // Step 2: TLS upgrade — host: sets SNI to the .local name
          // SecureSocket extends Socket, so it satisfies ConnectionTask<Socket>
          final secureSocket = await SecureSocket.secure(
            tcpSocket,
            host: host,               // ← SNI = smashrite-server-1.local ✅
            context: ctx,
            onBadCertificate: (cert) {
              debugPrint('[SSL] Rejected: ${cert.subject} for $host');
              return false;
            },
          );

          return ConnectionTask.fromSocket(
            Future.value(secureSocket),
            () => secureSocket.destroy(),
          );
        };

        return client;
      },
    );
  }
}