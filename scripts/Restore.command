#!/bin/zsh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$ROOT/Payload/AltServer-original-1.7.2.zip"
TEMP_ROOT="$(mktemp -d /private/tmp/altserver-restore.XXXXXX)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

echo "AltServer 1.7.2 restore"
echo

EXPECTED="$(awk '$2 == "Payload/AltServer-original-1.7.2.zip" { print $1 }' "$ROOT/CHECKSUMS-SHA256.txt")"
ACTUAL="$(shasum -a 256 "$PAYLOAD" | awk '{ print $1 }')"
if [[ -z "$EXPECTED" || "$EXPECTED" != "$ACTUAL" ]]; then
    echo "Checksum verification failed."
    if [[ -t 0 ]]; then
        read -k 1 "?Press any key to close."
    fi
    exit 1
fi

ditto -x -k "$PAYLOAD" "$TEMP_ROOT"
APP="$TEMP_ROOT/AltServer.app"
codesign --verify --deep --strict "$APP"
killall AltServer 2>/dev/null || true

if rm -rf /Applications/AltServer.app 2>/dev/null \
    && ditto --noextattr --noqtn "$APP" /Applications/AltServer.app 2>/dev/null; then
    :
else
    STAGED="/private/tmp/AltServer-original-staged.app"
    rm -rf "$STAGED"
    ditto --noextattr --noqtn "$APP" "$STAGED"
    osascript -e 'do shell script "/bin/rm -rf /Applications/AltServer.app && /usr/bin/ditto --noextattr --noqtn /private/tmp/AltServer-original-staged.app /Applications/AltServer.app && /usr/sbin/chown -R root:wheel /Applications/AltServer.app" with administrator privileges'
    rm -rf "$STAGED"
fi

xattr -cr /Applications/AltServer.app
codesign --verify --deep --strict /Applications/AltServer.app
open -n /Applications/AltServer.app

echo
echo "Original AltServer 1.7.2 restored."
echo "The V3 identity file was preserved and may be deleted manually."
echo
if [[ -t 0 ]]; then
    read -k 1 "?Press any key to close."
fi
