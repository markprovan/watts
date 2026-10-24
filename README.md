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
