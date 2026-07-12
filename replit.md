# Conduit

A Flutter mobile app (Android & iOS) for SSH, Mosh, SFTP, and local terminal sessions — no account, no cloud sync. Hosts and keys stay on device.

Published on [App Store](https://apps.apple.com/app/id6780054869), [Google Play](https://play.google.com/store/apps/details?id=com.gwitko.conduit), and [F-Droid](https://f-droid.org/packages/com.gwitko.conduit/).

## Stack

- **Flutter 3.44.1** / **Dart ^3.12.0**
- `dartssh2` — SSH2 transport (custom fork)
- `conduit_vt` — VT terminal emulator (custom fork of xterm.dart)
- `dart_mosh` — Mosh protocol
- `flutter_pty` — local PTY for the built-in Arch Linux shell
- `flutter_secure_storage` — encrypted credential storage

## Project structure

```
lib/
  core/           Shared theme, palette, navigation, brand
  features/
    hosts/        Host/credential management, SSH key handling
    terminal/     SSH & Mosh sessions, keyboard bar, terminal UI
    local_shell/  Proot/PTY-based Arch Linux local shell
    sftp/         SFTP file browser
    snippets/     Reusable command snippets
    backup/       Import/export backup
    app_lock/     Biometric/PIN app lock
```

## Key files for the systemctl feature

| File | Role |
|---|---|
| `lib/core/theme/terminal_appearance.dart` | `TerminalKeyboardAction` enum + labels — add `systemctlMenu` here |
| `lib/features/terminal/presentation/terminal_keyboard_bar.dart` | Toolbar rendering — add `_SystemctlAction` enum + `_buildAction` case here |
| `lib/features/hosts/domain/saved_host.dart` | Per-host model (tmux settings live here — no changes needed for systemctl) |
| `lib/features/terminal/presentation/terminal_session_controller.dart` | Session logic, connect/disconnect (no changes needed for systemctl) |

## Replit environment notes

- Code is edited here on Replit; building and testing is done via Git CI (Flutter 3.44.1+ / Dart ^3.12.0 required).
- The app targets Android/iOS — it cannot be built or previewed directly on Replit.
- Flutter CLI isn't installed in this workspace; `flutter build`/`flutter test` can't run here. Icon/asset changes are made by editing `assets/icon/*.png` and manually regenerating platform outputs (Android `mipmap-*`/`drawable-*`, iOS `AppIcon.appiconset`) with ImageMagick, since `flutter pub run flutter_launcher_icons` isn't available.
- The `Release` GitHub Actions workflow (`.github/workflows/release.yml`) auto-bumps the patch version + build number and pushes a `[skip ci]` commit at the start of every run, so `pubspec.yaml`'s version is CI-managed — don't hand-edit it expecting it to stick.
- The Release workflow currently builds **unsigned** APKs (no `ANDROID_KEYSTORE_BASE64`/`ANDROID_KEY_ALIAS`/`ANDROID_KEY_PASSWORD`/`ANDROID_STORE_PASSWORD` repo secrets are set). Releases are tagged/published but aren't Play Store-ready until the real production keystore is added as GitHub Actions secrets.

## User preferences

- Scan first, report findings, then implement — user confirmed this workflow.
