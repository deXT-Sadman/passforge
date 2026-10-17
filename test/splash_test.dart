import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passforge/features/splash/splash_screen.dart';

void main() {
  testWidgets('splash shows until ready and min duration passed, then app', (tester) async {
    final ready = ValueNotifier(false);
    await tester.pumpWidget(MaterialApp(
      home: SplashGate(
        listenable: ready,
        isReady: () => ready.value,
        minDuration: const Duration(milliseconds: 500),
        child: const Text('APP'),
      ),
    ));

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PassForge'), findsOneWidget);
    expect(find.text('APP'), findsNothing);

    // Min duration elapsed but app not ready → still splashing.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('APP'), findsNothing);

    ready.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('APP'), findsOneWidget);
    expect(find.text('PassForge'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
