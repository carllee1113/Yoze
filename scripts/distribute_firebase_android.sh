#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Distribute YOZE Android build to Firebase App Distribution.

Usage:
  scripts/distribute_firebase_android.sh \
    --project-id <firebase_project_id> \
    --app-id <firebase_app_id> \
    [--groups <group1,group2>] \
    [--testers <email1,email2>] \
    [--release-notes "<text>"] \
    [--apk-path <path_to_apk>] \
    [--skip-build]

Examples:
  scripts/distribute_firebase_android.sh \
    --project-id yozewong \
    --app-id 1:1234567890:android:abcdef123456 \
    --groups family

  scripts/distribute_firebase_android.sh \
    --project-id yozewong \
    --app-id 1:1234567890:android:abcdef123456 \
    --testers dad@example.com \
    --release-notes "Medication scheduling UX update"
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

APP_ID=""
PROJECT_ID=""
GROUPS=""
TESTERS=""
RELEASE_NOTES=""
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
SKIP_BUILD="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id)
      APP_ID="${2:-}"
      shift 2
      ;;
    --project-id)
      PROJECT_ID="${2:-}"
      shift 2
      ;;
    --groups)
      GROUPS="${2:-}"
      shift 2
      ;;
    --testers)
      TESTERS="${2:-}"
      shift 2
      ;;
    --release-notes)
      RELEASE_NOTES="${2:-}"
      shift 2
      ;;
    --apk-path)
      APK_PATH="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$APP_ID" ]]; then
  echo "--app-id is required." >&2
  usage
  exit 1
fi

if [[ -z "$PROJECT_ID" ]]; then
  echo "--project-id is required." >&2
  usage
  exit 1
fi

if [[ -z "$GROUPS" && -z "$TESTERS" ]]; then
  echo "Either --groups or --testers must be provided." >&2
  usage
  exit 1
fi

require_command flutter
require_command firebase

if [[ "$SKIP_BUILD" != "true" ]]; then
  echo "Building release APK..."
  flutter build apk --release
fi

if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found at: $APK_PATH" >&2
  exit 1
fi

if [[ -z "$RELEASE_NOTES" ]]; then
  if command -v git >/dev/null 2>&1; then
    RELEASE_NOTES="$(git log -1 --pretty=format:'%h %s' || true)"
  fi
  if [[ -z "$RELEASE_NOTES" ]]; then
    RELEASE_NOTES="YOZE Android release build"
  fi
fi

DIST_CMD=(
  firebase appdistribution:distribute
  "$APK_PATH"
  --project "$PROJECT_ID"
  --app "$APP_ID"
  --release-notes "$RELEASE_NOTES"
)

if [[ -n "$GROUPS" ]]; then
  DIST_CMD+=(--groups "$GROUPS")
fi

if [[ -n "$TESTERS" ]]; then
  DIST_CMD+=(--testers "$TESTERS")
fi

echo "Uploading to Firebase App Distribution..."
"${DIST_CMD[@]}"
echo "Distribution completed."
