import 'package:flutter_test/flutter_test.dart';
import 'package:passforge/features/vault/domain/password_item.dart';

void main() {
  test('PasswordItem survives a JSON round trip', () {
    final item = PasswordItem(
      id: '1',
      title: 'GitHub',
      username: 'me@example.com',
      encryptedPassword: 'iv:cipher',
      category: PasswordCategory.work,
      updatedAt: DateTime(2026, 1, 1),
    );
    final copy = PasswordItem.fromJson(item.toJson());
    expect(copy.title, 'GitHub');
    expect(copy.category, PasswordCategory.work);
    expect(copy.updatedAt, item.updatedAt);
    expect(copy.iconPath, isNull);
  });
}
