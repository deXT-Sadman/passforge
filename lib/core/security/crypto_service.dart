import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM encryption for stored passwords.
///
/// The 256-bit key is generated once and kept in the platform keystore
/// (Android Keystore / iOS Keychain) via [FlutterSecureStorage]. It never
/// touches the vault file. Each encryption uses a fresh random IV; the stored
/// format is `base64(iv):base64(ciphertext+tag)`.
class CryptoService {
  CryptoService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'passforge_master_key_v1';
  final FlutterSecureStorage _storage;
  Encrypter? _encrypter;

  Future<Encrypter> _getEncrypter() async {
    if (_encrypter != null) return _encrypter!;
    var encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      encoded = Key.fromSecureRandom(32).base64;
      await _storage.write(key: _keyName, value: encoded);
    }
    return _encrypter =
        Encrypter(AES(Key.fromBase64(encoded), mode: AESMode.gcm));
  }

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
