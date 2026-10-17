import 'package:flutter/material.dart';

import '../../../core/security/clipboard_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/password_item.dart';
import 'password_form_screen.dart';
import 'vault_controller.dart';
import 'widgets/password_card.dart';

/// Home dashboard: header, search, category filters and the password list/grid.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final VaultController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _gridView = false;

  VaultController get _vault => widget.controller;

  Future<void> _openForm([PasswordItem? item]) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => PasswordFormScreen(controller: _vault, existing: item),
    ));
  }

  Future<void> _copy(PasswordItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final password = await _vault.revealPassword(item);
      await SecureClipboard.instance.copy(password);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    'Password copied. Clipboard clears in '
                    '${SecureClipboard.clearAfter.inSeconds}s.')),
          ]),
        ));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not decrypt this password.')));
    }
  }

  Future<void> _delete(PasswordItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete password?'),
        content: Text('"${item.title}" will be removed from your vault.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _vault.delete(item);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Deleted "${item.title}"'),
        action: SnackBarAction(label: 'Undo', onPressed: () => _vault.restore(item)),
      ));
  }

  void _onAction(PasswordItem item, CardAction action) => switch (action) {
        CardAction.edit => _openForm(item),
        CardAction.delete => _delete(item),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vault,
          builder: (context, _) {
            final items = _vault.visibleItems;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  gridView: _gridView,
                  onToggleView: () => setState(() => _gridView = !_gridView),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: SearchBar(
                    hintText: 'Search passwords',
                    leading: const Icon(Icons.search_rounded),
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor:
                        const WidgetStatePropertyAll(AppColors.surface),
                    onChanged: _vault.setQuery,
                  ),
                ),
                _CategoryFilter(
                    selected: _vault.category, onSelected: _vault.setCategory),
                Expanded(
                  child: _vault.loading
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? _EmptyState(vaultEmpty: _vault.isEmpty)
                          : _gridView
                              ? _buildGrid(items)
                              : _buildList(items),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card(PasswordItem item, {bool compact = false}) => PasswordCard(
        key: ValueKey(item.id),
        item: item,
        compact: compact,
        onCopy: () => _copy(item),
        onTap: () => _openForm(item),
        onAction: (a) => _onAction(item, a),
      );

  // Bottom padding keeps the last card clear of the FAB.
  static const _listPadding = EdgeInsets.fromLTRB(20, 4, 20, 96);

  Widget _buildList(List<PasswordItem> items) => ListView.separated(
        padding: _listPadding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(items[i]),
      );

  Widget _buildGrid(List<PasswordItem> items) => GridView.builder(
        padding: _listPadding,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisExtent: 188,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _card(items[i], compact: true),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.gridView, required this.onToggleView});

  final bool gridView;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryBright]),
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.black),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PassForge',
                style: text.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            Text('Forge Your Own Security.',
                style: text.bodySmall?.copyWith(color: Colors.white54)),
          ]),
        ),
        IconButton(
          tooltip: gridView ? 'List view' : 'Grid view',
          onPressed: onToggleView,
          icon: Icon(gridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded),
        ),
      ]),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.selected, required this.onSelected});

  final PasswordCategory? selected;
  final ValueChanged<PasswordCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final c in PasswordCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(c.icon, size: 16),
                label: Text(c.label),
                selected: selected == c,
                // Tapping the active chip returns to "All".
                onSelected: (_) => onSelected(selected == c ? null : c),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.vaultEmpty});
  final bool vaultEmpty;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(vaultEmpty ? Icons.lock_outline_rounded : Icons.search_off_rounded,
              size: 64, color: AppColors.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(vaultEmpty ? 'Your vault is empty' : 'No matches found',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
              vaultEmpty
                  ? 'Tap "Add" to save your first password.'
                  : 'Try a different search or category.',
              style: const TextStyle(color: Colors.white54)),
        ]),
      ),
    );
  }
}
