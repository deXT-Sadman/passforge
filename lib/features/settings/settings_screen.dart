import 'package:flutter/material.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../sync/backup_crypto.dart';
import '../sync/local_backup.dart';
import '../sync/passphrase_dialog.dart';
import '../sync/sync_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.sync,
    required this.theme,
    required this.backup,
  });

  final SyncController sync;
  final ThemeController theme;
  final LocalBackupService backup;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _fileBusy = false; // export / import in progress

  SyncController get _sync => widget.sync;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- Cloud sync ----------------------------------------------------

  Future<void> _syncNow() async {
    if (!_sync.hasSavedPassphrase) {
      // First sync on this device: ask once. If it turns out to be the very
      // first upload, ask again with confirmation (typo = unrecoverable backup).
      final pass = await askPassphrase(
        context,
        title: 'Backup passphrase',
        message: 'New device? Enter the passphrase you chose on your first device.',
      );
      if (pass == null || !mounted) return;
      try {
        await _sync.syncNow(passphrase: pass);
      } on PassphraseConfirmationRequired {
        if (!mounted) return;
        final confirmed = await askPassphrase(
          context,
          title: 'Create backup passphrase',
          message: 'This encrypts your cloud backup. If you forget it, the backup '
              'cannot be recovered.',
          confirm: true,
          actionLabel: 'Create & sync',
        );
        if (confirmed != null) {
          await _sync.syncNow(passphrase: confirmed, confirmation: confirmed);
        }
      }
    } else {
      await _sync.syncNow();
    }
  }

  // ---- Local file backup ---------------------------------------------

  Future<void> _export() async {
    final pass = await askPassphrase(
      context,
      title: 'Encrypt backup file',
      message: 'Choose a passphrase for this file. You will need it to import the backup.',
      confirm: true,
      actionLabel: 'Export',
    );
    if (pass == null) return;
    setState(() => _fileBusy = true);
    try {
      final saved = await widget.backup.export(pass);
      _toast(saved ? 'Encrypted backup saved.' : 'Export cancelled.');
    } catch (e) {
      _toast('Export failed: $e');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _fileBusy = true);
    try {
      final text = await widget.backup.pickBackup();
      if (text == null || !mounted) return;
      final pass = await askPassphrase(
        context,
        title: 'Import backup',
        message: 'Enter the passphrase this backup was encrypted with.',
        actionLabel: 'Import',
      );
      if (pass == null) return;
      final count = await widget.backup.import(text, pass);
      _toast('Backup imported. Your vault now has $count passwords.');
    } on WrongPassphraseException catch (e) {
      _toast('$e');
    } catch (e) {
      _toast('Import failed: $e');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _accountSection(context),
      _appearanceSection(context),
      _backupSection(context),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: FadeSlideIn(index: i, child: sections[i]),
            ),
        ],
      ),
    );
  }

  Widget _accountSection(BuildContext context) {
    return ListenableBuilder(
      listenable: _sync,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final busy = _sync.state == SyncState.syncing;
        final signedIn = _sync.isSignedIn;

        return _Section(
          title: 'Google Drive',
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                child: Icon(
                  signedIn ? Icons.account_circle_rounded : Icons.person_off_rounded,
                  color: scheme.primary,
                ),
              ),
              title: Text(signedIn ? (_sync.email ?? 'Signed in') : 'Not signed in'),
              subtitle: Text(signedIn
                  ? 'Backups go to a hidden app folder'
                  : 'Sign in to back up and sync your vault'),
              trailing: signedIn
                  ? TextButton(onPressed: busy ? null : _sync.signOut, child: const Text('Sign out'))
                  : FilledButton(onPressed: _sync.signIn, child: const Text('Sign in')),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Last synced'),
              subtitle: Text(_lastSyncedLabel(_sync.lastSync)),
              trailing: FilledButton.icon(
                onPressed: (!signedIn || busy) ? null : _syncNow,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(busy ? 'Syncing…' : 'Sync now'),
              ),
            ),
            // Status line slides in/out as sync progresses.
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: (_sync.message == null || busy)
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(children: [
                        Icon(
                          _sync.state == SyncState.error
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: _sync.state == SyncState.error ? scheme.error : scheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _sync.message!,
                            style: TextStyle(
                              color: _sync.state == SyncState.error ? scheme.error : scheme.secondary,
                            ),
                          ),
                        ),
                      ]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _appearanceSection(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.theme,
      builder: (context, _) => _Section(
        title: 'Appearance',
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('Light')),
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('System')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('Dark')),
                ],
                selected: {widget.theme.mode},
                onSelectionChanged: (s) => widget.theme.setMode(s.first),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backupSection(BuildContext context) {
    return _Section(
      title: 'Encrypted backup file',
      children: [
        ListTile(
          enabled: !_fileBusy,
          leading: const Icon(Icons.upload_file_rounded),
          title: const Text('Export backup'),
          subtitle: const Text('Save an encrypted .pfbak file'),
          onTap: _export,
        ),
        const Divider(height: 1),
        ListTile(
          enabled: !_fileBusy,
          leading: const Icon(Icons.download_rounded),
          title: const Text('Import backup'),
          subtitle: const Text('Merge a .pfbak file into this vault'),
          trailing: _fileBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _import,
        ),
      ],
    );
  }

  String _lastSyncedLabel(DateTime? t) {
    if (t == null) return 'Never';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

/// Titled rounded card that groups related settings.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Card(clipBehavior: Clip.antiAlias, child: Column(children: children)),
      ],
    );
  }
}
