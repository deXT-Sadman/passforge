import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passforge/core/theme/app_theme.dart';
import 'package:passforge/features/vault/presentation/widgets/empty_state.dart';

Widget host(ThemeData theme, Widget child) =>
    MaterialApp(theme: theme, home: Scaffold(body: child));

void main() {
  for (final entry in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
    testWidgets('empty vault shows CTA (${entry.key})', (tester) async {
      var added = false;
      await tester.pumpWidget(host(
        entry.value,
        EmptyState(vaultEmpty: true, onAdd: () => added = true),
      ));
      // The badge animates forever, so pump fixed frames instead of settling.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Your vault is empty'), findsOneWidget);
      await tester.tap(find.text('Add your first password'));
      expect(added, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no-match state offers clearing filters (${entry.key})',
        (tester) async {
      var cleared = false;
      await tester.pumpWidget(host(
        entry.value,
        EmptyState(vaultEmpty: false, onClearFilters: () => cleared = true),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('No matches found'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      expect(cleared, isTrue);
    });
  }
}
