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
