import 'package:flutter/material.dart';

import 'core/security/crypto_service.dart';
import 'core/security/key_store.dart';
import 'core/theme/app_theme.dart';
import 'features/lock/lock_controller.dart';
import 'features/lock/lock_gate.dart';
import 'features/sync/drive_service.dart';
import 'features/sync/sync_controller.dart';
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
  final _keys = KeyStore();
  late final LockController _lock = LockController(_keys)..init();
  late final VaultController _vault = VaultController(
    repository: HiveVaultRepository(_keys),
    crypto: CryptoService(_keys),
  )..load();
  late final SyncController _sync = SyncController(
    drive: DriveService(),
    vault: _vault,
    keys: _keys,
  )..init();

  @override
  void dispose() {
    _lock.dispose();
    _sync.dispose();
    _vault.dispose();
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
      // The lock sits above the Navigator, so it also covers pushed screens.
      builder: (context, child) => LockGate(controller: _lock, child: child!),
      home: HomeScreen(controller: _vault, sync: _sync),
    );
  }
}
