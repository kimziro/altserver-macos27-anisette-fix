#!/bin/zsh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BASE_APP="${1:-}"
OUTPUT="${2:-$ROOT/out}"

if [[ -z "$BASE_APP" || ! -d "$BASE_APP" ]]; then
    echo "Usage: $0 /path/to/original/AltServer.app [output-directory]"
    exit 1
fi

mkdir -p "$OUTPUT"
TEMP_APP="/private/tmp/AltServer-macOS27-build.app"
rm -rf "$TEMP_APP"

xcrun swiftc -O -parse-as-library \
    "$ROOT/../src/AnisetteHelper/AnisetteV3Client.swift" \
    "$ROOT/../src/AnisetteHelper/main.swift" \
    -o "$OUTPUT/AltServerAnisetteHelper"

xcrun clang -dynamiclib -fobjc-arc -framework Foundation \
    "$ROOT/../src/AltServerAnisetteFix.m" \
    -o "$OUTPUT/AltServerAnisetteFix.dylib"

codesign --force --sign - "$OUTPUT/AltServerAnisetteHelper"
codesign --force --sign - "$OUTPUT/AltServerAnisetteFix.dylib"

ditto --noextattr --noqtn "$BASE_APP" "$TEMP_APP"
ditto --noextattr --noqtn "$OUTPUT/AltServerAnisetteHelper" \
    "$TEMP_APP/Contents/Frameworks/AltServerAnisetteHelper"
ditto --noextattr --noqtn "$OUTPUT/AltServerAnisetteFix.dylib" \
    "$TEMP_APP/Contents/Frameworks/AltServerAnisetteFix.dylib"

/usr/libexec/PlistBuddy -c 'Delete :LSEnvironment' \
    "$TEMP_APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :LSEnvironment dict' \
    "$TEMP_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c \
    'Add :LSEnvironment:DYLD_INSERT_LIBRARIES string @executable_path/../Frameworks/AltServerAnisetteFix.dylib' \
    "$TEMP_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c \
    'Set :CFBundleShortVersionString 1.7.2-macOS27-v3.1' \
    "$TEMP_APP/Contents/Info.plist"

find "$TEMP_APP" -print0 | while IFS= read -r -d '' item; do
    xattr -c "$item" 2>/dev/null || true
done

codesign --force --deep --sign - "$TEMP_APP"
codesign --verify --deep --strict "$TEMP_APP"

rm -rf "$OUTPUT/AltServer.app"
ditto --noextattr --noqtn "$TEMP_APP" "$OUTPUT/AltServer.app"
rm -f "$OUTPUT/AltServer-macOS27-v3.1.zip"
ditto -c -k --keepParent "$OUTPUT/AltServer.app" \
    "$OUTPUT/AltServer-macOS27-v3.1.zip"

echo "Built: $OUTPUT/AltServer-macOS27-v3.1.zip"
