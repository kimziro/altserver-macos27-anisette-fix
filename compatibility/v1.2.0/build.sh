#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
    print -u2 -- "Usage: $0 <official-1_8_1.zip|AltServer.app> <output-AltServer.app>"
    exit 2
fi

INPUT="$1"
OUTPUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd -P)"
EXPECTED_MAIN_SHA="39b38f455ba71a8a163a38575c57d81dc1179068bc6fec0a76762c7a303b77df"
EXPECTED_TEAM="6XVY5G3U44"
DYLIB_NAME="80045ClientInfoGetter.dylib"
WORK="$(mktemp -d "${TMPDIR:-/private/tmp}/altserver-v120-build.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { print -u2 -- "build.sh: $1"; exit 1; }
plist_value() { /usr/libexec/PlistBuddy -c "Print :$1" "$2"; }

[[ -e "$INPUT" ]] || fail "input does not exist."
[[ ! -e "$OUTPUT" ]] || fail "output already exists; refusing to overwrite it."

if [[ -d "$INPUT" && "$INPUT" == *.app ]]; then
    SOURCE_APP="$INPUT"
elif [[ -f "$INPUT" && "$INPUT" == *.zip ]]; then
    ditto -x -k "$INPUT" "$WORK/unpacked"
    SOURCE_APP="$WORK/unpacked/AltServer.app"
else
    fail "input must be an official AltServer.app or ZIP archive."
fi

[[ -d "$SOURCE_APP" && ! -L "$SOURCE_APP" ]] || fail "official AltServer.app is missing or symlinked."
INFO="$SOURCE_APP/Contents/Info.plist"
[[ "$(plist_value CFBundleIdentifier "$INFO")" == "com.rileytestut.AltServer" ]] || fail "bundle identifier mismatch."
[[ "$(plist_value CFBundleShortVersionString "$INFO")" == "1.8.1" ]] || fail "version mismatch."
[[ "$(plist_value CFBundleVersion "$INFO")" == "98" ]] || fail "build mismatch."

DETAILS="$(codesign --display --verbose=4 "$SOURCE_APP" 2>&1)" || fail "signature inspection failed."
[[ "$DETAILS" == *"TeamIdentifier=$EXPECTED_TEAM"* ]] || fail "signing team mismatch."
[[ "$DETAILS" == *"Authority=Developer ID Application:"* ]] || fail "Developer ID signature missing."
codesign --verify --deep --strict "$SOURCE_APP" >/dev/null || fail "official input signature verification failed."
MAIN_SHA="$(shasum -a 256 "$SOURCE_APP/Contents/MacOS/AltServer" | awk '{print $1}')"
[[ "$MAIN_SHA" == "$EXPECTED_MAIN_SHA" ]] || fail "official main executable hash mismatch."

xcrun clang -O2 -Wall -Wextra -Werror -fobjc-arc -fblocks -g0 \
    -fdebug-compilation-dir=. -ffile-prefix-map="$HERE"=. \
    -arch arm64 -arch x86_64 -mmacosx-version-min=13.0 \
    -dynamiclib "$HERE/ClientInfoGetterHook.m" -framework Foundation \
    -Wl,-install_name,@rpath/80045ClientInfoGetter.dylib \
    -o "$WORK/$DYLIB_NAME"
codesign --force --sign - "$WORK/$DYLIB_NAME" >/dev/null
codesign --verify --strict "$WORK/$DYLIB_NAME" >/dev/null

xcrun clang -O2 -Wall -Wextra -Werror -fobjc-arc -fblocks \
    -DALT_HOOK_SYNTHETIC_TEST "$HERE/ClientInfoGetterHook.m" \
    "$HERE/SyntheticGetterTests.m" -framework Foundation \
    -o "$WORK/SyntheticGetterTests"
"$WORK/SyntheticGetterTests"

ditto --norsrc "$SOURCE_APP" "$OUTPUT"
ditto "$WORK/$DYLIB_NAME" "$OUTPUT/Contents/Frameworks/$DYLIB_NAME"
/usr/libexec/PlistBuddy -c 'Add :LSEnvironment dict' "$OUTPUT/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSEnvironment:DYLD_INSERT_LIBRARIES string @executable_path/../Frameworks/$DYLIB_NAME" "$OUTPUT/Contents/Info.plist"
codesign --force --sign - --entitlements "$HERE/Entitlements.plist" "$OUTPUT" >/dev/null
codesign --verify --deep --strict "$OUTPUT" >/dev/null
if strings -a "$OUTPUT/Contents/Frameworks/$DYLIB_NAME" | rg -q '/Users/|/private/tmp/'; then
    fail "output dylib contains a local host path."
fi

for ARCH in arm64 x86_64; do
    cmp <(otool -arch "$ARCH" -t "$SOURCE_APP/Contents/MacOS/AltServer" | sed -n '/^Contents of /,$p') \
        <(otool -arch "$ARCH" -t "$OUTPUT/Contents/MacOS/AltServer" | sed -n '/^Contents of /,$p') >/dev/null \
        || fail "$ARCH __TEXT differs from official input."
done

[[ "$(plist_value LSEnvironment:DYLD_INSERT_LIBRARIES "$OUTPUT/Contents/Info.plist")" == "@executable_path/../Frameworks/$DYLIB_NAME" ]] || fail "injection path mismatch."
[[ "$(otool -D "$OUTPUT/Contents/Frameworks/$DYLIB_NAME" | tail -1)" == "@rpath/$DYLIB_NAME" ]] || fail "output dylib install name mismatch."

print -- "Synthetic getter tests: PASS"
print -- "Official AltServer 1.8.1 (98), Team $EXPECTED_TEAM, main SHA-256 $MAIN_SHA"
print -- "Output: $OUTPUT"
print -- "Signature: ad-hoc, deep strict verification passed"
