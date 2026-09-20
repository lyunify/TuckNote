#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$REPO_ROOT/dist/TuckNotes.app"
ZIP="$REPO_ROOT/dist/TuckNotes-macOS.zip"
CHECKSUMS="$REPO_ROOT/dist/SHA256SUMS.txt"
KEYBOARD_RESOURCES="KeyboardShortcuts_KeyboardShortcuts.bundle"
HIGHLIGHTER_RESOURCES="Highlighter_Highlighter.bundle"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

rm -rf "$REPO_ROOT/dist"
(cd /tmp && "$SCRIPT_DIR/package-app.sh")

test -d "$APP/Contents/MacOS"
test -x "$APP/Contents/MacOS/TuckNote"
test -f "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
test -f "$APP/Contents/Resources/LICENSE"
test -f "$APP/Contents/Resources/TuckNotes.icns"
test -f "$APP/$KEYBOARD_RESOURCES/Info.plist"
test -f "$APP/$KEYBOARD_RESOURCES/en.lproj/Localizable.strings"
test -f "$APP/$HIGHLIGHTER_RESOURCES/atom-one-light.css"
test -f "$APP/$HIGHLIGHTER_RESOURCES/atom-one-dark.css"
test -f "$APP/Contents/Info.plist"
test -f "$ZIP"
test -f "$CHECKSUMS"
(cd "$REPO_ROOT/dist" && shasum -a 256 -c SHA256SUMS.txt)

verify_architectures() {
    local binary="$1"
    # The local bundle is not distribution-signed; verify its executable separately.
    cp "$binary" "$TMP_DIR/TuckNote"
    codesign --verify --strict "$TMP_DIR/TuckNote"
    local architectures=" $(lipo -archs "$binary") "
    for architecture in arm64 x86_64; do
        case "$architectures" in
            *" $architecture "*) ;;
            *) echo "Missing $architecture in $binary" >&2; exit 1 ;;
        esac
        local minimum
        minimum="$(xcrun vtool -arch "$architecture" -show-build "$binary" | awk '$1 == "minos" { print $2 }')"
        test "$minimum" = "14.0"
    done
}

verify_architectures "$APP/Contents/MacOS/TuckNote"

test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = \
    "com.lyunify.TuckNote"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")" = \
    "TuckNote"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist")" = \
    "TuckNotes"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$APP/Contents/Info.plist")" = \
    "TuckNotes"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP/Contents/Info.plist")" = \
    "TuckNotes"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP/Contents/Info.plist")" = \
    "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")" = "14.0"
plutil -lint "$APP/Contents/Info.plist"

CONTENTS="$TMP_DIR/extracted"
mkdir -p "$CONTENTS"
ditto -x -k "$ZIP" "$CONTENTS"
test -x "$CONTENTS/TuckNotes.app/Contents/MacOS/TuckNote"
test -f "$CONTENTS/TuckNotes.app/Contents/Resources/THIRD_PARTY_NOTICES.md"
test -f "$CONTENTS/TuckNotes.app/Contents/Resources/LICENSE"
test -f "$CONTENTS/TuckNotes.app/Contents/Resources/TuckNotes.icns"
test -f "$CONTENTS/TuckNotes.app/$KEYBOARD_RESOURCES/Info.plist"
test -f "$CONTENTS/TuckNotes.app/$KEYBOARD_RESOURCES/en.lproj/Localizable.strings"
test -f "$CONTENTS/TuckNotes.app/$HIGHLIGHTER_RESOURCES/atom-one-light.css"
test -f "$CONTENTS/TuckNotes.app/$HIGHLIGHTER_RESOURCES/atom-one-dark.css"
verify_architectures "$CONTENTS/TuckNotes.app/Contents/MacOS/TuckNote"
diff -qr "$APP" "$CONTENTS/TuckNotes.app"

echo "Package verification passed."
