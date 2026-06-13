#!/bin/zsh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$ROOT/Payload/AltServer-macOS27-v3.1.zip"
BACKUP_ROOT="$HOME/Library/Application Support/AltServer-macOS27-Fix/Backups"
TEMP_ROOT="$(mktemp -d /private/tmp/altserver-macos27-install.XXXXXX)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

echo "AltServer macOS 27 V3 Fix installer"
echo

if [[ ! -f "$PAYLOAD" ]]; then
    echo "Missing payload: $PAYLOAD"
    if [[ -t 0 ]]; then
        read -k 1 "?Press any key to close."
    fi
    exit 1
fi

EXPECTED="$(awk '$2 == "Payload/AltServer-macOS27-v3.1.zip" { print $1 }' "$ROOT/CHECKSUMS-SHA256.txt")"
ACTUAL="$(shasum -a 256 "$PAYLOAD" | awk '{ print $1 }')"
if [[ -z "$EXPECTED" || "$EXPECTED" != "$ACTUAL" ]]; then
    echo "Checksum verification failed. The package may be damaged."
    if [[ -t 0 ]]; then
        read -k 1 "?Press any key to close."
    fi
    exit 1
fi

ditto -x -k "$PAYLOAD" "$TEMP_ROOT"
APP="$TEMP_ROOT/AltServer.app"
xattr -cr "$APP"
codesign --verify --deep --strict "$APP"

mkdir -p "$BACKUP_ROOT"
if [[ -d /Applications/AltServer.app ]]; then
    CURRENT_VERSION="$(/usr/libexec/PlistBuddy \
        -c 'Print :CFBundleShortVersionString' \
        /Applications/AltServer.app/Contents/Info.plist 2>/dev/null || true)"
    if [[ "$CURRENT_VERSION" != *"-macOS27-"* ]]; then
        BACKUP="$BACKUP_ROOT/AltServer-$(date +%Y%m%d-%H%M%S).app"
        ditto /Applications/AltServer.app "$BACKUP"
        echo "Official AltServer backup created."
    else
        echo "Patched AltServer detected; existing backup preserved."
    fi
fi

killall AltServer 2>/dev/null || true

if rm -rf /Applications/AltServer.app 2>/dev/null \
    && ditto --noextattr --noqtn "$APP" /Applications/AltServer.app 2>/dev/null; then
    :
else
    STAGED="$TEMP_ROOT/AltServer-staged.app"
    ditto --noextattr --noqtn "$APP" "$STAGED"
    osascript - "$STAGED" <<'APPLESCRIPT'
on run argv
    set stagedPath to item 1 of argv
    do shell script "/bin/rm -rf /Applications/AltServer.app && " & ¬
        "/usr/bin/ditto --noextattr --noqtn " & quoted form of stagedPath & ¬
        " /Applications/AltServer.app && " & ¬
        "/usr/sbin/chown -R root:wheel /Applications/AltServer.app" ¬
        with administrator privileges
end run
APPLESCRIPT
fi

xattr -cr /Applications/AltServer.app
codesign --verify --deep --strict /Applications/AltServer.app
open -n /Applications/AltServer.app

echo
echo "Installation complete."
echo "The first anisette request creates a private V3 identity in:"
echo "~/Library/Application Support/AltServer/RemoteAnisetteUser.json"
echo
echo "If AltStore is already installed on the iPhone, do not reinstall it."
echo "Open AltStore > My Apps, then use Refresh All or refresh the app."
echo
echo "Apple may show a sign-in approval alert and a six-digit code."
echo "Approve it only if you started this refresh, and enter the code only"
echo "in the prompt shown by AltStore or AltServer. Never share the code."
echo
if [[ -t 0 ]]; then
    read -k 1 "?Press any key to close."
fi
