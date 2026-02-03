#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="PatchPilot"
APP_BUNDLE="$DIST_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
BUILD_DIR="$ROOT_DIR/.build"
SWIFTPM_CACHE="$ROOT_DIR/.swiftpm-cache"
SWIFTPM_CONFIG="$ROOT_DIR/.swiftpm-config"
SWIFTPM_SECURITY="$ROOT_DIR/.swiftpm-security"
MODULE_CACHE="$ROOT_DIR/.swift-module-cache"

BUNDLE_ID="${BUNDLE_ID:-com.yourcompany.patchpilot}"
APP_VERSION="${APP_VERSION:-1.0}"
APP_BUILD="${APP_BUILD:-1}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"
SPARKLE_FRAMEWORK_PATH="${SPARKLE_FRAMEWORK_PATH:-}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

mkdir -p "$DIST_DIR" "$SWIFTPM_CACHE" "$SWIFTPM_CONFIG" "$SWIFTPM_SECURITY" "$MODULE_CACHE"

swift build \
  -c release \
  --scratch-path "$BUILD_DIR" \
  --cache-path "$SWIFTPM_CACHE" \
  --config-path "$SWIFTPM_CONFIG" \
  --security-path "$SWIFTPM_SECURITY" \
  --manifest-cache local \
  -Xswiftc -module-cache-path -Xswiftc "$MODULE_CACHE" \
  -Xlinker -rpath -Xlinker "@executable_path/../Frameworks"

BIN_PATH="$BUILD_DIR/release/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "Build output not found at $BIN_PATH"
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>PatchPilot</string>
  <key>CFBundleDisplayName</key>
  <string>PatchPilot</string>
  <key>CFBundleIdentifier</key>
  <string>BUNDLE_ID_REPLACE</string>
  <key>CFBundleVersion</key>
  <string>APP_BUILD_REPLACE</string>
  <key>CFBundleShortVersionString</key>
  <string>APP_VERSION_REPLACE</string>
  <key>CFBundleExecutable</key>
  <string>PatchPilot</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>SUFeedURL</key>
  <string>SPARKLE_FEED_URL_REPLACE</string>
  <key>SUPublicEDKey</key>
  <string>SPARKLE_PUBLIC_KEY_REPLACE</string>
  <key>SUEnableAutomaticChecks</key>
  <false/>
  <key>SUAllowsAutomaticUpdates</key>
  <false/>
  <key>SUAutomaticallyUpdate</key>
  <false/>
</dict>
</plist>
PLIST

perl -0pi -e "s|BUNDLE_ID_REPLACE|$BUNDLE_ID|g; s|APP_BUILD_REPLACE|$APP_BUILD|g; s|APP_VERSION_REPLACE|$APP_VERSION|g; s|SPARKLE_FEED_URL_REPLACE|$SPARKLE_FEED_URL|g; s|SPARKLE_PUBLIC_KEY_REPLACE|$SPARKLE_PUBLIC_KEY|g" "$CONTENTS_DIR/Info.plist"

if [[ -f "$ROOT_DIR/Sources/PatchPilot/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Sources/PatchPilot/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

RESOURCE_BUNDLE_PATH="$(find "$BUILD_DIR" -name "PatchPilot_PatchPilot.bundle" -print -quit 2>/dev/null || true)"
if [[ -n "$RESOURCE_BUNDLE_PATH" && -d "$RESOURCE_BUNDLE_PATH" ]]; then
  rsync -a "$RESOURCE_BUNDLE_PATH" "$RESOURCES_DIR/"
fi

if [[ -z "$SPARKLE_FRAMEWORK_PATH" ]]; then
  SPARKLE_FRAMEWORK_PATH="$(find "$ROOT_DIR/.build" -name "Sparkle.framework" -print -quit 2>/dev/null || true)"
fi

if [[ -n "$SPARKLE_FRAMEWORK_PATH" && -d "$SPARKLE_FRAMEWORK_PATH" ]]; then
  rsync -a "$SPARKLE_FRAMEWORK_PATH" "$FRAMEWORKS_DIR/"
else
  echo "Warning: Sparkle.framework not found. The app will fail to launch without it."
fi

if [[ -n "$CODESIGN_IDENTITY" ]]; then
  codesign --force --deep --options runtime --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
fi

DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_BUNDLE" \
  -ov -format UDZO \
  "$DMG_PATH"

echo "DMG created at: $DMG_PATH"
