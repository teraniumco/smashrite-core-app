import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveEncryptionService {
  static const String _encryptionKeyName = 'smashrite_hive_encryption_key';
  static final _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Uint8List? _cachedKey;

  /// Get or generate encryption key
  static Future<Uint8List> getEncryptionKey() async {
    // Return cached key if available
    if (_cachedKey != null) {
      return _cachedKey!;
    }

    // Try to load existing key
    final existingKey = await _secureStorage.read(key: _encryptionKeyName);

    if (existingKey != null) {
      _cachedKey = base64Url.decode(existingKey);
      return _cachedKey!;
    }

    // Generate new key if none exists
    final newKey = Hive.generateSecureKey();
    await _secureStorage.write(
      key: _encryptionKeyName,
      value: base64Url.encode(newKey),
    );

    _cachedKey = Uint8List.fromList(newKey);
    return _cachedKey!;
  }

  /// Delete encryption key (use with caution - will make existing data unreadable)
  static Future<void> deleteEncryptionKey() async {
    await _secureStorage.delete(key: _encryptionKeyName);
    _cachedKey = null;
  }

  /// Clear cached key (will be reloaded from secure storage on next use)
  static void clearCachedKey() {
    _cachedKey = null;
  }
}
