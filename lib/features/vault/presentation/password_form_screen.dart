import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/password_item.dart';
import 'vault_controller.dart';
import 'widgets/platform_avatar.dart';

/// Add / Edit form. Pass [existing] to edit.
class PasswordFormScreen extends StatefulWidget {
  const PasswordFormScreen({super.key, required this.controller, this.existing});

  final VaultController controller;
  final PasswordItem? existing;

  @override
  State<PasswordFormScreen> createState() => _PasswordFormScreenState();
}

class _PasswordFormScreenState extends State<PasswordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _username = TextEditingController(text: widget.existing?.username);
  final _password = TextEditingController();

  late PasswordCategory _category =
      widget.existing?.category ?? PasswordCategory.other;
  String? _iconPath;
  bool _obscure = true;
  bool _saving = false;
  bool _loadingPassword = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _iconPath = widget.existing?.iconPath;
    if (_isEditing) _decryptExisting();
  }

  /// Pre-fills the password field when editing.
  Future<void> _decryptExisting() async {
    setState(() => _loadingPassword = true);
    try {
      _password.text = await widget.controller.revealPassword(widget.existing!);
    } catch (_) {
      // Leave empty; the user can enter a new password.
    }
    if (mounted) setState(() => _loadingPassword = false);
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Picks an image and copies it into app storage so it survives the
  /// gallery/cache file being removed.
  Future<void> _pickIcon() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
    );
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final iconsDir = await Directory('${dir.path}/icons').create(recursive: true);
    final ext = picked.path.contains('.') ? picked.path.split('.').last : 'png';
    final saved = await File(picked.path)
        .copy('${iconsDir.path}/${DateTime.now().microsecondsSinceEpoch}.$ext');
    if (mounted) setState(() => _iconPath = saved.path);
  }

  /// Generates a strong random password (letters, digits, symbols).
  void _generate() {
    const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
        '23456789!@#\$%^&*-_=+?';
    final rnd = Random.secure();
    setState(() {
      _password.text =
          List.generate(20, (_) => chars[rnd.nextInt(chars.length)]).join();
      _obscure = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.controller.save(
      existing: widget.existing,
      title: _title.text.trim(),
      username: _username.text.trim(),
      plainPassword: _password.text,
      category: _category,
      iconPath: _iconPath,
    );
    if (mounted) Navigator.of(context).pop();
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit password' : 'New password')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _IconPicker(
              title: _title,
              iconPath: _iconPath,
              onPick: _pickIcon,
              onClear: () => setState(() => _iconPath = null),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _title,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. GitHub',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
              validator: (v) => _required(v, 'Title'),
              // Rebuild so the avatar initial follows the title.
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _username,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Username or email',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) => _required(v, 'Username'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !_loadingPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Generate strong password',
                    icon: const Icon(Icons.auto_awesome_rounded),
                    onPressed: _generate,
                  ),
                  IconButton(
                    tooltip: _obscure ? 'Show' : 'Hide',
                    icon: Icon(_obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ]),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PasswordCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final c in PasswordCategory.values)
                  DropdownMenuItem(
                    value: c,
                    child: Row(children: [
                      Icon(c.icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(c.label),
                    ]),
                  ),
              ],
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.lock_rounded),
              label: Text(_isEditing ? 'Save changes' : 'Encrypt & save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable avatar preview with an "add logo" badge.
class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.title,
    required this.iconPath,
    required this.onPick,
    required this.onClear,
  });

  final TextEditingController title;
  final String? iconPath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      GestureDetector(
        onTap: onPick,
        child: Stack(clipBehavior: Clip.none, children: [
          PlatformAvatar(title: title.text, iconPath: iconPath, size: 88),
          Positioned(
            right: -6,
            bottom: -6,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_a_photo_rounded,
                  size: 16, color: Colors.black),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      if (iconPath != null)
        TextButton(onPressed: onClear, child: const Text('Remove logo'))
      else
        Text('Optional logo', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}
