import 'dart:async';
import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Web-type OAuth client ID from Google Cloud Console (see setup steps).
/// Not a secret.
const String kGoogleServerClientId =
    '1029780966704-mtmnkov3i2sg7fqbdug7k25381lfto6m.apps.googleusercontent.com';

/// Talks to Google Drive's hidden per-app storage (`appDataFolder`).
///
/// Files there are invisible in the user's normal Drive UI, are only readable
/// by this app, and are deleted if the user uninstalls/disconnects the app
/// from their Google account.
class DriveService {
  static const fileName = 'passforge_vault.enc';
  static const _scopes = [drive.DriveApi.driveAppdataScope];

  bool _initialized = false;
  GoogleSignInAccount? _account;

  GoogleSignInAccount? get account => _account;
  String? get email => _account?.email;
  bool get isSignedIn => _account != null;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
    _initialized = true;
  }

  /// Silent sign-in at startup (no UI). Returns true if a session was restored.
  Future<bool> restoreSession() async {
    await _ensureInitialized();
    try {
      _account = await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (_) {
      _account = null;
    }
    return _account != null;
  }

  /// Interactive sign-in + Drive appdata consent.
  Future<void> signIn() async {
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    // Explicitly request the Drive scope (separate from identity sign-in).
    await account.authorizationClient.authorizeScopes(_scopes);
    _account = account;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    _account = null;
  }

  /// Builds an authenticated Drive client. Tokens are short-lived, so a fresh
  /// client is created for each operation.
  Future<(drive.DriveApi, http.Client)> _api() async {
    final account = _account;
    if (account == null) throw StateError('Not signed in to Google.');
    final authz = await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);
    final client = authz.authClient(scopes: _scopes);
    return (drive.DriveApi(client), client);
  }

  /// Finds the vault file in appDataFolder; null when nothing was uploaded yet.
  Future<drive.File?> _find(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$fileName' and trashed = false",
      $fields: 'files(id,name,modifiedTime)',
      pageSize: 1,
    );
    final files = list.files;
    return (files == null || files.isEmpty) ? null : files.first;
  }

  /// Downloads the encrypted vault text, or null if none exists in the cloud.
  Future<String?> download() async {
    final (api, client) = await _api();
    try {
      final file = await _find(api);
      if (file == null) return null;
      final media = await api.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = await media.stream.expand((chunk) => chunk).toList();
      return utf8.decode(bytes);
    } finally {
      client.close();
    }
  }

  /// Creates the file on first upload, otherwise overwrites it in place.
  Future<void> upload(String content) async {
    final (api, client) = await _api();
    try {
      final bytes = utf8.encode(content);
      final media = drive.Media(Stream.value(bytes), bytes.length,
          contentType: 'application/json');
      final existing = await _find(api);
      if (existing == null) {
        await api.files.create(
          drive.File()
            ..name = fileName
            ..parents = ['appDataFolder'], // this is what hides it
          uploadMedia: media,
        );
      } else {
        // `parents` must NOT be sent on update.
        await api.files.update(drive.File(), existing.id!, uploadMedia: media);
      }
    } finally {
      client.close();
    }
  }
}
