import 'package:flutter/material.dart';

import 'lock_controller.dart';
import 'lock_screen.dart';

/// Wraps the whole app (via MaterialApp.builder) and covers it with the lock
/// screen whenever the vault is locked — including any pushed routes.
///
/// The app underneath stays mounted but hidden, so navigation and scroll
/// state survive a lock/unlock cycle.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.controller, required this.child});

  final LockController controller;
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // `inactive` is deliberately ignored: it also fires for system dialogs
      // such as the biometric prompt and notification shade.
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        widget.controller.lock();
      case AppLifecycleState.resumed:
        widget.controller.unlockWithBiometric(); // no-op unless locked
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final status = widget.controller.status;
        if (status == LockStatus.loading) {
          return ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final unlocked = status == LockStatus.unlocked;
        return Stack(children: [
          // Hidden + non-interactive while locked, but state is preserved.
          Offstage(offstage: !unlocked, child: TickerMode(enabled: unlocked, child: widget.child)),
          if (!unlocked)
            Positioned.fill(child: LockScreen(controller: widget.controller)),
        ]);
      },
    );
  }
}
