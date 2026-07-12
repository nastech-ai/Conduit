---
name: Conduit has no Flutter CLI in the Replit workspace
description: How to update app icons/launcher assets when flutter_launcher_icons can't be run here
---

The Replit workspace for Conduit only has the Dart SDK (`dart-3.10` module) — no `flutter` binary. `flutter pub run flutter_launcher_icons` (the tool `pubspec.yaml` is configured to use for icon generation) cannot run here.

**Why:** the project's `.replit` modules are `bash`, `swift-5.8`, `dart-3.10` — no Flutter module was set up, and building/testing is expected to happen via Git CI, not locally in this workspace.

**How to apply:** when changing the app icon, update the source files (`assets/icon/icon.png`, `assets/icon/icon_foreground.png`) and then manually regenerate every platform output with ImageMagick (`magick`), matching flutter_launcher_icons' conventions:
- Android: `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` (legacy, square, sizes 48/72/96/144/192) from `icon.png`; `drawable-*/ic_launcher_foreground.png` and `drawable-*/ic_launcher_monochrome.png` (sizes 108/162/216/324/432, transparent bg) from `icon_foreground.png`.
- iOS: every entry in `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` (sizes 20–1024, opaque/no alpha — iOS icons can't have transparency) from `icon.png`.
