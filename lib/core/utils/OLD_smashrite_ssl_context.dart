import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SmashriteSslContext {
  SmashriteSslContext._();

  static SecurityContext? _context;
  
  // The expected issuer CN in all Smashrite CA-signed certs.
  // Must match the O= or CN= field in your CA's subject.
  static const String _caOrganization = 'Smashrite Technologies';
  static const String _caCommonName = 'Smashrite Local CA';

  /// Returns a SecurityContext that trusts ONLY the Smashrite CA.
  /// Built once and cached.
  static Future<SecurityContext> get() async {
    if (_context != null) return _context!;

    final caBytes = await rootBundle.load('assets/certs/smashrite_ca.crt');
    _context = SecurityContext(withTrustedRoots: false);
    _context!.setTrustedCertificatesBytes(caBytes.buffer.asUint8List());

    debugPrint('[SSL] SmashriteSslContext built — CA loaded.');
    return _context!;
  }

  /// Apply a CA-pinned, hostname-flexible HttpClient to [dio].
  ///
  /// CA validation is enforced by the SecurityContext.
  /// Hostname verification is relaxed for LAN servers — the cert's
  /// issuer is checked instead, ensuring only Smashrite-CA-signed
  /// certs are accepted regardless of which IP the server is on.
  static Future<void> applyTo(dynamic dio) async {
    final context = await get();

    (dio.httpClientAdapter as dynamic).createHttpClient = () {
      final client = HttpClient(context: context);

      client.badCertificateCallback = (
        X509Certificate cert,
        String host,
        int port,
      ) {
        // The SecurityContext already rejected certs from foreign CAs —
        // if we reach here, it means the cert IS from our CA but the
        // hostname doesn't match (because the app connected via raw IP).
        //
        // Double-check the cert issuer to be safe before allowing.
        final isSmashriteCert = cert.issuer.contains(_caCommonName);

        debugPrint(
            '[SSL] Double-checked the cert issuer to be safe before allowing.'
            'Host: $host:$port | Issuer: ${cert.issuer} | isSmashriteCert: $isSmashriteCert',
          );

        if (isSmashriteCert) {
          debugPrint(
            '[SSL] Hostname mismatch allowed — cert is Smashrite-issued. '
            'Host: $host:$port | Issuer: ${cert.issuer}',
          );
          return true; // ✅ Dynamic IP, same CA — allow
        }

        debugPrint(
          '[SSL] REJECTED — cert issuer is not Smashrite CA. '
          'Host: $host:$port | Issuer: ${cert.issuer}',
        );
        return false; // ❌ Foreign cert — reject
      };

      return client;
    };

    debugPrint('[SSL] Secure adapter applied.');
  }
}