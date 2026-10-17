import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/security/crypto_service.dart';
import '../../sync/vault_snapshot.dart';
import '../data/vault_repository.dart';
import '../domain/password_item.dart';

/// Holds vault state and exposes search/filter + CRUD to the UI.
class VaultController extends ChangeNotifier {
  VaultController({required this.repository, required this.crypto});

  final VaultRepository repository;
  final CryptoService crypto;

  List<PasswordItem> _items = [];
  Map<String, DateTime> _tombstones = {};
  String _query = '';
  PasswordCategory? _category;
  bool _loading = true;

  bool get loading => _loading;
  PasswordCategory? get category => _category;

  /// Items matching the current search query and category filter.
  List<PasswordItem> get visibleItems {
    final q = _query.toLowerCase();
    return _items.where((i) {
      final matchesCategory = _category == null || i.category == _category;
      final matchesQuery = q.isEmpty ||
          i.title.toLowerCase().contains(q) ||
          i.username.toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  bool get isEmpty => _items.isEmpty;

  Future<void> load() async {
    _items = await repository.loadAll();
    _tombstones = await repository.loadTombstones();
    _loading = false;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value.trim();
    notifyListeners();
  }

  void setCategory(PasswordCategory? value) {
    _category = value;
    notifyListeners();
  }

  Future<String> revealPassword(PasswordItem item) =>
      crypto.decrypt(item.encryptedPassword);

  /// Creates a new item, or updates [existing] when provided.
  Future<void> save({
    PasswordItem? existing,
    required String title,
    required String username,
    required String plainPassword,
    required PasswordCategory category,
    String? iconPath,
  }) async {
    final encrypted = await crypto.encrypt(plainPassword);
    final now = DateTime.now();
    if (existing == null) {
      _items.add(PasswordItem(
        id: const Uuid().v4(),
        title: title,
        username: username,
        encryptedPassword: encrypted,
        category: category,
        iconPath: iconPath,
        updatedAt: now,
      ));
    } else {
      final index = _items.indexWhere((i) => i.id == existing.id);
      _items[index] = existing.copyWith(
        title: title,
        username: username,
        encryptedPassword: encrypted,
        category: category,
        iconPath: iconPath,
        clearIcon: iconPath == null,
        updatedAt: now,
      );
    }
    await _persist();
  }

  Future<void> delete(PasswordItem item) async {
    _items.removeWhere((i) => i.id == item.id);
    // Leave a marker so sync deletes it on other devices too.
    _tombstones[item.id] = DateTime.now().toUtc();
    await _persist();
  }

  /// Re-inserts a deleted item (snackbar "Undo").
  Future<void> restore(PasswordItem item) async {
    _items.add(item);
    _tombstones.remove(item.id);
    await _persist();
  }

  // ---- Cloud sync support ---------------------------------------------

  /// Decrypts everything into a portable snapshot (stays in memory only).
  Future<VaultSnapshot> exportSnapshot() async => VaultSnapshot(
        entries: {
          for (final i in _items)
            i.id: BackupEntry(
              id: i.id,
              title: i.title,
              username: i.username,
              password: await crypto.decrypt(i.encryptedPassword),
              category: i.category,
              updatedAt: i.updatedAt.toUtc(),
            ),
        },
        tombstones: Map.of(_tombstones),
      );

  /// Replaces local data with a merged snapshot. Items whose timestamp is
  /// unchanged keep their existing ciphertext; only new/changed ones are
  /// re-encrypted with this device's key.
  Future<void> applySnapshot(VaultSnapshot merged) async {
    final local = {for (final i in _items) i.id: i};
    final next = <PasswordItem>[];
    for (final e in merged.entries.values) {
      final existing = local[e.id];
      if (existing != null && existing.updatedAt.isAtSameMomentAs(e.updatedAt)) {
        next.add(existing);
      } else {
        next.add(PasswordItem(
          id: e.id,
          title: e.title,
          username: e.username,
          encryptedPassword: await crypto.encrypt(e.password),
          category: e.category,
          iconPath: existing?.iconPath, // logos are device-local, not synced
          updatedAt: e.updatedAt,
        ));
      }
    }
    _items = next;
    _tombstones = Map.of(merged.tombstones);
    await _persist();
  }

  Future<void> _persist() async {
    await repository.saveAll(_items);
    await repository.saveTombstones(_tombstones);
    notifyListeners();
  }
}
