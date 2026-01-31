import 'package:hive_flutter/hive_flutter.dart';
import 'package:smashrite/core/services/hive_encryption_service.dart';

class StorageService {
  static Box? _box;
  static const String _boxName = 'smashrite_box';

  static bool get isInitialized => _box != null && _box!.isOpen;

  // Initialize storage with encryption
  static Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      // Get encryption key
      final encryptionKey = await HiveEncryptionService.getEncryptionKey();
      
      // Open box with encryption
      _box = await Hive.openBox(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    }
  }

  // Save data
  static Future<void> save(String key, dynamic value) async {
    await _ensureInitialized();
    await _box!.put(key, value);
  }

  // Get data
  static T? get<T>(String key, {T? defaultValue}) {
    _ensureInitializedSync();
    return _box!.get(key, defaultValue: defaultValue) as T?;
  }

  // Remove data
  static Future<void> remove(String key) async {
    await _ensureInitialized();
    await _box!.delete(key);
  }

  // Clear all data
  static Future<void> clear() async {
    await _ensureInitialized();
    await _box!.clear();
  }

  // Check if key exists
  static bool containsKey(String key) {
    _ensureInitializedSync();
    return _box!.containsKey(key);
  }

  // Get all keys
  static Iterable<dynamic> getAllKeys() {
    _ensureInitializedSync();
    return _box!.keys;
  }

  // Private helper methods
  static Future<void> _ensureInitialized() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
  }

  static void _ensureInitializedSync() {
    if (_box == null || !_box!.isOpen) {
      throw Exception('StorageService not initialized. Call StorageService.init() first.');
    }
  }

  // Close the box
  static Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}