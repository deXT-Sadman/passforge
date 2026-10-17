import 'package:flutter/material.dart';

import '../../domain/password_item.dart';
import 'platform_avatar.dart';

enum CardAction { edit, delete }

/// A single vault entry. Renders as a row in list mode, or a tile in grid mode.
class PasswordCard extends StatelessWidget {
  const PasswordCard({
    super.key,
    required this.item,
    required this.onCopy,
    required this.onTap,
    required this.onAction,
    this.compact = false,
  });

  final PasswordItem item;

  /// Copies the password; returns true if it worked (drives the ✓ animation).
  final Future<bool> Function() onCopy;
  final VoidCallback onTap;
  final ValueChanged<CardAction> onAction;

  /// true → grid tile layout, false → list row layout.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final copyButton = _CopyButton(onCopy: onCopy, compact: compact);

    final menu = PopupMenuButton<CardAction>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      onSelected: onAction,
      itemBuilder: (_) => const [
        PopupMenuItem(value: CardAction.edit, child: Text('Edit')),
        PopupMenuItem(value: CardAction.delete, child: Text('Delete')),
      ],
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(item.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      PlatformAvatar(
                          title: item.title, iconPath: item.iconPath, size: 44),
                      const Spacer(),
                      SizedBox(width: 32, height: 32, child: menu),
                    ]),
                    const Spacer(),
                    titleBlock,
                    const SizedBox(height: 10),
                    Row(children: [
                      Flexible(child: _CategoryChip(category: item.category)),
                      const SizedBox(width: 8),
                      copyButton,
                    ]),
                  ],
                )
              : Row(children: [
                  PlatformAvatar(title: item.title, iconPath: item.iconPath),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        const SizedBox(height: 6),
                        _CategoryChip(category: item.category),
                      ],
                    ),
                  ),
                  copyButton,
                  menu,
                ]),
        ),
      ),
    );
  }
}

/// Copy button that morphs into a green check for 2s after a successful copy.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.onCopy, required this.compact});

  final Future<bool> Function() onCopy;
  final bool compact;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _done = false;

  Future<void> _press() async {
    final ok = await widget.onCopy();
    if (!ok || !mounted) return;
    setState(() => _done = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _done = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _done ? scheme.secondary : scheme.primary;

    return IconButton.filledTonal(
      tooltip: 'Copy password (clears in 30s)',
      onPressed: _press,
      style: IconButton.styleFrom(
        // Slimmer button in grid tiles so the card content fits its height.
        visualDensity: widget.compact ? VisualDensity.compact : null,
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
      ),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          _done ? Icons.check_rounded : Icons.copy_rounded,
          key: ValueKey(_done),
          size: 20,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final PasswordCategory category;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(category.icon, size: 13, color: primary),
      const SizedBox(width: 4),
      Flexible(
        child: Text(category.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: primary)),
      ),
    ]);
  }
}
