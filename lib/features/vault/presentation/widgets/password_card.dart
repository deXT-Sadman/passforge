import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
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
  final VoidCallback onCopy;
  final VoidCallback onTap;
  final ValueChanged<CardAction> onAction;

  /// true → grid tile layout, false → list row layout.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final copyButton = IconButton.filledTonal(
      tooltip: 'Copy password (clears in 30s)',
      onPressed: onCopy,
      style: IconButton.styleFrom(
        // Slimmer button in grid tiles so the card content fits its height.
        visualDensity: compact ? VisualDensity.compact : null,
        backgroundColor: AppColors.primary.withValues(alpha: 0.16),
        foregroundColor: AppColors.primary,
      ),
      icon: const Icon(Icons.copy_rounded, size: 20),
    );

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
            style: text.bodySmall?.copyWith(color: Colors.white60)),
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
                      _CategoryChip(category: item.category),
                      const Spacer(),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final PasswordCategory category;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(category.icon, size: 13, color: AppColors.primary),
      const SizedBox(width: 4),
      Text(category.label,
          style: const TextStyle(fontSize: 12, color: AppColors.primary)),
    ]);
  }
}
