import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'sync_controller.dart';

/// Bottom sheet: Google sign-in, backup passphrase and "Sync now".
Future<void> showSyncSheet(BuildContext context, SyncController controller) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _SyncSheet(controller: controller),
    ),
  );
}

class _SyncSheet extends StatefulWidget {
  const _SyncSheet({required this.controller});
  final SyncController controller;

  @override
  State<_SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends State<_SyncSheet> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _needsConfirm = false;
  bool _obscure = true;

  SyncController get _sync => widget.controller;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      await _sync.syncNow(
        passphrase: _pass.text.isEmpty ? null : _pass.text,
        confirmation: _needsConfirm ? _confirm.text : null,
      );
    } on PassphraseConfirmationRequired {
      // First upload: ask the user to type the passphrase again.
      setState(() => _needsConfirm = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sync,
      builder: (context, _) {
        final busy = _sync.state == SyncState.syncing;
        final needsPassphrase = !_sync.hasSavedPassphrase;
        final text = Theme.of(context).textTheme;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Google Drive backup',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Encrypted on this device with your passphrase, then stored in a '
                'hidden app folder only PassForge can access.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 20),
              if (!_sync.isSignedIn)
                FilledButton.icon(
                  onPressed: _sync.signIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in with Google'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                )
              else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle_rounded, color: AppColors.primary),
                  title: Text(_sync.email ?? ''),
                  subtitle: Text(_sync.lastSync == null
                      ? 'Never synced'
                      : 'Last sync: ${_sync.lastSync!.toLocal().toString().split('.').first}'),
                  trailing: TextButton(onPressed: _sync.signOut, child: const Text('Sign out')),
                ),
                if (needsPassphrase) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pass,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Backup passphrase',
                      helperText: 'New device? Enter the passphrase you set before. '
                          'It cannot be recovered if forgotten.',
                      helperMaxLines: 3,
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_needsConfirm) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(labelText: 'Confirm passphrase'),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy ? null : _run,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded),
                  label: Text(busy ? 'Syncing…' : 'Sync now'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ],
              if (_sync.message != null && !busy) ...[
                const SizedBox(height: 12),
                Text(
                  _sync.message!,
                  style: TextStyle(
                    color: _sync.state == SyncState.error
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
