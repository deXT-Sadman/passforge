import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'lock_controller.dart';

/// Full-screen PIN pad used for first-time setup and for unlocking.
/// Uses a custom keypad (no TextField) so it works above the Navigator.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.controller});

  final LockController controller;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entry = '';
  String? _firstEntry; // setup: remembers the first PIN while confirming
  String? _error;
  Timer? _ticker;

  LockController get _lock => widget.controller;
  bool get _isSetup => _lock.status == LockStatus.needsSetup;

  @override
  void initState() {
    super.initState();
    _startTickerIfThrottled();
    // Only prompt when visible; a lock that happens in the background is
    // prompted by LockGate once the app resumes.
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _lock.unlockWithBiometric());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Refreshes the lockout countdown once per second.
  void _startTickerIfThrottled() {
    _ticker?.cancel();
    if (_lock.lockoutRemaining == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_lock.lockoutRemaining == null) {
        t.cancel();
        setState(() => _error = null);
      } else {
        setState(() {});
      }
    });
  }

  void _onDigit(String d) {
    if (_entry.length >= LockController.pinLength) return;
    if (_lock.lockoutRemaining != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entry += d;
      _error = null;
    });
    if (_entry.length == LockController.pinLength) _submit();
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    final pin = _entry;
    if (_isSetup) {
      if (_firstEntry == null) {
        setState(() {
          _firstEntry = pin;
          _entry = '';
        });
      } else if (_firstEntry == pin) {
        await _lock.setupPin(pin);
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _firstEntry = null;
          _entry = '';
          _error = "PINs didn't match. Start again.";
        });
      }
      return;
    }

    final result = await _lock.unlockWithPin(pin);
    if (!mounted || result == PinResult.success) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _entry = '';
      _error = result == PinResult.wrong ? 'Wrong PIN' : null;
    });
    _startTickerIfThrottled();
  }

  String get _title {
    if (!_isSetup) return 'Unlock PassForge';
    return _firstEntry == null ? 'Create a PIN' : 'Confirm your PIN';
  }

  String? get _subtitle {
    final left = _lock.lockoutRemaining;
    if (left != null) {
      return 'Too many attempts. Try again in ${left.inSeconds + 1}s.';
    }
    if (_error != null) return _error;
    if (_isSetup) return 'Choose a ${LockController.pinLength}-digit PIN to protect your vault.';
    return 'Enter your PIN';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isError = _error != null || _lock.lockoutRemaining != null;
    final canUseBio = !_isSetup && _lock.biometricEnabled;

    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryBright]),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      size: 36, color: Colors.black),
                ),
                const SizedBox(height: 20),
                Text(_title,
                    style: text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _subtitle ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isError ? AppColors.error : Colors.white60),
                  ),
                ),
                const SizedBox(height: 28),
                _PinDots(filled: _entry.length, error: isError),
                const SizedBox(height: 32),
                _Keypad(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  onBiometric: canUseBio ? _lock.unlockWithBiometric : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled, required this.error});
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < LockController.pinLength; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? (error ? AppColors.error : AppColors.primary)
                  : Colors.transparent,
              border: Border.all(
                  color: error ? AppColors.error : AppColors.primary, width: 2),
            ),
          ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback? onTap) => Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 72,
            height: 72,
            child: onTap == null
                ? null
                : Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onTap,
                        child: Center(child: child)),
                  ),
          ),
        );

    Widget digit(String d) => key(
        Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
        () => onDigit(d));

    return Column(children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) digit(d)]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        key(const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
            onBiometric),
        digit('0'),
        key(const Icon(Icons.backspace_outlined), onBackspace),
      ]),
    ]);
  }
}
