#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-CineChill.xcodeproj}"
SCHEME="${SCHEME:-CineChill}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_ROOT="${BUILD_ROOT:-build}"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
OUTPUT_DIR="$BUILD_ROOT/unsigned-ipa"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos/$SCHEME.app"
IPA_PATH="$OUTPUT_DIR/$SCHEME-unsigned.ipa"

rm -rf "$DERIVED_DATA" "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  clean build

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR/Payload"
cp -R "$APP_PATH" "$OUTPUT_DIR/Payload/"

(
  cd "$OUTPUT_DIR"
  /usr/bin/zip -qry "$SCHEME-unsigned.ipa" Payload
)

rm -rf "$OUTPUT_DIR/Payload"
echo "Unsigned IPA created: $IPA_PATH"
