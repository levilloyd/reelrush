#!/bin/bash
# Builds ReelRush.app into ./build using the Swift compiler (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")"

APP=build/ReelRush.app
BIN=build/ReelRush
mkdir -p build

echo "▸ Compiling…"
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13.0" \
    -framework AppKit -framework SpriteKit \
    Sources/ReelRush/*.swift -o "$BIN"

echo "▸ Bundling app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ReelRush"

# App icon (rendered by the game itself)
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
"$BIN" --export-icon build/icon_1024.png
sips -z 1024 1024 build/icon_1024.png --out build/icon_1024.png >/dev/null
for s in 16 32 128 256 512; do
    sips -z $s $s build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Reel Rush</string>
    <key>CFBundleDisplayName</key><string>Reel Rush</string>
    <key>CFBundleExecutable</key><string>ReelRush</string>
    <key>CFBundleIdentifier</key><string>com.reelrush.game</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.arcade-games</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true
echo "✓ Built $APP  —  run with: open $APP"
