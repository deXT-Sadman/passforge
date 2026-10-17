import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' show SecureRandom;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over the platform keystore (Android Keystore / iOS Keychain /
/// Windows Credential Locker) for secrets that must never touch plain files.
class KeyStore {
  KeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Returns the 32-byte key stored under [name], generating it on first use.
  Future<Uint8List> getOrCreateKey(String name) async {
    final existing = await _storage.read(key: name);
    if (existing != null) return base64Decode(existing);
    final key = SecureRandom(32).bytes;
    await _storage.write(key: name, value: base64Encode(key));
    return key;
  }

  Future<String?> read(String name) => _storage.read(key: name);
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);
  Future<void> delete(String name) => _storage.delete(key: name);
}
