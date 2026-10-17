import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../vault/presentation/vault_controller.dart';
import 'backup_crypto.dart';
import 'vault_snapshot.dart';

/// Export / import of an encrypted backup file (`.pfbak`).
///
/// Uses the same passphrase-encrypted format as the Drive backup, so a file
/// exported here is also readable on any other device with the passphrase.
class LocalBackupService {
  LocalBackupService(this.vault, {this.crypto = const BackupCrypto()});

  final VaultController vault;
  final BackupCrypto crypto;

  static const fileExtension = 'pfbak';

  /// Lets the user choose where to save. Returns false if they cancelled.
  Future<bool> export(String passphrase) async {
    final sealed = await crypto.seal(await vault.exportSnapshot(), passphrase);
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save encrypted backup',
      fileName: 'passforge-backup-${d.year}-${two(d.month)}-${two(d.day)}.$fileExtension',
      bytes: utf8.encode(sealed),
    );
    return saved != null;
  }

  /// Lets the user choose a backup file. Returns its text, or null if cancelled.
  Future<String?> pickBackup() async {
    // FileType.any: Android has no reliable MIME type for a custom extension.
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a PassForge backup');
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes());
  }

  /// Merges a backup into the vault (nothing is overwritten blindly: the
  /// newest version of each password wins). Returns the resulting item count.
  Future<int> import(String backupText, String passphrase) async {
    final remote = await crypto.open(backupText, passphrase);
    final merged = mergeSnapshots(await vault.exportSnapshot(), remote);
    await vault.applySnapshot(merged);
    return merged.entries.length;
  }
}
