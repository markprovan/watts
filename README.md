# Watts

Android app (Flutter) showing live charging stats: charging power in watts, time to 80% and 100%, a charge forecast in 10% steps, battery temperature, current, voltage and recent power. The look follows the system light or dark setting.

Flutter plugins don't expose battery current, voltage or temperature, so `MainActivity.kt` provides them over a method channel (`watts/battery`). Time estimates assume the current charging rate stays constant, so the 100% figure is optimistic.

<p>
  <img src="docs/screenshots/charging-light.png" width="240" alt="Charging, light">
  <img src="docs/screenshots/charging-dark.png" width="240" alt="Charging, dark">
  <img src="docs/screenshots/on-battery.png" width="240" alt="On battery">
</p>

Screenshots are renders of the Flutter UI (in a browser) with sample data, not captured from a phone.

Roboto Flex (SIL Open Font License, see `assets/fonts/OFL.txt`) is bundled as a Latin-only subset with a variable weight axis (about 36 KB).

## Development

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## CI and installing the APK

`.github/workflows/ci.yml` runs format check, analysis and tests on every push and pull request. `.github/workflows/build-apk.yml` builds the debug APK only when app files (`lib/`, `android/`, `pubspec.yaml`, `pubspec.lock`) change on `main`, or when you start it manually from the Actions tab. To install: open the workflow run on GitHub's Actions tab, download the `watts-debug-apk` artifact, unzip it, and open `app-debug.apk` on your phone (allow installs from unknown sources). The debug APK is signed with a debug key, which is fine for sideloading.

## Releases

Creating a release in GitHub (or pushing a tag like `v1.2.0`) runs `.github/workflows/release.yml`. It runs the checks, builds a **signed release APK** and attaches `Watts-v1.2.0.apk` to the release (creating the release with generated notes if only a tag was pushed; tags with a `-` such as `v1.2.0-beta` become pre-releases). The tag sets the app version, and the build number is the workflow run number.

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
