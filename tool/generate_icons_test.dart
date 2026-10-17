// Generates the launcher-icon / splash PNGs from the in-app logo painter.
//
// Run manually (it is not part of the normal test suite):
//   flutter test tool/generate_icons_test.dart
// Then apply them with:
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passforge/core/widgets/forge_logo.dart';

const _background = Color(0xFF1E1E2E);
const _px = 1024.0;

Future<void> _render(
  String path, {
  required double logoScale,
  Color? background,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (background != null) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, _px, _px), Paint()..color = background);
  }
  final side = _px * logoScale;
  canvas.translate((_px - side) / 2, (_px - side) / 2);
  const ForgeLogoPainter().paint(canvas, Size(side, side));

  final image = await recorder.endRecording().toImage(_px.toInt(), _px.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate icon PNGs', (tester) async {
    await tester.runAsync(() async {
      // Full icon (legacy launchers, iOS): logo on the brand background.
      await _render('assets/icon/app_icon.png', logoScale: 0.74, background: _background);
      // Adaptive-icon foreground / splash logo: transparent, kept inside the
      // central safe zone so circular and squircle masks never crop it.
      await _render('assets/icon/app_icon_foreground.png', logoScale: 0.56);
    });
  });
}
