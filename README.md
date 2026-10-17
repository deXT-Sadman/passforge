# PassForge

**Forge Your Own Security.** A local-first password manager built with Flutter and Material 3. Your passwords are encrypted on the device, protected by a PIN or biometrics, and can optionally be backed up to your own Google Drive. There is no backend server.

> **Status:** a personal project in development. It has **not** had an independent security audit. Don't rely on it as your only copy of important passwords.

## Features

- **Encrypted vault.** Each password is encrypted with AES-256-GCM, and the Hive database holding it is encrypted too. Both keys live in the platform keystore (Android Keystore / iOS Keychain).
- **App lock.** A 6-digit PIN (salted PBKDF2-SHA256) with optional fingerprint/face unlock. The app locks whenever it goes to the background. Repeated wrong PINs trigger an increasing lockout that survives restarts.
- **Secure copy.** Copying a password clears the clipboard after 30 seconds, but only if the clipboard still holds that password.
- **Google Drive backup.** Syncs an encrypted backup to Drive's hidden `appDataFolder`, so it never appears in your normal Drive files. Last-write-wins merge per item, with deletion markers so deleted items don't come back.
- **Encrypted backup file.** Export and import a passphrase-encrypted `.pfbak` file.
- **Modern UI.** Light, dark and system themes, search, category filters, list and grid views, staggered card animations, and empty states.
- **Password form.** Title, username, password with show/hide and a generator, category, and an optional local logo.

## How the encryption works

| Layer | What | Key |
|---|---|---|
| Field | Each password: AES-256-GCM, random IV per save | Random key in the device keystore |
| Database | Hive box: `HiveAesCipher` (AES-256) | A separate random key in the device keystore |
| PIN | PBKDF2-HMAC-SHA256, 100,000 iterations, random salt | Derived from the PIN, hash stored in the keystore |
| Backup (Drive and file) | AES-256-GCM over the whole vault | Derived from **your backup passphrase** (PBKDF2, 200,000 iterations) |

Keystore keys can't move between devices. So backups use a key derived from a passphrase you choose, which is what lets a new device restore them. **If you forget the backup passphrase, the backup cannot be recovered.**

## Project structure

Feature-first, with a domain / data / presentation split inside the vault feature.

```
lib/
├─ main.dart                  # composition root (wires dependencies)
├─ core/
│  ├─ security/               # keystore wrapper, AES service, PBKDF2, secure clipboard
│  ├─ theme/                  # Material 3 light/dark themes, theme controller
│  └─ widgets/                # shared animation widgets
└─ features/
   ├─ vault/                  # password model, Hive repository, home + form screens
   ├─ lock/                   # PIN + biometric lock, lifecycle lock gate
   ├─ sync/                   # Drive service, merge logic, backup crypto, file backup
   └─ settings/               # account, sync, theme, backup file
```

## Getting started

**Requirements:** Flutter 3.47+ (Dart 3.13+), and an Android device or emulator **with Google Play** (needed for Google sign-in).

```bash
git clone <your-repo-url>
cd passforge
flutter pub get
flutter run
```

Everything works out of the box except Google Drive sync, which needs your own Google Cloud credentials (below).

### Setting up Google Drive sync

Skip this if you don't need cloud backup. The app works fully offline without it.

1. In [Google Cloud Console](https://console.cloud.google.com), create a project and enable the **Google Drive API**.
2. Configure the **OAuth consent screen**. Under *Data Access*, add the scope `https://www.googleapis.com/auth/drive.appdata`. While the app is in *Testing*, add your Google account under *Audience → Test users*.
3. Create an **Android** OAuth client with package name `com.example.passforge` and your signing SHA-1. For a debug build, get it with:
   ```bash
   cd android
   ./gradlew signingReport
   ```
4. Create a **Web application** OAuth client. Copy its client ID into `kGoogleServerClientId` in [`lib/features/sync/drive_service.dart`](lib/features/sync/drive_service.dart). Android sign-in needs this value. It is an identifier, not a secret.
5. New clients can take from a few minutes to a few hours to start working.

Never commit a `client_secret*.json`, `google-services.json` or keystore. They are listed in `.gitignore`. This app doesn't use a client secret.

## Platform notes

- **Android** is the primary target. `minSdk` is 23, and `MainActivity` extends `FlutterFragmentActivity` as `local_auth` requires.
- **iOS** hasn't been tested. If you build for it, add `NSFaceIDUsageDescription` to `ios/Runner/Info.plist`.
- **Windows / desktop:** `google_sign_in` doesn't support Windows, so Drive sync is unavailable there. The rest of the app, including file export and import, should work.
- Before publishing, replace the debug signing config with a release keystore, and change the `com.example.passforge` application ID.

## Testing

```bash
flutter analyze
flutter test
```

The tests cover the item model, the sync merge rules, backup encryption (including wrong-passphrase rejection) and the empty-state UI. Drive, biometrics and file picking need a real device and aren't covered by automated tests.

## Known limitations

- Android screenshots and the app-switcher preview aren't blocked (`FLAG_SECURE` isn't set).
- A forgotten PIN can't be reset inside the app. Clearing the app's data is the only way back in, and that deletes the local vault.
- Sync is manual (the Sync now button) and last-write-wins, which relies on each device's clock. Two devices syncing at exactly the same moment can miss each other's changes until the next sync.
- Custom logos are stored on the device only and aren't synced.
- Decrypted passwords stay in memory while the app is unlocked.

## Main dependencies

`flutter_secure_storage`, `hive_ce`, `encrypt`, `pointycastle`, `local_auth`, `google_sign_in`, `googleapis`, `file_picker`, `image_picker`.
