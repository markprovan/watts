# Developing Watts

Watts is a Flutter app for Android. Flutter plugins don't expose battery current, voltage or temperature, so `android/app/src/main/kotlin/com/markprovan/watts/MainActivity.kt` provides them over a method channel (`watts/battery`). Everything else is Dart in `lib/`.

| File | What it holds |
|---|---|
| `lib/battery_stats.dart` | Pure logic: unit handling, watts, capacity, time estimates, forecast, temperature status, formatting |
| `lib/battery_reader.dart` | Polls the method channel every 2 seconds, smooths the current, keeps 5 minutes of power history |
| `lib/theme.dart` | Colours for each state and brightness, and the text style helper |
| `lib/widgets.dart` | Cards, level bar, forecast, temperature bar, power chart |
| `lib/main.dart` | App, theme, and the screen layout |

## Build and test

```
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

The widget tests load the bundled font so layout checks use real text sizes.

## Workflows

| Workflow | When it runs | What it does |
|---|---|---|
| `ci.yml` | Every push and pull request | Format check, analysis, tests |
| `build-apk.yml` | Push to `main` that changes `lib/`, `android/`, `pubspec.yaml` or `pubspec.lock`, or run manually | Builds a debug APK and uploads it as the `watts-debug-apk` artifact |
| `release.yml` | Push of a `v*` tag, or run manually | Builds a signed release APK and attaches it to the GitHub release |

## Releases

Creating a release in GitHub (or pushing a tag like `v1.2.0`) runs `release.yml`. It runs the checks, builds a signed release APK and attaches `Watts-v1.2.0.apk` to the release. If only a tag was pushed, it creates the release with generated notes. Tags with a `-` such as `v1.2.0-beta` become pre-releases. The tag sets the app version, and the workflow run number is the build number.

One-time setup, because the APK must be signed with your own key:

1. Create a keystore and **back it up somewhere safe**. If you lose it, phones with the app installed cannot be updated.
   ```
   keytool -genkeypair -v -keystore watts-release.jks -alias watts -keyalg RSA -keysize 2048 -validity 10000
   base64 -w0 watts-release.jks   # on macOS: base64 -i watts-release.jks
   ```
2. In the repository settings under Secrets and variables, Actions, add these secrets:
   `ANDROID_KEYSTORE_BASE64` (the base64 output), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`watts` above) and `ANDROID_KEY_PASSWORD`.

A tag pushed without the secrets fails straight away with a message naming the missing one. To test the pipeline without secrets, run the Release workflow manually from the Actions tab: it builds with a throwaway key, uploads the APK as a workflow artifact and publishes nothing.

Debug builds from `main` and release builds are signed with different keys, so Android will not install one over the other. Uninstall the app first when switching.

## Icon

The launcher icon sources are in `assets/icon` (SVG, rendered to PNG). After editing them, run `dart run flutter_launcher_icons` to regenerate the Android icons, including the themed monochrome icon for Android 13 and later.

## Font

Roboto Flex (SIL Open Font License, see `assets/fonts/OFL.txt`) is bundled as a Latin-only subset with a variable weight axis from 200 to 700 (about 36 KB).

## Screenshots

The images in `docs/screenshots` are renders of the real Flutter UI in a browser with sample data, not captures from a phone.
