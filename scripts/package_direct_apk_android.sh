#!/usr/bin/env bash

set -euo pipefail

OUTPUT_DIR="dist/android"
BUILD_NAME=""
BUILD_NUMBER=""

usage() {
  cat <<'EOF'
Build a signed universal APK for direct sharing.

Usage:
  scripts/package_direct_apk_android.sh [--build-name 1.0.0] [--build-number 2]

Output:
  dist/android/yoze-<version>-<build>.apk
  dist/android/yoze-<version>-<build>.apk.sha256
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-name)
      BUILD_NAME="${2:-}"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="${2:-}"
      shift 2
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

if ! command -v flutter >/dev/null 2>&1; then
  echo "Missing required command: flutter" >&2
  exit 1
fi

BUILD_ARGS=(apk --release)
if [[ -n "$BUILD_NAME" ]]; then
  BUILD_ARGS+=(--build-name "$BUILD_NAME")
fi
if [[ -n "$BUILD_NUMBER" ]]; then
  BUILD_ARGS+=(--build-number "$BUILD_NUMBER")
fi

flutter build "${BUILD_ARGS[@]}"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found at: $APK_PATH" >&2
  exit 1
fi

if [[ -z "$BUILD_NAME" || -z "$BUILD_NUMBER" ]]; then
  VERSION_LINE="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
  BUILD_NAME="${BUILD_NAME:-${VERSION_LINE%%+*}}"
  BUILD_NUMBER="${BUILD_NUMBER:-${VERSION_LINE##*+}}"
fi

mkdir -p "$OUTPUT_DIR"
TARGET_APK="$OUTPUT_DIR/yoze-${BUILD_NAME}-${BUILD_NUMBER}.apk"
cp "$APK_PATH" "$TARGET_APK"

if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$TARGET_APK" > "$TARGET_APK.sha256"
elif command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$TARGET_APK" > "$TARGET_APK.sha256"
else
  echo "No checksum command found; skipped sha256 file." >&2
fi

echo "Direct APK ready:"
echo "$TARGET_APK"
if [[ -f "$TARGET_APK.sha256" ]]; then
  echo "$TARGET_APK.sha256"
fi
