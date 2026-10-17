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

  // Regression: a Stack whose only non-positioned child is Offstage (exactly
  // what LockGate looks like while locked) used to collapse to 0x0 inside the
  // gate, leaving a black screen.
  testWidgets('a locked-style Stack child fills the whole screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashGate(
        listenable: ValueNotifier(true),
        isReady: () => true,
        minDuration: const Duration(milliseconds: 100),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Offstage(child: SizedBox.expand()),
            Positioned.fill(child: Container(key: const Key('lock'), color: Colors.red)),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.getSize(find.byKey(const Key('lock'))), tester.view.physicalSize / tester.view.devicePixelRatio);
  });
}
