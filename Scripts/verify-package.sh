#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$REPO_ROOT/dist/TuckNote.app"
ZIP="$REPO_ROOT/dist/TuckNote-macOS.zip"

rm -rf "$REPO_ROOT/dist"
(cd /tmp && "$SCRIPT_DIR/package-app.sh")

test -d "$APP/Contents/MacOS"
test -x "$APP/Contents/MacOS/TuckNote"
test -f "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
test -f "$APP/Contents/Info.plist"
test -f "$ZIP"

test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = \
    "com.lyunify.TuckNote"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")" = \
    "TuckNote"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP/Contents/Info.plist")" = \
    "true"
plutil -lint "$APP/Contents/Info.plist"

CONTENTS="$(mktemp -d)"
trap 'rm -rf "$CONTENTS"' EXIT
ditto -x -k "$ZIP" "$CONTENTS"
test -x "$CONTENTS/TuckNote.app/Contents/MacOS/TuckNote"
test -f "$CONTENTS/TuckNote.app/Contents/Resources/THIRD_PARTY_NOTICES.md"

echo "Package verification passed."
