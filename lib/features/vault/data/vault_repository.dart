import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/password_item.dart';

/// Persistence contract — swap for SQLite/Drift/cloud without touching UI.
abstract interface class VaultRepository {
  Future<List<PasswordItem>> loadAll();
  Future<void> saveAll(List<PasswordItem> items);
}

/// Stores the vault as a JSON file in the app documents directory.
/// Passwords inside are already encrypted by [CryptoService].
class FileVaultRepository implements VaultRepository {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/vault.json');
  }

  @override
  Future<List<PasswordItem>> loadAll() async {
    final file = await _file();
    if (!await file.exists()) return [];
    final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
    return raw
        .map((e) => PasswordItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveAll(List<PasswordItem> items) async {
    final file = await _file();
    // Write to a temp file first so a crash can't corrupt the vault.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
    await tmp.rename(file.path);
  }
}
