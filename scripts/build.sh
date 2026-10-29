#!/bin/zsh
# Builds "Halo Search.app" into ./build.
#
#   scripts/build.sh                 build the app
#   scripts/build.sh --install       also copy it to /Applications and launch it
#   scripts/build.sh --zip           also package build/HaloSearch-<version>.zip for a release
#
#   CODESIGN_IDENTITY="Developer ID Application: …"   sign with a real identity instead of ad hoc
#   VERSION=1.2.0                                     override the version from the VERSION file
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Halo Search"
EXECUTABLE="HaloSearch"
BUNDLE_ID="io.github.buwaneka-halpage.HaloSearch"
VERSION="${VERSION:-$(cat VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP="build/$APP_NAME.app"

swift build -c release --product "$EXECUTABLE"
BIN="$(swift build -c release --show-bin-path)/$EXECUTABLE"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXECUTABLE"

if [[ ! -f build/AppIcon.icns ]]; then
    ICONSET="build/AppIcon.iconset"
    mkdir -p "$ICONSET"
    swift scripts/make-icon.swift build/icon-1024.png
    for size in 16 32 128 256 512; do
        sips -z $size $size build/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) build/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o build/AppIcon.icns
    rm -rf "$ICONSET" build/icon-1024.png
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 Buwaneka Halpage. MIT License.</string>
</dict>
</plist>
PLIST

codesign --force --sign "${CODESIGN_IDENTITY:--}" "$APP"
echo "Built $APP ($VERSION, build $BUILD_NUMBER)"

for arg in "$@"; do
    case "$arg" in
    --zip)
        ZIP="build/$EXECUTABLE-$VERSION.zip"
        rm -f "$ZIP"
        ditto -c -k --keepParent "$APP" "$ZIP"
        echo "Packaged $ZIP"
        ;;
    --install)
        pkill -x "$EXECUTABLE" 2>/dev/null || true
        rm -rf "/Applications/$APP_NAME.app"
        cp -R "$APP" /Applications/
        open "/Applications/$APP_NAME.app"
        echo "Installed to /Applications and launched"
        ;;
    esac
done
