import 'dart:async';

import 'package:flutter/services.dart';

/// Copies secrets to the clipboard and wipes them after [clearAfter].
///
/// The clipboard is only cleared if it still holds the value we put there, so
/// we never destroy something the user copied afterwards.
class SecureClipboard {
  SecureClipboard._();
  static final instance = SecureClipboard._();

  static const clearAfter = Duration(seconds: 30);

  Timer? _timer;

  Future<void> copy(String secret) async {
    _timer?.cancel();
    await Clipboard.setData(ClipboardData(text: secret));
    _timer = Timer(clearAfter, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == secret) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }
}
