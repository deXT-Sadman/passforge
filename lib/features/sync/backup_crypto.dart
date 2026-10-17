import 'dart:convert';

import 'package:encrypt/encrypt.dart';

import '../../core/security/pbkdf2.dart';
import 'vault_snapshot.dart';

class WrongPassphraseException implements Exception {
  const WrongPassphraseException();
  @override
  String toString() => 'Wrong backup passphrase, or the backup is corrupted.';
}

/// Encrypts a [VaultSnapshot] with a key derived from the user's passphrase.
///
/// File format (JSON, safe to store anywhere):
/// `{"v":1,"iter":200000,"salt":"…","iv":"…","ct":"…"}`
/// AES-256-GCM authenticates the data, so a wrong passphrase or any tampering
/// fails decryption instead of yielding garbage.
class BackupCrypto {
  const BackupCrypto();

  static const _iterations = 200000;

  Future<String> seal(VaultSnapshot snapshot, String passphrase) async {
    final salt = secureRandomBytes(16);
    final key = await pbkdf2(passphrase, salt, iterations: _iterations);
    final iv = IV.fromSecureRandom(12);
    final ct = Encrypter(AES(Key(key), mode: AESMode.gcm))
        .encrypt(jsonEncode(snapshot.toJson()), iv: iv);
    return jsonEncode({
      'v': 1,
      'iter': _iterations,
      'salt': base64Encode(salt),
      'iv': iv.base64,
      'ct': ct.base64,
    });
  }

  Future<VaultSnapshot> open(String sealed, String passphrase) async {
    final Map<String, dynamic> env;
    try {
      env = jsonDecode(sealed) as Map<String, dynamic>;
    } on FormatException {
      throw const WrongPassphraseException();
    }
    final key = await pbkdf2(
      passphrase,
      base64Decode(env['salt'] as String),
      iterations: env['iter'] as int,
    );
    final String plain;
    try {
      plain = Encrypter(AES(Key(key), mode: AESMode.gcm)).decrypt(
        Encrypted.fromBase64(env['ct'] as String),
        iv: IV.fromBase64(env['iv'] as String),
      );
    } catch (_) {
      // GCM tag mismatch (pointycastle throws its own exception type).
      throw const WrongPassphraseException();
    }
    return VaultSnapshot.fromJson(jsonDecode(plain) as Map<String, dynamic>);
  }
}
