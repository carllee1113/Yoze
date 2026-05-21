# YOZE

YOZE is a Flutter medication reminder app that supports:

- Batch medication setup in one session
- Mixed sources: manual entry + photo/OCR extraction
- Unified schedule setup with one day-start time
- Automatic shared-slot distribution across medications
- Daily reminder notifications
- Dose status tracking and history

## Requirements

- Flutter 3.35+ (Dart 3.11+)
- iOS/Android build toolchains

## Run

```bash
flutter pub get
flutter run
```

## Quality Checks

```bash
flutter analyze
flutter test
```

## Project Structure

- `lib/screens`: UI screens (home, capture, processing, verification, history)
- `lib/services`: OCR, fuzzy matching, notification scheduling
- `lib/database`: SQLite helper and queries
- `lib/models`: medication and dose data models
- `test`: unit tests for extraction and core model behavior

## Notes

- Batch schedule planning logic is in `lib/services/schedule_planner.dart`.
- Notification actions (`已吃` / `稍後提醒`) are handled in `NotificationService`.
- Timezone-aware scheduling is configured at app startup.

## Building for Release

### Prerequisites

A release keystore and signing config must be set up (one-time setup):

1. Generate a keystore in `android/`:
   ```bash
   keytool -genkey -v -keystore android/upload-keystore.jks \
     -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload -dname "CN=Yoze"
   ```

2. Create `android/key.properties`:
   ```properties
   storePassword=<your-password>
   keyPassword=<your-password>
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```

Both files are gitignored — back them up outside the repo. If lost, users will need to uninstall before reinstalling future updates.

### Build

```bash
# Single APK for one architecture (recommended for direct sharing)
flutter build apk --release --split-per-abi

# Universal APK (all architectures, larger)
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/`

### Data persistence across updates

Android identifies the app by its signing certificate. As long as every release is signed with the same keystore, installing a new APK over an old one preserves all local data (medication records, settings, history).

## Firebase App Distribution

Use Firebase App Distribution to avoid "suspicious APK" warnings from side-loading.

### One-time setup

1. Create Android app in Firebase project (package name: `com.yoze.yoze`).
2. Copy the Firebase App ID (format like `1:1234567890:android:abcdef123456`).
3. Install and login Firebase CLI:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
4. Add testers in Firebase Console (App Distribution) or prepare tester emails/groups.

### Distribute build

Run from repo root:

```bash
chmod +x scripts/distribute_firebase_android.sh
scripts/distribute_firebase_android.sh \
  --project-id yozewong \
  --app-id <your_firebase_android_app_id> \
  --groups family \
  --release-notes "YOZE update"
```

You can also distribute to individual testers:

```bash
scripts/distribute_firebase_android.sh \
  --project-id yozewong \
  --app-id <your_firebase_android_app_id> \
  --testers dad@example.com
```

Options:
- `--skip-build`: upload existing APK without rebuilding.
- `--apk-path`: custom APK path (default: `build/app/outputs/flutter-apk/app-release.apk`).

## Direct APK Fallback

If Firebase App Distribution download fails with a protected-link `403`, build a signed universal APK and share it directly.

```bash
scripts/package_direct_apk_android.sh --build-name 1.0.0 --build-number 2
```

The script creates:

```text
dist/android/yoze-1.0.0-2.apk
dist/android/yoze-1.0.0-2.apk.sha256
```

Share the APK through a trusted channel such as Google Drive, iCloud Drive, OneDrive, or direct cable transfer. The tester should download the APK with Chrome or Files, allow installation from that source, and install it.

Notes:
- Keep using the same Android keystore for future APKs, or Android will require uninstalling the previous app before installing updates.
- Direct APK install may still show Android/Play Protect warnings because it is side-loaded outside Google Play.
- Do not share `android/key.properties` or `android/upload-keystore.jks`.
