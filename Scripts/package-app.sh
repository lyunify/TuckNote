#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
APP_DIR="$DIST_DIR/TuckNote.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$DIST_DIR/TuckNote-macOS.zip"

cd "$REPO_ROOT"
swift build -c release --disable-sandbox
BIN_DIR="$(swift build -c release --disable-sandbox --show-bin-path)"

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
install -m 755 "$BIN_DIR/TuckNote" "$MACOS_DIR/TuckNote"
install -m 644 "$REPO_ROOT/THIRD_PARTY_NOTICES.md" \
    "$RESOURCES_DIR/THIRD_PARTY_NOTICES.md"
install -m 644 "$REPO_ROOT/LICENSE" "$RESOURCES_DIR/LICENSE"

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
    <key>CFBundleIdentifier</key>
    <string>com.lyunify.TuckNote</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>TuckNote</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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
