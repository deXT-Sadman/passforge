import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

/// OS-backed random bytes (salts, IVs).
Uint8List secureRandomBytes(int n) {
  final rnd = Random.secure();
  return Uint8List.fromList(List.generate(n, (_) => rnd.nextInt(256)));
}

/// PBKDF2-HMAC-SHA256 → 32-byte key. Runs in a background isolate because
/// hundreds of thousands of iterations would otherwise jank the UI.
Future<Uint8List> pbkdf2(String secret, Uint8List salt, {int iterations = 100000}) =>
    compute(_derive, (secret, salt, iterations));

Uint8List _derive((String, Uint8List, int) args) {
  final (secret, salt, iterations) = args;
  final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, 32));
  return kdf.process(Uint8List.fromList(utf8.encode(secret)));
}

/// Timing-safe byte comparison.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
