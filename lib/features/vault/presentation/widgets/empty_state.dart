import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';

/// Shown when the vault has no passwords yet, or when search/filter finds none.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.vaultEmpty,
    this.onAdd,
    this.onClearFilters,
  });

  /// true → nothing saved at all; false → saved items exist but none match.
  final bool vaultEmpty;
  final VoidCallback? onAdd;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // FadeSlideIn sits *outside* the scroll view: sliding content inside a
    // shrink-wrapped scroll view gets clipped by its viewport mid-animation.
    return Center(
      child: FadeSlideIn(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _FloatingBadge(
              icon: vaultEmpty ? Icons.lock_outline_rounded : Icons.search_off_rounded,
            ),
            const SizedBox(height: 28),
            Text(
              vaultEmpty ? 'Your vault is empty' : 'No matches found',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              vaultEmpty
                  ? 'Add your first password. It is encrypted on this device before it is saved.'
                  : 'Try a different search or clear the filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (vaultEmpty && onAdd != null)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add your first password'),
              )
            else if (!vaultEmpty && onClearFilters != null)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Clear filters'),
              ),
          ]),
        ),
      ),
    );
  }
}

/// A glowing icon badge that bobs up and down slowly.
class _FloatingBadge extends StatefulWidget {
  const _FloatingBadge({required this.icon});
  final IconData icon;

  @override
  State<_FloatingBadge> createState() => _FloatingBadgeState();
}

class _FloatingBadgeState extends State<_FloatingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final badge = Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withValues(alpha: 0.12),
        border: Border.all(color: primary.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: primary.withValues(alpha: 0.25), blurRadius: 36, spreadRadius: 2),
        ],
      ),
      child: Icon(widget.icon, size: 52, color: AppColors.primary),
    );

    // No continuous motion if the user asked the OS to reduce animations.
    if (MediaQuery.disableAnimationsOf(context)) return badge;

    return AnimatedBuilder(
      animation: _controller,
      child: badge,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -8 * Curves.easeInOutSine.transform(_controller.value)),
        child: child,
      ),
    );
  }
}
