#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$REPO_ROOT/dist/TuckNotes.app"
ZIP="$REPO_ROOT/dist/TuckNotes-macOS.zip"
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

echo "Package verification passed."
