#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_APK_DIR="$PROJECT_ROOT/build/app/outputs/flutter-apk"
SITE_APK_DIR="$PROJECT_ROOT/apk_download_site/apks"

APK_FILES=(
  "app-arm64-v8a-release.apk"
  "app-armeabi-v7a-release.apk"
  "app-x86_64-release.apk"
)

mkdir -p "$SITE_APK_DIR"

missing=0
for apk in "${APK_FILES[@]}"; do
  if [[ ! -f "$BUILD_APK_DIR/$apk" ]]; then
    echo "Missing APK: $BUILD_APK_DIR/$apk"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo
  echo "Build APKs first: flutter build apk --split-per-abi"
  exit 1
fi

for apk in "${APK_FILES[@]}"; do
  cp -f "$BUILD_APK_DIR/$apk" "$SITE_APK_DIR/$apk"
done

echo "APK files copied to: $SITE_APK_DIR"
ls -lh "$SITE_APK_DIR"
