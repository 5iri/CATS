#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/CATS.xcodeproj}"
SCHEME="${SCHEME:-CATS}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="${APP_NAME:-CATS}"
ORIGINAL_HOME="$HOME"

BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build/macos-package}"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
SOURCE_PACKAGES_PATH="$BUILD_ROOT/SourcePackages"
LOCAL_CACHE_PATH="$BUILD_ROOT/LocalCache"
MODULE_CACHE_PATH="$BUILD_ROOT/ModuleCache"
TEMP_HOME_PATH="$BUILD_ROOT/Home"
DIST_PATH="${DIST_PATH:-$ROOT_DIR/dist}"
DMG_STAGING_PATH="$BUILD_ROOT/DMGRoot"

echo "==> Preparing build folders"
rm -rf "$BUILD_ROOT"
mkdir -p \
  "$DERIVED_DATA_PATH" \
  "$SOURCE_PACKAGES_PATH" \
  "$LOCAL_CACHE_PATH" \
  "$MODULE_CACHE_PATH" \
  "$TEMP_HOME_PATH" \
  "$DIST_PATH"

seed_source_packages() {
  local seed_path="${SOURCE_PACKAGES_SEED_PATH:-}"
  local candidates=()

  if [[ -n "$seed_path" ]]; then
    candidates+=("$seed_path")
  else
    shopt -s nullglob
    candidates+=("$ORIGINAL_HOME"/Library/Developer/Xcode/DerivedData/"$SCHEME"-*/SourcePackages)
    shopt -u nullglob
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate/checkouts" && -d "$candidate/repositories" ]]; then
      echo "==> Seeding SwiftPM cache from $candidate"
      cp -R "$candidate/checkouts" "$SOURCE_PACKAGES_PATH/"
      cp -R "$candidate/repositories" "$SOURCE_PACKAGES_PATH/"
      return 0
    fi
  done

  echo "==> No local SwiftPM cache seed found. Build may require network."
}

seed_source_packages

echo "==> Building $APP_NAME ($CONFIGURATION)"
HOME="$TEMP_HOME_PATH" \
XDG_CACHE_HOME="$LOCAL_CACHE_PATH" \
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_PATH" \
MODULE_CACHE_DIR="$MODULE_CACHE_PATH" \
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_PATH" \
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app was not found at:"
  echo "  $APP_PATH"
  exit 1
fi

VERSION="$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "0.0.0")"
BUILD_NUMBER="$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "0")"
DMG_NAME="$APP_NAME-$VERSION-$BUILD_NUMBER.dmg"
DMG_PATH="$DIST_PATH/$DMG_NAME"
ZIP_PATH="$DIST_PATH/$APP_NAME-$VERSION-$BUILD_NUMBER.zip"

echo "==> Creating zip archive"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Creating dmg"
rm -rf "$DMG_STAGING_PATH"
mkdir -p "$DMG_STAGING_PATH"
cp -R "$APP_PATH" "$DMG_STAGING_PATH/"
ln -s /Applications "$DMG_STAGING_PATH/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo
echo "Packaging complete:"
echo "  App: $APP_PATH"
echo "  Zip: $ZIP_PATH"
echo "  DMG: $DMG_PATH"
