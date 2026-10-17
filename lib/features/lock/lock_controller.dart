import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/security/key_store.dart';
import '../../core/security/pbkdf2.dart';

enum LockStatus { loading, needsSetup, locked, unlocked }

enum PinResult { success, wrong, lockedOut }

/// Owns the app-lock state: PIN (hashed, never stored raw), biometrics,
/// and brute-force throttling.
class LockController extends ChangeNotifier {
  LockController(this._keys, {LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  static const pinLength = 6;
  static const _maxFreeAttempts = 5;
  static const _kSalt = 'passforge_pin_salt';
  static const _kHash = 'passforge_pin_hash';
  static const _kAttempts = 'passforge_pin_attempts';
  static const _kLockedUntil = 'passforge_pin_locked_until';
  static const _kBiometric = 'passforge_biometric_enabled';

  final KeyStore _keys;
  final LocalAuthentication _auth;

  LockStatus _status = LockStatus.loading;
  bool _biometricEnabled = false;
  bool _authenticating = false;
  int _attempts = 0;
  DateTime? _lockedUntil;

  LockStatus get status => _status;
  bool get biometricEnabled => _biometricEnabled;

  /// Remaining throttle time, or null when PIN entry is allowed.
  Duration? get lockoutRemaining {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  Future<void> init() async {
    final hasPin = await _keys.read(_kHash) != null;
    _attempts = int.tryParse(await _keys.read(_kAttempts) ?? '') ?? 0;
    final until = int.tryParse(await _keys.read(_kLockedUntil) ?? '');
    _lockedUntil =
        until == null ? null : DateTime.fromMillisecondsSinceEpoch(until);
    _biometricEnabled = await _keys.read(_kBiometric) == 'true' &&
        await _biometricsAvailable();
    _status = hasPin ? LockStatus.locked : LockStatus.needsSetup;
    notifyListeners();
  }

  Future<bool> _biometricsAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  // ---- PIN -----------------------------------------------------------

  Future<void> setupPin(String pin) async {
    final salt = secureRandomBytes(16);
    final hash = await pbkdf2(pin, salt);
    await _keys.write(_kSalt, base64Encode(salt));
    await _keys.write(_kHash, base64Encode(hash));
    // Offer biometrics by default when the device has them enrolled.
    _biometricEnabled = await _biometricsAvailable();
    await _keys.write(_kBiometric, _biometricEnabled.toString());
    await _resetAttempts();
    _status = LockStatus.unlocked;
    notifyListeners();
  }

  Future<PinResult> unlockWithPin(String pin) async {
    if (lockoutRemaining != null) return PinResult.lockedOut;

    final salt = base64Decode(await _keys.read(_kSalt) ?? '');
    final stored = base64Decode(await _keys.read(_kHash) ?? '');
    final candidate = await pbkdf2(pin, Uint8List.fromList(salt));

    if (constantTimeEquals(candidate, stored)) {
      await _resetAttempts();
      _status = LockStatus.unlocked;
      notifyListeners();
      return PinResult.success;
    }

    _attempts++;
    await _keys.write(_kAttempts, '$_attempts');
    if (_attempts >= _maxFreeAttempts) {
      // 30s, 60s, 120s, ... capped at 1 hour. Persisted so a restart can't skip it.
      final seconds = (30 * (1 << (_attempts - _maxFreeAttempts).clamp(0, 7)))
          .clamp(30, 3600);
      _lockedUntil = DateTime.now().add(Duration(seconds: seconds));
      await _keys.write(
          _kLockedUntil, '${_lockedUntil!.millisecondsSinceEpoch}');
    }
    notifyListeners();
    return lockoutRemaining != null ? PinResult.lockedOut : PinResult.wrong;
  }

  Future<void> _resetAttempts() async {
    _attempts = 0;
    _lockedUntil = null;
    await _keys.delete(_kAttempts);
    await _keys.delete(_kLockedUntil);
  }

  // ---- Biometrics ----------------------------------------------------

  /// Prompts for fingerprint / face. Falls back silently to the PIN pad.
  Future<void> unlockWithBiometric() async {
    if (_status != LockStatus.locked || !_biometricEnabled || _authenticating) {
      return;
    }
    _authenticating = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your PassForge vault',
        biometricOnly: true,
      );
      if (ok) {
        await _resetAttempts();
        _status = LockStatus.unlocked;
        notifyListeners();
      }
    } catch (_) {
      // Cancelled / too many tries / not enrolled → user falls back to PIN.
    } finally {
      _authenticating = false;
    }
  }

  // ---- Locking -------------------------------------------------------

  /// Called when the app goes to the background.
  void lock() {
    // The system biometric dialog itself pauses the app; don't re-lock mid-prompt.
    if (_status != LockStatus.unlocked || _authenticating) return;
    _status = LockStatus.locked;
    notifyListeners();
  }
}
