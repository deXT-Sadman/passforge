import 'package:flutter/material.dart';

import '../../../core/security/clipboard_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../settings/settings_screen.dart';
import '../../sync/local_backup.dart';
import '../../sync/sync_controller.dart';
import '../domain/password_item.dart';
import 'password_form_screen.dart';
import 'vault_controller.dart';
import 'widgets/empty_state.dart';
import 'widgets/password_card.dart';

/// Home dashboard: header, search, category filters and the password list/grid.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.sync,
    required this.theme,
  });

  final VaultController controller;
  final SyncController sync;
  final ThemeController theme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  bool _gridView = false;

  VaultController get _vault => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm([PasswordItem? item]) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => PasswordFormScreen(controller: _vault, existing: item),
    ));
  }

  void _openSettings() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        sync: widget.sync,
        theme: widget.theme,
        backup: LocalBackupService(_vault),
      ),
    ));
  }

  void _clearFilters() {
    _search.clear();
    _vault.setQuery('');
    _vault.setCategory(null);
  }

  /// Returns true when the password was copied (drives the ✓ animation).
  Future<bool> _copy(PasswordItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final accent = Theme.of(context).colorScheme.secondary;
    try {
      final password = await _vault.revealPassword(item);
      await SecureClipboard.instance.copy(password);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_rounded, color: accent),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    'Password copied. Clipboard clears in '
                    '${SecureClipboard.clearAfter.inSeconds}s.')),
          ]),
        ));
      return true;
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not decrypt this password.')));
      return false;
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
              child: Text('Delete',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
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
                  onSettings: _openSettings,
                  gridView: _gridView,
                  onToggleView: () => setState(() => _gridView = !_gridView),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: SearchBar(
                    controller: _search,
                    hintText: 'Search passwords',
                    leading: const Icon(Icons.search_rounded),
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: WidgetStatePropertyAll(
                        Theme.of(context).colorScheme.surface),
                    onChanged: _vault.setQuery,
                  ),
                ),
                _CategoryFilter(
                    selected: _vault.category, onSelected: _vault.setCategory),
                Expanded(
                  // Cross-fades between loading / empty / list / grid.
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOut,
                    child: KeyedSubtree(
                      key: ValueKey(_viewKey(items)),
                      child: _vault.loading
                          ? const Center(child: CircularProgressIndicator())
                          : items.isEmpty
                              ? EmptyState(
                                  vaultEmpty: _vault.isEmpty,
                                  onAdd: _openForm,
                                  onClearFilters: _clearFilters,
                                )
                              : _gridView
                                  ? _buildGrid(items)
                                  : _buildList(items),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Changes only when the *kind* of content changes, not on every keystroke.
  String _viewKey(List<PasswordItem> items) {
    if (_vault.loading) return 'loading';
    if (items.isEmpty) return _vault.isEmpty ? 'empty' : 'no-match';
    return _gridView ? 'grid' : 'list';
  }

  Widget _card(PasswordItem item, int index, {bool compact = false}) =>
      FadeSlideIn(
        key: ValueKey(item.id),
        index: index,
        child: PasswordCard(
          item: item,
          compact: compact,
          onCopy: () => _copy(item),
          onTap: () => _openForm(item),
          onAction: (a) => _onAction(item, a),
        ),
      );

  // Bottom padding keeps the last card clear of the FAB.
  static const _listPadding = EdgeInsets.fromLTRB(20, 4, 20, 96);

  Widget _buildList(List<PasswordItem> items) => ListView.separated(
        padding: _listPadding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(items[i], i),
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
        itemBuilder: (_, i) => _card(items[i], i, compact: true),
      );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.gridView,
    required this.onToggleView,
    required this.onSettings,
  });

  final VoidCallback onSettings;
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
                style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
        IconButton(
          tooltip: gridView ? 'List view' : 'Grid view',
          onPressed: onToggleView,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              gridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
              key: ValueKey(gridView),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_rounded),
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
