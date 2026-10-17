import 'package:flutter_test/flutter_test.dart';
import 'package:passforge/features/sync/backup_crypto.dart';
import 'package:passforge/features/sync/vault_snapshot.dart';
import 'package:passforge/features/vault/domain/password_item.dart';

BackupEntry entry(String id, String title, DateTime at, {String pw = 'pw'}) =>
    BackupEntry(
      id: id,
      title: title,
      username: 'u',
      password: pw,
      category: PasswordCategory.other,
      updatedAt: at.toUtc(),
    );

void main() {
  final t1 = DateTime.utc(2026, 1, 1);
  final t2 = DateTime.utc(2026, 1, 2);
  final t3 = DateTime.utc(2026, 1, 3);
  final now = DateTime.utc(2026, 1, 10);

  group('mergeSnapshots', () {
    test('newer edit wins per item', () {
      final local = VaultSnapshot(entries: {'a': entry('a', 'old', t1)});
      final remote = VaultSnapshot(entries: {'a': entry('a', 'new', t2)});
      expect(mergeSnapshots(local, remote, now: now).entries['a']!.title, 'new');
      expect(mergeSnapshots(remote, local, now: now).entries['a']!.title, 'new');
    });

    test('items unique to each side are both kept', () {
      final local = VaultSnapshot(entries: {'a': entry('a', 'A', t1)});
      final remote = VaultSnapshot(entries: {'b': entry('b', 'B', t1)});
      expect(mergeSnapshots(local, remote, now: now).entries.keys, {'a', 'b'});
    });

    test('tombstone newer than edit deletes the item', () {
      final local = VaultSnapshot(tombstones: {'a': t2});
      final remote = VaultSnapshot(entries: {'a': entry('a', 'A', t1)});
      final merged = mergeSnapshots(local, remote, now: now);
      expect(merged.entries, isEmpty);
      expect(merged.tombstones.keys, ['a']);
    });

    test('edit newer than tombstone revives the item', () {
      final local = VaultSnapshot(tombstones: {'a': t1});
      final remote = VaultSnapshot(entries: {'a': entry('a', 'A', t3)});
      final merged = mergeSnapshots(local, remote, now: now);
      expect(merged.entries.keys, ['a']);
      expect(merged.tombstones, isEmpty);
    });

    test('old tombstones are pruned', () {
      final local = VaultSnapshot(tombstones: {'a': t1});
      final merged = mergeSnapshots(local, const VaultSnapshot(),
          now: t1.add(const Duration(days: 100)));
      expect(merged.tombstones, isEmpty);
    });
  });

  group('BackupCrypto', () {
    const crypto = BackupCrypto();
    final snap = VaultSnapshot(
      entries: {'a': entry('a', 'GitHub', t1, pw: 's3cret!')},
      tombstones: {'z': t2},
    );

    test('round trips with the right passphrase', () async {
      final sealed = await crypto.seal(snap, 'correct horse');
      expect(sealed.contains('s3cret!'), isFalse);
      final opened = await crypto.open(sealed, 'correct horse');
      expect(opened.entries['a']!.password, 's3cret!');
      expect(opened.tombstones['z'], t2);
    });

    test('wrong passphrase is rejected', () async {
      final sealed = await crypto.seal(snap, 'correct horse');
      expect(crypto.open(sealed, 'battery staple'),
          throwsA(isA<WrongPassphraseException>()));
    });
  });
}
