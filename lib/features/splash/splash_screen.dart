import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/forge_logo.dart';

/// Animated splash: the shield is traced, fills with colour, the keyhole pops
/// in, then the name appears above a looping "forging" loading bar.
///
/// It always uses the dark brand colours (not the user's theme) so it flows
/// seamlessly out of the native splash, which is the same charcoal colour.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1; // reduce-motion: show the finished state, no looping
    } else {
      _intro.forward();
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// Maps the intro timeline to a sub-range with an easing curve.
  Animation<double> _phase(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final outline = _phase(0.0, 0.5, Curves.easeInOut);
    final fill = _phase(0.35, 0.7, Curves.easeIn);
    final keyhole = _phase(0.6, 0.9, Curves.elasticOut);
    final title = _phase(0.55, 0.85);
    final tagline = _phase(0.7, 1.0);

    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 200,
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _loop]),
                builder: (context, _) {
                  // Soft glow behind the shield that breathes once it has filled.
                  final pulse = 0.5 + 0.5 * Curves.easeInOut.transform(
                      (_loop.value < 0.5 ? _loop.value : 1 - _loop.value) * 2);
                  return Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: 0.30 * fill.value * (0.6 + 0.4 * pulse)),
                            blurRadius: 60,
                            spreadRadius: 6 + 8 * pulse,
                          ),
                        ],
                      ),
                    ),
                    CustomPaint(
                      size: const Size.square(150),
                      painter: ForgeLogoPainter(
                        draw: outline.value,
                        fill: fill.value,
                        keyhole: keyhole.value,
                      ),
                    ),
                  ]);
                },
              ),
            ),
            const SizedBox(height: 20),
            _Reveal(
              animation: title,
              child: const Text(
                'PassForge',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _Reveal(
              animation: tagline,
              child: const Text(
                'Forge Your Own Security.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
            const SizedBox(height: 44),
            _Reveal(
              animation: tagline,
              child: _LoadingBar(animation: _loop),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fade + small upward slide driven by an animation.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
          child: child,
        ),
      );
}

/// Indeterminate bar: a glowing segment sweeps across a faint track.
class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.animation});

  final Animation<double> animation;

  static const _width = 140.0;
  static const _segment = 52.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.10))),
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(animation.value);
              return Positioned(
                left: -_segment + t * (_width + _segment),
                width: _segment,
                top: 0,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0x0000E5FF),
                      AppColors.primaryBright,
                      Color(0x0000E5FF),
                    ]),
                  ),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

/// Shows [SplashScreen] until the app is ready *and* the animation has had
/// [minDuration] to play, then cross-fades to [child].
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.listenable,
    required this.isReady,
    required this.child,
    this.minDuration = const Duration(milliseconds: 2200),
  });

  /// Notifies when readiness may have changed (e.g. the lock controller).
  final Listenable listenable;
  final bool Function() isReady;
  final Widget child;
  final Duration minDuration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Timer? _timer;
  bool _minElapsed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minDuration, () {
      if (mounted) setState(() => _minElapsed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, _) {
        final done = _minElapsed && widget.isReady();
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: done
              ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
              : const SplashScreen(key: ValueKey('splash')),
        );
      },
    );
  }
}
