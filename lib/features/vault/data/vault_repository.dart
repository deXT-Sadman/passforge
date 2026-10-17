import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../../core/security/key_store.dart';
import '../domain/password_item.dart';

/// Persistence contract — swap the storage engine without touching the UI.
abstract interface class VaultRepository {
  Future<List<PasswordItem>> loadAll();
  Future<void> saveAll(List<PasswordItem> items);

  /// Deletion markers (id → deletedAt, UTC) used by cloud sync.
  Future<Map<String, DateTime>> loadTombstones();
  Future<void> saveTombstones(Map<String, DateTime> tombstones);
}

/// Hive boxes encrypted at rest with AES-256 (HiveAesCipher).
///
/// The box key is random, lives only in the platform keystore, and is never
/// written next to the data. Items are stored as JSON strings keyed by id.
class HiveVaultRepository implements VaultRepository {
  HiveVaultRepository(this._keys);

  static const _keyName = 'passforge_box_key_v1';
  final KeyStore _keys;
  HiveCipher? _cipher;
  bool _initialized = false;
  final _boxes = <String, Box<String>>{};

  Future<Box<String>> _open(String name) async {
    final cached = _boxes[name];
    if (cached != null) return cached;
    if (!_initialized) {
      await Hive.initFlutter();
      _initialized = true;
    }
    _cipher ??= HiveAesCipher(await _keys.getOrCreateKey(_keyName));
    return _boxes[name] = await Hive.openBox<String>(name, encryptionCipher: _cipher);
  }

  @override
  Future<List<PasswordItem>> loadAll() async {
    final box = await _open('vault');
    return box.values
        .map((json) => PasswordItem.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveAll(List<PasswordItem> items) async {
    final box = await _open('vault');
    await box.clear();
    await box.putAll({for (final i in items) i.id: jsonEncode(i.toJson())});
  }

  @override
  Future<Map<String, DateTime>> loadTombstones() async {
    final box = await _open('tombstones');
    return {for (final e in box.toMap().entries) e.key as String: DateTime.parse(e.value).toUtc()};
  }

  @override
  Future<void> saveTombstones(Map<String, DateTime> tombstones) async {
    final box = await _open('tombstones');
    await box.clear();
    await box.putAll({
      for (final e in tombstones.entries) e.key: e.value.toUtc().toIso8601String(),
    });
  }
}
