import 'package:flutter/material.dart';

import 'sync_controller.dart';

/// Asks for a backup passphrase. With [confirm] the user must type it twice
/// (use when *creating* a passphrase, since a typo makes the backup unreadable).
/// Returns null if cancelled.
Future<String?> askPassphrase(
  BuildContext context, {
  required String title,
  String? message,
  bool confirm = false,
  String actionLabel = 'Continue',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PassphraseDialog(
      title: title,
      message: message,
      confirm: confirm,
      actionLabel: actionLabel,
    ),
  );
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({
    required this.title,
    required this.message,
    required this.confirm,
    required this.actionLabel,
  });

  final String title;
  final String? message;
  final bool confirm;
  final String actionLabel;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) Navigator.pop(context, _pass.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message != null) ...[
                Text(widget.message!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _pass,
                autofocus: true,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Backup passphrase',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v ?? '').length < SyncController.minPassphraseLength
                    ? 'At least ${SyncController.minPassphraseLength} characters'
                    : null,
                onFieldSubmitted: (_) => widget.confirm ? null : _submit(),
              ),
              if (widget.confirm) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'Confirm passphrase'),
                  validator: (v) => v != _pass.text ? "Passphrases don't match" : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}
