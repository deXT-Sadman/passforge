import '../vault/domain/password_item.dart';

/// A password in portable form: the plain-text password is included because
/// the whole snapshot is encrypted with the user's backup passphrase before it
/// leaves the device (device keystore keys can't be moved between devices).
class BackupEntry {
  const BackupEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.category,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String username;
  final String password;
  final PasswordCategory category;
  final DateTime updatedAt; // always UTC

  factory BackupEntry.fromJson(Map<String, dynamic> j) => BackupEntry(
        id: j['id'] as String,
        title: j['title'] as String,
        username: j['username'] as String,
        password: j['password'] as String,
        category: PasswordCategory.fromName(j['category'] as String?),
        updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'category': category.name,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

/// Everything that gets synced: live entries plus deletion markers
/// ("tombstones"). Without tombstones a deleted item would be resurrected by
/// the next sync from a device that still has it.
class VaultSnapshot {
  const VaultSnapshot({this.entries = const {}, this.tombstones = const {}});

  final Map<String, BackupEntry> entries;

  /// id → when it was deleted (UTC).
  final Map<String, DateTime> tombstones;

  factory VaultSnapshot.fromJson(Map<String, dynamic> j) => VaultSnapshot(
        entries: {
          for (final e in (j['entries'] as List<dynamic>? ?? const []))
            (e as Map<String, dynamic>)['id'] as String: BackupEntry.fromJson(e),
        },
        tombstones: {
          for (final e in (j['tombstones'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: DateTime.parse(e.value as String).toUtc(),
        },
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        'entries': entries.values.map((e) => e.toJson()).toList(),
        'tombstones': {
          for (final e in tombstones.entries) e.key: e.value.toUtc().toIso8601String(),
        },
      };
}

/// Three-way-free, per-item "last write wins" merge.
///
/// Rules, applied per item id:
///  1. If both sides have the item, the newer `updatedAt` wins (tie → local).
///  2. A tombstone newer than (or equal to) the winning edit deletes the item.
///  3. An edit newer than the tombstone revives it (edited after deletion elsewhere).
///  4. Tombstones older than [tombstoneTtl] are dropped to keep the file small.
///
/// Timestamps come from each device's clock, so a badly skewed clock can win
/// unfairly; that's the accepted trade-off of serverless sync.
VaultSnapshot mergeSnapshots(
  VaultSnapshot local,
  VaultSnapshot remote, {
  DateTime? now,
  Duration tombstoneTtl = const Duration(days: 90),
}) {
  final clock = (now ?? DateTime.now()).toUtc();
  final entries = <String, BackupEntry>{};
  final tombstones = <String, DateTime>{};

  final ids = {
    ...local.entries.keys,
    ...remote.entries.keys,
    ...local.tombstones.keys,
    ...remote.tombstones.keys,
  };

  for (final id in ids) {
    final l = local.entries[id];
    final r = remote.entries[id];
    final winner = switch ((l, r)) {
      (null, null) => null,
      (final x?, null) => x,
      (null, final y?) => y,
      (final x?, final y?) => y.updatedAt.isAfter(x.updatedAt) ? y : x,
    };

    final tl = local.tombstones[id];
    final tr = remote.tombstones[id];
    final tomb = switch ((tl, tr)) {
      (null, null) => null,
      (final x?, null) => x,
      (null, final y?) => y,
      (final x?, final y?) => y.isAfter(x) ? y : x,
    };

    final deleted =
        tomb != null && (winner == null || !winner.updatedAt.isAfter(tomb));

    if (deleted) {
      if (clock.difference(tomb).abs() < tombstoneTtl) tombstones[id] = tomb;
    } else if (winner != null) {
      entries[id] = winner;
    }
  }
  return VaultSnapshot(entries: entries, tombstones: tombstones);
}
