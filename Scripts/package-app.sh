#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
APP_DIR="$DIST_DIR/TuckNotes.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$DIST_DIR/TuckNotes-macOS.zip"
APP_ICON_SOURCE="$REPO_ROOT/Assets/AppIcon.png"
APP_ICON_NAME="TuckNotes.icns"

cd "$REPO_ROOT"
swift build -c release --disable-sandbox
BIN_DIR="$(swift build -c release --disable-sandbox --show-bin-path)"

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
install -m 755 "$BIN_DIR/TuckNote" "$MACOS_DIR/TuckNote"
install -m 644 "$REPO_ROOT/THIRD_PARTY_NOTICES.md" \
    "$RESOURCES_DIR/THIRD_PARTY_NOTICES.md"
install -m 644 "$REPO_ROOT/LICENSE" "$RESOURCES_DIR/LICENSE"

create_app_icon() {
    local iconset="$DIST_DIR/TuckNotes.iconset"

    test -f "$APP_ICON_SOURCE"
    rm -rf "$iconset"
    mkdir -p "$iconset"

    sips -s format png -z 16 16 "$APP_ICON_SOURCE" --out "$iconset/icon_16x16.png" >/dev/null
    sips -s format png -z 32 32 "$APP_ICON_SOURCE" --out "$iconset/icon_16x16@2x.png" >/dev/null
    sips -s format png -z 32 32 "$APP_ICON_SOURCE" --out "$iconset/icon_32x32.png" >/dev/null
    sips -s format png -z 64 64 "$APP_ICON_SOURCE" --out "$iconset/icon_32x32@2x.png" >/dev/null
    sips -s format png -z 128 128 "$APP_ICON_SOURCE" --out "$iconset/icon_128x128.png" >/dev/null
    sips -s format png -z 256 256 "$APP_ICON_SOURCE" --out "$iconset/icon_128x128@2x.png" >/dev/null
    sips -s format png -z 256 256 "$APP_ICON_SOURCE" --out "$iconset/icon_256x256.png" >/dev/null
    sips -s format png -z 512 512 "$APP_ICON_SOURCE" --out "$iconset/icon_256x256@2x.png" >/dev/null
    sips -s format png -z 512 512 "$APP_ICON_SOURCE" --out "$iconset/icon_512x512.png" >/dev/null
    sips -s format png -z 1024 1024 "$APP_ICON_SOURCE" --out "$iconset/icon_512x512@2x.png" >/dev/null

    iconutil -c icns "$iconset" -o "$RESOURCES_DIR/$APP_ICON_NAME"
    rm -rf "$iconset"
}

create_app_icon

copy_bundle() {
    local bundle="$1"
    local source="$BIN_DIR/$bundle"
    local destination="$APP_DIR/$bundle"

    test -d "$source"
    while IFS= read -r directory; do
        local relative_path="${directory#"$source"}"
        mkdir -p "$destination$relative_path"
    done < <(find "$source" -type d -print | sort)
    while IFS= read -r resource; do
        local relative_path="${resource#"$source"/}"
        install -m 644 "$resource" "$destination/$relative_path"
    done < <(find "$source" -type f -print | sort)
}

copy_bundle "KeyboardShortcuts_KeyboardShortcuts.bundle"
copy_bundle "Highlighter_Highlighter.bundle"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>TuckNote</string>
    <key>CFBundleIconFile</key>
    <string>TuckNotes</string>
    <key>CFBundleIdentifier</key>
    <string>com.lyunify.TuckNote</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>TuckNotes</string>
    <key>CFBundleDisplayName</key>
    <string>TuckNotes</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.2</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Created $APP_DIR"
echo "Created $ZIP_PATH"
