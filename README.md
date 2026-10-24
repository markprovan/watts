# Watts

Android app (Flutter) showing live charging stats: charging power in watts, time to 80%, time to 100%, battery temperature, current and voltage.

Flutter plugins don't expose battery current, voltage or temperature, so `MainActivity.kt` provides them over a method channel (`watts/battery`). Time estimates assume the current charging rate stays constant, so the 100% figure is optimistic.

## Development

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## CI and installing the APK

`.github/workflows/ci.yml` runs format check, analysis and tests, then builds a debug APK. To install: open the workflow run on GitHub's Actions tab, download the `watts-debug-apk` artifact, unzip it, and open `app-debug.apk` on your phone (allow installs from unknown sources). The debug APK is signed with a debug key, which is fine for sideloading.
