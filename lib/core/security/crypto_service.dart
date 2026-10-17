import 'package:encrypt/encrypt.dart';

import 'key_store.dart';

/// Field-level AES-256-GCM encryption for stored passwords.
///
/// This is a second layer on top of the encrypted Hive box: even if the box
/// file were decrypted, passwords stay ciphertext. It uses its own key, separate
/// from the box key. Each encryption uses a fresh random IV; the stored format
/// is `base64(iv):base64(ciphertext+tag)`.
class CryptoService {
  CryptoService(this._keys);

  static const _keyName = 'passforge_field_key_v1';
  final KeyStore _keys;
  Encrypter? _encrypter;

  Future<Encrypter> _getEncrypter() async =>
      _encrypter ??= Encrypter(
          AES(Key(await _keys.getOrCreateKey(_keyName)), mode: AESMode.gcm));

  Future<String> encrypt(String plainText) async {
    final iv = IV.fromSecureRandom(12); // 96-bit nonce recommended for GCM
    final encrypted = (await _getEncrypter()).encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  Future<String> decrypt(String payload) async {
    final parts = payload.split(':');
    if (parts.length != 2) throw const FormatException('Bad cipher payload');
    return (await _getEncrypter())
        .decrypt(Encrypted.fromBase64(parts[1]), iv: IV.fromBase64(parts[0]));
  }
}
