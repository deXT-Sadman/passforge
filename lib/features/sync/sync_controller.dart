import 'package:flutter/foundation.dart';

import '../../core/security/key_store.dart';
import '../vault/presentation/vault_controller.dart';
import 'backup_crypto.dart';
import 'drive_service.dart';
import 'vault_snapshot.dart';

enum SyncState { idle, syncing, success, error }

/// Thrown when this would be the very first upload and the passphrase hasn't
/// been typed twice — a typo here would make the backup unrecoverable.
class PassphraseConfirmationRequired implements Exception {
  const PassphraseConfirmationRequired();
}

/// Orchestrates: download → decrypt → merge → apply locally → encrypt → upload.
class SyncController extends ChangeNotifier {
  SyncController({
    required this.drive,
    required this.vault,
    required this._keys,
    this.backupCrypto = const BackupCrypto(),
  });

  static const _kPassphrase = 'passforge_sync_passphrase';
  static const _kLastSync = 'passforge_last_sync';
  static const minPassphraseLength = 8;

  final DriveService drive;
  final VaultController vault;
  final BackupCrypto backupCrypto;
  final KeyStore _keys;

  SyncState _state = SyncState.idle;
  String? _message;
  DateTime? _lastSync;
  bool _hasSavedPassphrase = false;

  SyncState get state => _state;
  String? get message => _message;
  DateTime? get lastSync => _lastSync;
  bool get hasSavedPassphrase => _hasSavedPassphrase;
  bool get isSignedIn => drive.isSignedIn;
  String? get email => drive.email;

  Future<void> init() async {
    await drive.restoreSession();
    _hasSavedPassphrase = await _keys.read(_kPassphrase) != null;
    final ms = int.tryParse(await _keys.read(_kLastSync) ?? '');
    _lastSync = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    notifyListeners();
  }

  Future<void> signIn() async {
    try {
      await drive.signIn();
      _set(SyncState.idle, null);
    } catch (e) {
      _set(SyncState.error, 'Google sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    await drive.signOut();
    await _keys.delete(_kPassphrase);
    _hasSavedPassphrase = false;
    _set(SyncState.idle, null);
  }

  /// Runs a full two-way sync. Pass [passphrase] on first use; afterwards the
  /// one saved in the device keystore is used. Returns true on success.
  Future<bool> syncNow({String? passphrase, String? confirmation}) async {
    if (_state == SyncState.syncing) return false;
    final pass = passphrase ?? await _keys.read(_kPassphrase);
    if (pass == null || pass.length < minPassphraseLength) {
      _set(SyncState.error,
          'Enter a backup passphrase of at least $minPassphraseLength characters.');
      return false;
    }

    _set(SyncState.syncing, 'Syncing…');
    try {
      final remoteText = await drive.download();
      final local = await vault.exportSnapshot();

      final VaultSnapshot merged;
      if (remoteText == null) {
        // First ever upload: make sure the passphrase was typed correctly.
        if (passphrase != null && confirmation != passphrase) {
          _set(SyncState.idle, null);
          throw const PassphraseConfirmationRequired();
        }
        merged = local;
      } else {
        final remote = await backupCrypto.open(remoteText, pass);
        merged = mergeSnapshots(local, remote);
        await vault.applySnapshot(merged);
      }

      await drive.upload(await backupCrypto.seal(merged, pass));

      await _keys.write(_kPassphrase, pass);
      _hasSavedPassphrase = true;
      _lastSync = DateTime.now();
      await _keys.write(_kLastSync, '${_lastSync!.millisecondsSinceEpoch}');
      _set(SyncState.success, 'Synced ${merged.entries.length} passwords.');
      return true;
    } on PassphraseConfirmationRequired {
      rethrow;
    } on WrongPassphraseException catch (e) {
      _set(SyncState.error, '$e');
    } catch (e) {
      _set(SyncState.error, 'Sync failed: $e');
    }
    return false;
  }

  void _set(SyncState state, String? message) {
    _state = state;
    _message = message;
    notifyListeners();
  }
}
