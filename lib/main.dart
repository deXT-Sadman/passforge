import 'package:flutter/material.dart';

import 'core/security/crypto_service.dart';
import 'core/theme/app_theme.dart';
import 'features/vault/data/vault_repository.dart';
import 'features/vault/presentation/home_screen.dart';
import 'features/vault/presentation/vault_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PassForgeApp());
}

class PassForgeApp extends StatefulWidget {
  const PassForgeApp({super.key});

  @override
  State<PassForgeApp> createState() => _PassForgeAppState();
}

class _PassForgeAppState extends State<PassForgeApp> {
  // Composition root: wire dependencies once.
  late final VaultController _controller = VaultController(
    repository: FileVaultRepository(),
    crypto: CryptoService(),
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PassForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: HomeScreen(controller: _controller),
    );
  }
}
